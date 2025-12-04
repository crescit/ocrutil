//
//  PaddleOCRService.swift
//  ocr_util
//
//  Wrapper around the paddleocr-cli binary bundled in the app.
//  Uses PaddleOCR in CPU mode for OCR text extraction.
//

import Foundation
import AppKit

enum PaddleOCRError: Error {
    case binaryNotFound
    case processFailed(code: Int32, stderr: String)
    case outputDecodingFailed
    case tempFileWriteFailed(Error)
    case invalidImage
    case imageFileNotFound
}

final class PaddleOCRService: OCRService {

    static let shared = PaddleOCRService()
    private init() {}

    // Use the app's container directory instead of system temp
    // This ensures sandboxed subprocesses can access files created by the parent process
    private var tempDir: URL {
        // Use the app's container directory which subprocesses can access
        if let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let ocrTempDir = containerURL.appendingPathComponent("OCR_Temp", isDirectory: true)
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: ocrTempDir, withIntermediateDirectories: true)
            return ocrTempDir
        }
        // Fallback to system temp (may not work for subprocesses)
        return FileManager.default.temporaryDirectory
    }
    
    // Writable directory for OCR resources (fonts, models cache, etc.)
    // This is needed because the app bundle is read-only in sandboxed apps
    private var ocrResourcesDir: URL {
        if let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let resourcesDir = containerURL.appendingPathComponent("OCR_Resources", isDirectory: true)
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            return resourcesDir
        }
        return tempDir
    }
    private var isRunningOCR = false
    private let loadingCursor = LoadingCursorOverlay()
    private var pythonPatchDirectory: URL?

    // MARK: - Paths

    /// URL of the bundled CLI executable
    /// Supports both onefile (single executable) and onedir (directory bundle) modes
    private func binaryURL() throws -> URL {
        let fm = FileManager.default
        let candidates: [URL?] = [
            // Try onedir mode - folder reference at root level (most common)
            Bundle.main.resourceURL?
                .appendingPathComponent("paddleocr-cli-dir", isDirectory: true)
                .appendingPathComponent("paddleocr-cli", isDirectory: false),
            // Try onedir mode - in ocr/paddleocr subdirectory
            Bundle.main.resourceURL?
                .appendingPathComponent("ocr", isDirectory: true)
                .appendingPathComponent("paddleocr", isDirectory: true)
                .appendingPathComponent("paddleocr-cli-dir", isDirectory: true)
                .appendingPathComponent("paddleocr-cli", isDirectory: false),
            // Try using Bundle.main.url with subdirectory
            Bundle.main.url(
                forResource: "paddleocr-cli",
                withExtension: nil,
                subdirectory: "paddleocr-cli-dir"
            ),
            Bundle.main.url(
                forResource: "paddleocr-cli",
                withExtension: nil,
                subdirectory: "ocr/paddleocr/paddleocr-cli-dir"
            ),
            // Try onefile mode (single executable)
            Bundle.main.url(
                forResource: "paddleocr-cli",
                withExtension: nil,
                subdirectory: "ocr/paddleocr"
            ),
            Bundle.main.url(
                forResource: "paddleocr-cli",
                withExtension: nil,
                subdirectory: "ocr"
            ),
            Bundle.main.url(
                forResource: "paddleocr-cli",
                withExtension: nil
            ),
            // Additional fallback paths
            Bundle.main.resourceURL?
                .appendingPathComponent("ocr", isDirectory: true)
                .appendingPathComponent("paddleocr", isDirectory: true)
                .appendingPathComponent("paddleocr-cli", isDirectory: false)
        ]

        // Debug: Log all candidates we're checking
        DebugLogger.log("🔍 PaddleOCR: Searching for executable...")
        for candidate in candidates.compactMap({ $0 }) {
            let exists = fm.fileExists(atPath: candidate.path)
            let isExecutable = fm.isExecutableFile(atPath: candidate.path)
            DebugLogger.log("   Checking: \(candidate.path)")
            DebugLogger.log("     Exists: \(exists), Executable: \(isExecutable)")
            
            if isExecutable {
                DebugLogger.log("✅ PaddleOCR: Found executable at \(candidate.path)")
                return candidate
            }
        }
        
        // Debug: List all resources in bundle
        if let resourceURL = Bundle.main.resourceURL {
            DebugLogger.log("🔍 PaddleOCR: Bundle resources at: \(resourceURL.path)")
            DebugLogger.log("🔍 PaddleOCR: Bundle main path: \(Bundle.main.bundlePath)")
            if let contents = try? fm.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) {
                DebugLogger.log("   Contents:")
                for item in contents {
                    let isDir = item.hasDirectoryPath
                    DebugLogger.log("     - \(item.lastPathComponent) (\(isDir ? "dir" : "file"))")
                    if isDir && item.lastPathComponent == "paddleocr-cli-dir" {
                        // List contents of paddleocr-cli-dir
                        if let dirContents = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                            DebugLogger.log("       Inside paddleocr-cli-dir:")
                            for subItem in dirContents {
                                DebugLogger.log("         - \(subItem.lastPathComponent)")
                            }
                        }
                    }
                }
            }
        }

        throw PaddleOCRError.binaryNotFound
    }

    // MARK: - Public API

    /// Run OCR on a screenshot/image at `imageURL`.
    /// - Returns: raw text output from PaddleOCR.
    func runOCR(on imageURL: URL) async throws -> String {
        // Prevent concurrent OCR calls
        guard !isRunningOCR else {
            throw PaddleOCRError.processFailed(code: -1, stderr: "OCR already in progress")
        }
        isRunningOCR = true
        defer {
            isRunningOCR = false
        }
        
        let bin = try binaryURL()
        
        // Set working directory to the executable's directory
        // This ensures PyInstaller can find the _internal directory
        let workingDir = bin.deletingLastPathComponent()
        let internalDir = workingDir.appendingPathComponent("_internal", isDirectory: true)
        
        // Prepare fonts in writable location to avoid sandbox write errors
        // This improves OCR performance by avoiding failed font copy operations
        try prepareFonts(in: internalDir)
        
        // Set up Python patch to redirect font operations (if possible)
        // Note: This may not work with PyInstaller, but it's worth trying
        try? setupPythonPatch()
        
        // Verify _internal directory exists and is accessible BEFORE creating process
        let fm = FileManager.default
        DebugLogger.log("🔍 PaddleOCR: Checking _internal directory...")
        if !fm.fileExists(atPath: internalDir.path) {
            DebugLogger.log("❌ PaddleOCR: _internal directory not found at \(internalDir.path)")
            throw PaddleOCRError.processFailed(code: -1, stderr: "_internal directory not found")
        } else {
            DebugLogger.log("✅ PaddleOCR: _internal directory found at \(internalDir.path)")
            // Check if we can list contents (tests read access)
            do {
                let contents = try fm.contentsOfDirectory(atPath: internalDir.path)
                DebugLogger.log("   Directory contains \(contents.count) items")
                // Log first few items for debugging
                let sampleItems = contents.prefix(5)
                DebugLogger.log("   Sample items: \(sampleItems.joined(separator: ", "))")
            } catch {
                DebugLogger.log("⚠️ PaddleOCR: Cannot read _internal directory contents: \(error)")
                DebugLogger.log("   This may indicate a sandbox permission issue")
            }
        }
        
        let process = Process()
        process.executableURL = bin
        process.arguments = [imageURL.path]
        process.currentDirectoryURL = workingDir
        
        // Set environment variables to help PyInstaller find its resources
        var environment = ProcessInfo.processInfo.environment
        environment["PYINSTALLER_BOOTLOADER"] = "1"
        // Set _MEIPASS to the _internal directory (PyInstaller uses this)
        environment["_MEIPASS"] = internalDir.path
        
        // Set environment variables to help RapidOCR find fonts and avoid write errors
        // RapidOCR may check these locations or use them as fallbacks
        let writableModelsDir = ocrResourcesDir.appendingPathComponent("rapidocr/models", isDirectory: true)
        if FileManager.default.fileExists(atPath: writableModelsDir.path) {
            // Set various environment variables that RapidOCR might respect
            // Note: These may not be directly used by RapidOCR, but setting them
            // ensures fonts are available in writable locations as fallbacks
            environment["RAPIDOCR_MODELS_DIR"] = writableModelsDir.path
            environment["RAPIDOCR_FONT_DIR"] = writableModelsDir.path
            DebugLogger.log("🔧 PaddleOCR: Set RAPIDOCR_MODELS_DIR to \(writableModelsDir.path)")
        }
        
        // Add Python patch directory to PYTHONPATH if we set it up
        if let pythonPatchDir = pythonPatchDirectory, FileManager.default.fileExists(atPath: pythonPatchDir.path) {
            let currentPythonPath = environment["PYTHONPATH"] ?? ""
            let newPythonPath = currentPythonPath.isEmpty ? pythonPatchDir.path : "\(pythonPatchDir.path):\(currentPythonPath)"
            environment["PYTHONPATH"] = newPythonPath
            DebugLogger.log("🔧 PaddleOCR: Added Python patch directory to PYTHONPATH: \(pythonPatchDir.path)")
        }
        
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        DebugLogger.log("🚀 PaddleOCR: Running executable: \(bin.path)")
        DebugLogger.log("🚀 PaddleOCR: Working directory: \(workingDir.path)")
        DebugLogger.log("🚀 PaddleOCR: Image path: \(imageURL.path)")
        DebugLogger.log("🚀 PaddleOCR: Environment _MEIPASS: \(environment["_MEIPASS"] ?? "not set")")
        
        // Verify executable exists and is executable
        if !fm.fileExists(atPath: bin.path) {
            DebugLogger.log("❌ PaddleOCR: Executable does not exist at \(bin.path)")
            throw PaddleOCRError.binaryNotFound
        }
        if !fm.isExecutableFile(atPath: bin.path) {
            DebugLogger.log("❌ PaddleOCR: Executable is not executable at \(bin.path)")
            throw PaddleOCRError.binaryNotFound
        }
        
        // Check code signature and entitlements
        let codesignTask = Process()
        codesignTask.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignTask.arguments = ["-d", "--entitlements", "-", bin.path]
        let codesignPipe = Pipe()
        codesignTask.standardOutput = codesignPipe
        codesignTask.standardError = Pipe()
        try? codesignTask.run()
        codesignTask.waitUntilExit()
        if codesignTask.terminationStatus == 0 {
            let codesignData = codesignPipe.fileHandleForReading.readDataToEndOfFile()
            if let codesignOutput = String(data: codesignData, encoding: .utf8), !codesignOutput.isEmpty {
                DebugLogger.log("📋 PaddleOCR: Executable entitlements:")
                DebugLogger.log(codesignOutput)
            }
        }

        do {
            try process.run()
            DebugLogger.log("✅ PaddleOCR: Process launched successfully")
        } catch {
            DebugLogger.log("❌ PaddleOCR: Failed to launch process: \(error)")
            DebugLogger.log("   Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                DebugLogger.log("   Domain: \(nsError.domain)")
                DebugLogger.log("   Code: \(nsError.code)")
                DebugLogger.log("   UserInfo: \(nsError.userInfo)")
            }
            throw PaddleOCRError.processFailed(code: -1, stderr: "Failed to launch process: \(error.localizedDescription)")
        }
        
        process.waitUntilExit()

        let status = process.terminationStatus
        let terminationReason = process.terminationReason
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        
        // Always log process termination details for debugging
        DebugLogger.log("📊 PaddleOCR: Process terminated")
        DebugLogger.log("   Exit code: \(status)")
        if terminationReason == .exit {
            DebugLogger.log("   Termination reason: normal exit")
        } else {
            // For signal termination, calculate the signal number
            // macOS reports signal termination as exit code = 128 + signal number
            // But sometimes it's just the signal number directly
            let signalNumber: Int32
            if status > 128 {
                signalNumber = status - 128
            } else if status > 0 && status < 32 {
                signalNumber = status
            } else {
                signalNumber = -1 // unknown
            }
            DebugLogger.log("   Termination reason: uncaught signal")
            if signalNumber > 0 {
                let signalName = getSignalName(signalNumber)
                DebugLogger.log("   Signal number: \(signalNumber) (\(signalName))")
            } else {
                DebugLogger.log("   Signal number: unknown (exit code: \(status))")
            }
        }
        
        // Log stdout (even if empty)
        let outString = String(data: outData, encoding: .utf8) ?? "<could not decode stdout>"
        DebugLogger.log("📋 PaddleOCR stdout output (\(outData.count) bytes):")
        if outString.isEmpty {
            DebugLogger.log("   (empty)")
        } else {
            DebugLogger.log(outString)
        }
        
        // Log stderr (even if empty)
        let errString = String(data: errData, encoding: .utf8) ?? "<could not decode stderr>"
        DebugLogger.log("📋 PaddleOCR stderr output (\(errData.count) bytes):")
        if errString.isEmpty {
            DebugLogger.log("   (empty)")
        } else {
            DebugLogger.log(errString)
        }
        
        // Log additional process info for debugging
        DebugLogger.log("📋 PaddleOCR process details:")
        DebugLogger.log("   Executable: \(bin.path)")
        DebugLogger.log("   Arguments: \(process.arguments?.joined(separator: " ") ?? "none")")
        DebugLogger.log("   Working directory: \(workingDir.path)")
        if let env = process.environment {
            DebugLogger.log("   Environment variables:")
            for (key, value) in env.sorted(by: { $0.key < $1.key }) {
                DebugLogger.log("     \(key)=\(value)")
            }
        }

        if status != 0 {
            let err = String(data: errData, encoding: .utf8) ?? ""
            DebugLogger.log("❌ PaddleOCR: Process failed with exit code \(status)")
            DebugLogger.log("   stderr: \(err.isEmpty ? "(empty)" : err)")
            
            // For signal termination, provide more specific error message
            if terminationReason != .exit {
                let signalNumber: Int32
                if status > 128 {
                    signalNumber = status - 128
                } else if status > 0 && status < 32 {
                    signalNumber = status
                } else {
                    signalNumber = -1
                }
                
                if signalNumber == 5 {
                    DebugLogger.log("⚠️ PaddleOCR: Process killed by SIGTRAP (signal 5)")
                    DebugLogger.log("   This often indicates a sandbox violation or missing entitlements")
                    DebugLogger.log("   Check Console.app for sandbox 'deny' messages")
                    DebugLogger.log("   Verify the executable is signed with Helper.entitlements")
                } else if signalNumber == 9 {
                    DebugLogger.log("⚠️ PaddleOCR: Process killed by SIGKILL (signal 9)")
                    DebugLogger.log("   This usually indicates the sandbox killed the process")
                } else if signalNumber == 11 {
                    DebugLogger.log("⚠️ PaddleOCR: Process killed by SIGSEGV (signal 11)")
                    DebugLogger.log("   This indicates a segmentation fault - possible library loading issue")
                }
            }
            
            throw PaddleOCRError.processFailed(code: status, stderr: err)
        }

        guard let output = String(data: outData, encoding: .utf8) else {
            throw PaddleOCRError.outputDecodingFailed
        }

        // Preserve newlines - only trim leading/trailing whitespace (spaces and tabs), not newlines
        // This ensures multi-line text from OCR is preserved correctly
        // Create a character set with only spaces and tabs (not newlines)
        let spacesAndTabs = CharacterSet.whitespaces.subtracting(CharacterSet.newlines)
        var trimmed = output.trimmingCharacters(in: spacesAndTabs)
        
        // Optionally remove a single leading/trailing newline if present, but preserve internal newlines
        if trimmed.hasPrefix("\n") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasPrefix("\r\n") {
            trimmed = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("\r") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("\n") {
            trimmed = String(trimmed.dropLast())
        }
        if trimmed.hasSuffix("\r\n") {
            trimmed = String(trimmed.dropLast(2))
        } else if trimmed.hasSuffix("\r") {
            trimmed = String(trimmed.dropLast())
        }
        
        return trimmed
    }

    // MARK: - OCRService

    func recognize(
        screenshot: Screenshot,
        completion: @escaping (Result<OCRResult, Error>) -> Void
    ) {
        // Capture completion strongly to prevent deallocation
        Task { [loadingCursor, completion] in
            var imageURL: URL?
            var shouldCleanup = false
            
            do {
                DebugLogger.log("🔍 PaddleOCR: Starting recognize()")
                let prepared = try prepareImageFile(from: screenshot)
                imageURL = prepared.0
                shouldCleanup = prepared.1
                DebugLogger.log("🔍 PaddleOCR: Prepared image file at \(prepared.0.path)")
                
                // Verify file still exists and is readable before OCR
                guard let url = imageURL else {
                    throw PaddleOCRError.imageFileNotFound
                }
                
                let fm = FileManager.default
                guard fm.fileExists(atPath: url.path) else {
                    throw PaddleOCRError.imageFileNotFound
                }
                
                // Verify file is readable and has content right before OCR
                guard let preCheckData = try? Data(contentsOf: url),
                      preCheckData.count > 0 else {
                    throw PaddleOCRError.invalidImage
                }
                
                DebugLogger.log("✅ PaddleOCR: File verified before OCR - \(preCheckData.count) bytes")

                // Show loading cursor when OCR starts
                loadingCursor.show()
                
                let rawText = try await runOCR(on: url)
                
                // Hide loading cursor when OCR completes
                loadingCursor.hide()
                
                // Verify file still exists after OCR (before cleanup)
                if shouldCleanup, let url = imageURL, FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                    DebugLogger.log("🧹 PaddleOCR: Cleaned up temp file")
                }
                
                // Preserve newlines - only trim leading/trailing whitespace, not internal newlines
                // This ensures multi-line text from OCR is preserved correctly
                // rawText is already trimmed by runOCR(), so we can use it directly
                let ocrResult = OCRResult(text: rawText, markdown: nil)
                DebugLogger.log("✅ PaddleOCR: recognize() completed successfully, text length: \(rawText.count)")

                // Call completion on main thread to ensure thread safety
                Task { @MainActor in
                    completion(.success(ocrResult))
                }
            } catch {
                DebugLogger.log("❌ PaddleOCR: recognize() failed with error: \(error)")
                
                // Hide loading cursor on error
                loadingCursor.hide()
                
                // Clean up on error too, but only after OCR process is done
                if shouldCleanup, let url = imageURL {
                    // Wait a moment to ensure process has fully terminated
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    if FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                        DebugLogger.log("🧹 PaddleOCR: Cleaned up temp file after error")
                    }
                }
                
                // Call completion on main thread to ensure thread safety
                Task { @MainActor in
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Helpers
    
    /// Prepares fonts in a writable location to avoid sandbox write errors.
    /// RapidOCR tries to copy fonts to the models directory, but the app bundle is read-only.
    /// This method copies fonts to a writable location that mirrors the expected structure.
    private func prepareFonts(in internalDir: URL) throws {
        let fm = FileManager.default
        
        // Find the bundled font location
        let fontCandidates = [
            internalDir.appendingPathComponent("rapidocr/resources/fonts/FZYTK.TTF"),
            internalDir.appendingPathComponent("rapidocr/resources/fonts/fzyttk.ttf"),
            internalDir.appendingPathComponent("resources/fonts/FZYTK.TTF"),
        ]
        
        guard let bundledFontURL = fontCandidates.first(where: { fm.fileExists(atPath: $0.path) }) else {
            DebugLogger.log("⚠️ PaddleOCR: Bundled font not found, OCR may have reduced performance")
            return
        }
        
        DebugLogger.log("🔍 PaddleOCR: Found bundled font at: \(bundledFontURL.path)")
        
        // Create writable models directory in container for fonts
        // RapidOCR expects fonts in: _internal/rapidocr/models/FZYTK.TTF
        // We'll create a writable mirror structure
        let writableModelsDir = ocrResourcesDir.appendingPathComponent("rapidocr/models", isDirectory: true)
        try? fm.createDirectory(at: writableModelsDir, withIntermediateDirectories: true)
        
        // Copy font to writable location if needed
        let writableFontURL = writableModelsDir.appendingPathComponent("FZYTK.TTF")
        
        let needsCopy: Bool
        if fm.fileExists(atPath: writableFontURL.path) {
            // Check if bundled font is newer or different
            if let bundledAttrs = try? fm.attributesOfItem(atPath: bundledFontURL.path),
               let writableAttrs = try? fm.attributesOfItem(atPath: writableFontURL.path),
               let bundledSize = bundledAttrs[.size] as? Int64,
               let writableSize = writableAttrs[.size] as? Int64,
               bundledSize == writableSize {
                // Font already exists and sizes match, skip copy
                needsCopy = false
            } else {
                needsCopy = true
            }
        } else {
            needsCopy = true
        }
        
        if needsCopy {
            do {
                // Remove old font if it exists
                if fm.fileExists(atPath: writableFontURL.path) {
                    try fm.removeItem(at: writableFontURL)
                }
                // Copy font to writable location
                try fm.copyItem(at: bundledFontURL, to: writableFontURL)
                DebugLogger.log("✅ PaddleOCR: Copied font to writable location: \(writableFontURL.path)")
            } catch {
                DebugLogger.log("⚠️ PaddleOCR: Failed to copy font to writable location: \(error)")
                // Non-fatal, OCR will use bundled font directly
            }
        } else {
            DebugLogger.log("✅ PaddleOCR: Font already in writable location")
        }
        
        // Also try to set up a user home directory override for RapidOCR's font cache
        // RapidOCR may look for fonts in ~/.rapidocr or similar locations
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            let rapidOcrHome = URL(fileURLWithPath: homeDir).appendingPathComponent(".rapidocr", isDirectory: true)
            let rapidOcrModels = rapidOcrHome.appendingPathComponent("models", isDirectory: true)
            try? fm.createDirectory(at: rapidOcrModels, withIntermediateDirectories: true)
            
            let homeFontURL = rapidOcrModels.appendingPathComponent("FZYTK.TTF")
            if !fm.fileExists(atPath: homeFontURL.path) {
                try? fm.copyItem(at: bundledFontURL, to: homeFontURL)
                DebugLogger.log("✅ PaddleOCR: Also copied font to user home cache: \(homeFontURL.path)")
            }
        }
    }
    
    /// Sets up a Python patch script to redirect RapidOCR font operations.
    /// This copies a patch script to a writable location and prepares it for injection.
    private func setupPythonPatch() throws {
        let fm = FileManager.default
        
        // Create patch directory in container
        let patchDir = ocrResourcesDir.appendingPathComponent("python_patch", isDirectory: true)
        try? fm.createDirectory(at: patchDir, withIntermediateDirectories: true)
        
        // Copy patch script from bundle if it exists
        if let bundlePatchURL = Bundle.main.url(forResource: "rapidocr_font_patch", withExtension: "py") {
            let containerPatchURL = patchDir.appendingPathComponent("rapidocr_font_patch.py")
            
            // Only copy if it doesn't exist or is different
            let needsCopy: Bool
            if fm.fileExists(atPath: containerPatchURL.path) {
                if let bundleAttrs = try? fm.attributesOfItem(atPath: bundlePatchURL.path),
                   let containerAttrs = try? fm.attributesOfItem(atPath: containerPatchURL.path),
                   let bundleSize = bundleAttrs[.size] as? Int64,
                   let containerSize = containerAttrs[.size] as? Int64,
                   bundleSize == containerSize {
                    needsCopy = false
                } else {
                    needsCopy = true
                }
            } else {
                needsCopy = true
            }
            
            if needsCopy {
                try? fm.removeItem(at: containerPatchURL)
                try fm.copyItem(at: bundlePatchURL, to: containerPatchURL)
                DebugLogger.log("✅ PaddleOCR: Copied Python patch script to: \(containerPatchURL.path)")
            }
            
            pythonPatchDirectory = patchDir
        } else {
            DebugLogger.log("⚠️ PaddleOCR: Python patch script not found in bundle, skipping patch setup")
        }
    }
    
    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case 1: return "SIGHUP"
        case 2: return "SIGINT"
        case 3: return "SIGQUIT"
        case 4: return "SIGILL"
        case 5: return "SIGTRAP"
        case 6: return "SIGABRT"
        case 7: return "SIGEMT"
        case 8: return "SIGFPE"
        case 9: return "SIGKILL"
        case 10: return "SIGBUS"
        case 11: return "SIGSEGV"
        case 12: return "SIGSYS"
        case 13: return "SIGPIPE"
        case 14: return "SIGALRM"
        case 15: return "SIGTERM"
        default: return "SIG\(signal)"
        }
    }

    private func prepareImageFile(from screenshot: Screenshot) throws -> (URL, Bool) {
        if let existingURL = screenshot.fileURL {
            return (existingURL, false)
        }

        let url = tempDir
            .appendingPathComponent("paddleocr-\(UUID().uuidString)")
            .appendingPathExtension("png")

        do {
            try screenshot.imageData.write(to: url, options: .atomic)
            
            // Ensure file is fully written and readable before returning
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else {
                throw PaddleOCRError.tempFileWriteFailed(NSError(domain: "FileNotFound", code: -1))
            }
            
            // Verify we can read the file back and it has content
            guard let verifyData = try? Data(contentsOf: url),
                  verifyData.count == screenshot.imageData.count else {
                throw PaddleOCRError.tempFileWriteFailed(NSError(domain: "FileVerificationFailed", code: -1))
            }
            
            // Verify the image can actually be decoded and has valid dimensions
            guard let image = NSImage(data: verifyData),
                  let tiffData = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiffData),
                  let cgImage = rep.cgImage else {
                throw PaddleOCRError.invalidImage
            }
            
            let width = cgImage.width
            let height = cgImage.height
            
            DebugLogger.log("🔍 PaddleOCR: Image validation - \(width)x\(height) pixels, \(verifyData.count) bytes")
            
            // Ensure image has valid dimensions
            guard width > 0 && height > 0 else {
                DebugLogger.log("❌ PaddleOCR: Image has invalid dimensions: \(width)x\(height)")
                throw PaddleOCRError.invalidImage
            }
        } catch {
            throw PaddleOCRError.tempFileWriteFailed(error)
        }

        return (url, true)
    }
}

