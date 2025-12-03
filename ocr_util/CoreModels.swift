//
//  CoreModels.swift
//  ocr_util
//
//  Shared models and protocols for screenshot/OCR/clipboard.
//

import Foundation
import CoreGraphics

/// <#Description#>
struct Screenshot {
    let imageData: Data
    /// <#Description#>
    let fileURL: URL?
}

struct OCRResult: Equatable {
    let text: String
    let markdown: String?
}

protocol ScreenshotCapturing {
    func capture(rect: CGRect) async throws -> Screenshot
}

protocol ScreenshotSaving {
    func save(_ screenshot: Screenshot) throws
}

protocol HotkeyListening: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    func startListening()
}


/// <#Description#>
protocol OCRService {
    func recognize(
        screenshot: Screenshot,
        completion: @escaping (Result<OCRResult, Error>) -> Void
    )
}


protocol ClipboardWriting {
    func copy(text: String)
}

protocol CaptureCoordinatorDelegate: AnyObject {
    func captureCoordinatorDidStartSelection(_ coordinator: CaptureCoordinator)
    func captureCoordinatorDidStartProcessing(_ coordinator: CaptureCoordinator)
    func captureCoordinator(_ coordinator: CaptureCoordinator, didFinishOCR result: OCRResult)
    func captureCoordinator(_ coordinator: CaptureCoordinator, didFailWith error: Error)
}
