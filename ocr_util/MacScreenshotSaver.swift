//
//  MacScreenshotSaver.swift
//  ocr_util
//
//  Saves the CROPPED screenshot to a temp folder for debugging.
//

import Foundation

final class MacScreenshotSaver: ScreenshotSaving {

    enum SaveError: Error {
        case writeFailed
    }

    func save(_ screenshot: Screenshot) throws {
        // Use the app's temporary directory for debug output
        let baseTmp = FileManager.default.temporaryDirectory
        let dir = baseTmp.appendingPathComponent("ocr_util_debug", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        } catch {
            print("❌ Failed to create temp debug dir: \(error)")
            throw SaveError.writeFailed
        }

        let formatter = ISO8601DateFormatter()
        let filename = "cropped-\(formatter.string(from: Date())).png"
        let url = dir.appendingPathComponent(filename)

        do {
            try screenshot.imageData.write(to: url)
            print("📸 Saved CROPPED screenshot to: \(url.path)")

        } catch {
            print("❌ Failed to save cropped screenshot: \(error)")
            throw SaveError.writeFailed
        }
    }
}
