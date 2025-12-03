//
//  MacScreenshotService.swift
//  ocr_util
//
//  Captures the display that contains the selection rect, then crops
//  to the exact bounding box the user drew. Handles Retina and multiple
//  monitors by using the screen's frame and backing scale.
//

import Cocoa

final class MacScreenshotService: ScreenshotCapturing {

    enum CaptureError: Error {
        case noScreenForRect
        case screencaptureNotFound
        case failed(exitCode: Int32, stderr: String)
        case noFile
        case imageDecodeFailed
        case noBitmapRep
        case noCGImage
        case cropFailed
        case alreadyCapturing
    }
    
    private var isCapturing = false

    func capture(rect: CGRect) async throws -> Screenshot {
        // Prevent concurrent captures
        guard !isCapturing else {
            throw CaptureError.alreadyCapturing
        }
        isCapturing = true
        defer {
            isCapturing = false
        }
        
        // performCapture uses main-actor isolated APIs (NSScreen, NSImage)
        // so we need to call it on the main actor
        return try await MainActor.run {
            try self.performCapture(rect: rect)
        }
    }
    
    
    
    private func performCapture(rect: CGRect) throws -> Screenshot {
        print("📐 MacScreenshotService.capture rect (global, points): \(rect)")

        // 1. Find the screen whose frame contains the center of the rect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) else {
            print("❌ No screen contains rect center \(center)")
            throw CaptureError.noScreenForRect
        }

        let screens = NSScreen.screens
        guard let screenIndex = screens.firstIndex(of: screen) else {
            print("❌ Could not find screen index in NSScreen.screens")
            throw CaptureError.noScreenForRect
        }

        // screencapture -D is 1-based
        let displayNumber = screenIndex + 1
        let screenFrame = screen.frame
        let scale = screen.backingScaleFactor

        print("🖥 Using screen #\(displayNumber) frame: \(screenFrame), scale: \(scale)")

        // 2. Take a full screenshot of that display into a temp file
        let fullScreenshotURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let screencapturePath = "/usr/sbin/screencapture"
        guard FileManager.default.isExecutableFile(atPath: screencapturePath) else {
            print("❌ screencapture not found at \(screencapturePath)")
            throw CaptureError.screencaptureNotFound
        }

        // Run screencapture
        let process = Process()
        process.executableURL = URL(fileURLWithPath: screencapturePath)
        process.arguments = ["-x", "-D", String(displayNumber), fullScreenshotURL.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        print("🚀 running \(screencapturePath) \(process.arguments ?? [])")

        try process.run()
        process.waitUntilExit()

        let status = process.terminationStatus
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stderrPipe.fileHandleForReading.closeFile()
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
        if !stderrString.isEmpty {
            print("⚠️ screencapture stderr:\n\(stderrString)")
        }
        guard status == 0 else {
            print("❌ screencapture exit code \(status)")
            throw CaptureError.failed(exitCode: status, stderr: stderrString)
        }

        // 3. Load the full display image
        guard let imageData = try? Data(contentsOf: fullScreenshotURL),
              let image = NSImage(data: imageData) else {
            print("❌ failed to decode full screenshot image")
            throw CaptureError.imageDecodeFailed
        }

        guard
            let tiffData = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData),
            let cgImageFull = rep.cgImage
        else {
            print("❌ no bitmap rep / cgImage from screenshot")
            throw CaptureError.noBitmapRep
        }

        let pixelsWide = cgImageFull.width
        let pixelsHigh = cgImageFull.height
        print("🧮 display image pixels: \(pixelsWide)x\(pixelsHigh)")

        // 4. Convert global selection rect to this screen's local coordinates (points)
        let localXPoints = rect.origin.x - screenFrame.origin.x
        let localYPoints = rect.origin.y - screenFrame.origin.y
        let localWidthPoints = rect.width
        let localHeightPoints = rect.height

        print("📐 local rect (points): x=\(localXPoints), y=\(localYPoints), w=\(localWidthPoints), h=\(localHeightPoints)")

        // 5. Convert to pixels with Y flipped (image space is top-left origin)
        let wPixels = localWidthPoints * scale
        let hPixels = localHeightPoints * scale
        let xPixels = localXPoints * scale

        let imageHeight = CGFloat(pixelsHigh)
        let bottomFromBottomPixels = localYPoints * scale
        let yPixels = imageHeight - bottomFromBottomPixels - hPixels

        var cropRectPixels = CGRect(
            x: xPixels,
            y: yPixels,
            width: wPixels,
            height: hPixels
        )

        // Clamp to image bounds just in case
        let imageBounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(pixelsWide),
            height: CGFloat(pixelsHigh)
        )
        cropRectPixels = cropRectPixels.intersection(imageBounds)

        print("✂️ crop rect (pixels): \(cropRectPixels) within \(imageBounds)")

        guard let croppedCG = cgImageFull.cropping(to: cropRectPixels) else {
            print("❌ cropping failed")
            throw CaptureError.cropFailed
        }

        // 6. Encode cropped image as PNG in memory
        let croppedRep = NSBitmapImageRep(cgImage: croppedCG)
        guard let croppedData = croppedRep.representation(using: .png, properties: [:]) else {
            print("❌ failed to encode cropped PNG")
            throw CaptureError.imageDecodeFailed
        }

        print("✅ cropped screenshot bytes: \(croppedData.count)")
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: fullScreenshotURL)
        
        return Screenshot(imageData: croppedData, fileURL: nil)
    }
}
