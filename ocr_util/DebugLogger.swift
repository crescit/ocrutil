//
//  DebugLogger.swift
//  ocr_util
//
//  Simple file-backed logger so we can inspect logs in distributed builds.
//

import Foundation

final class DebugLogger {
    static let shared = DebugLogger()

    private let logURL: URL
    private let queue = DispatchQueue(label: "DebugLogger.queue", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        let fm = FileManager.default

        // Prefer Application Support inside the app's container
        let baseDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "ocr_util"
        let appDir = baseDir.appendingPathComponent(bundleID, isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)

        // Simple .log file; avoid UniformTypeIdentifiers to keep dependencies minimal
        logURL = appDir.appendingPathComponent("ocr_util.log")
 
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Start a new session marker
        let header = "\n\n===== New session: \(dateFormatter.string(from: Date())) =====\n"
        if let data = header.data(using: .utf8) {
            if fm.fileExists(atPath: logURL.path) {
                try? append(data: data)
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }

    /// Public helper to write a log line (also mirrors to stdout for Xcode)
    static func log(_ message: String) {
        shared.write(message)
    }

    /// Location of the current log file (for user reference)
    static var logFileURL: URL {
        shared.logURL
    }

    // MARK: - Internal

    private func write(_ message: String) {
        let line = "\(dateFormatter.string(from: Date()))  \(message)\n"

        queue.async {
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logURL.path) {
                    try? self.append(data: data)
                } else {
                    try? data.write(to: self.logURL, options: .atomic)
                }
            }

            // Also print to standard output for dev builds
            print(message)
        }
    }

    private func append(data: Data) throws {
        let handle = try FileHandle(forWritingTo: logURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}


