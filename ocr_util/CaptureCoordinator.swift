//
//  CaptureCoordinator.swift
//  ocr_util
//
//  Orchestrates hotkey -> selection -> screenshot -> OCR -> clipboard.
//

import Foundation
import CoreGraphics
import UserNotifications

final class CaptureCoordinator {
    private let hotkeyListener: HotkeyListening
    private let screenshotService: ScreenshotCapturing
    private let screenshotSaver: ScreenshotSaving
    private let selectionViewModel: SelectionViewModel
    private let ocrService: OCRService?
    private let clipboard: ClipboardWriting?

    private(set) var isSelecting: Bool = false
    weak var delegate: CaptureCoordinatorDelegate?
    private var isProcessing: Bool = false

    init(
        hotkeyListener: HotkeyListening,
        screenshotService: ScreenshotCapturing,
        screenshotSaver: ScreenshotSaving,
        selectionViewModel: SelectionViewModel,
        ocrService: OCRService? = nil,
        clipboard: ClipboardWriting? = nil
    ) {
        self.hotkeyListener = hotkeyListener
        self.screenshotService = screenshotService
        self.screenshotSaver = screenshotSaver
        self.selectionViewModel = selectionViewModel
        self.ocrService = ocrService
        self.clipboard = clipboard

        hotkeyListener.onHotkeyPressed = { [weak self] in
            self?.startSelection()
        }

        selectionViewModel.onSelectionComplete = { [weak self] rect in
            self?.finishSelection(with: rect) 
        }

        hotkeyListener.startListening()
    }

    private func startSelection() {
        // Prevent starting a new selection if already processing
        guard !isProcessing else {
            DebugLogger.log("⚠️ CaptureCoordinator: already processing, ignoring hotkey")
            return
        }
        
        // Clear any previous selection so the old box doesn't flash back in
        selectionViewModel.cancel()

        isSelecting = true
        delegate?.captureCoordinatorDidStartSelection(self)
    }

    private func finishSelection(with rect: CGRect) {
        DebugLogger.log("🔁 CaptureCoordinator.finishSelection rect: \(rect)")
        
        // Prevent concurrent processing
        guard !isProcessing else {
            DebugLogger.log("⚠️ CaptureCoordinator: already processing, ignoring duplicate selection")
            return
        }
        
        // Close overlay and stop selecting when processing starts
        isSelecting = false
        isProcessing = true
        
        // Close overlay window immediately when processing starts
        Task { @MainActor in
            self.selectionViewModel.cancel()
            self.delegate?.captureCoordinatorDidStartProcessing(self)
        }

        Task { [weak self] in
            guard let self else { return }
            
            do {
                let screenshot = try await screenshotService.capture(rect: rect)
                DebugLogger.log("✅ CaptureCoordinator: got screenshot (\(screenshot.imageData.count) bytes)")
                
                try await Task.detached(priority: .utility) { [weak self] in
                    guard let self else { throw CancellationError() }
                    try self.screenshotSaver.save(screenshot)
                }.value
                
                DebugLogger.log("✅ CaptureCoordinator: screenshot saved, starting OCR")

                guard let ocrService else {
                    DebugLogger.log("ℹ️ CaptureCoordinator: no OCR service configured")
                    await MainActor.run {
                        self.isProcessing = false
                    }
                    return
                }

                ocrService.recognize(screenshot: screenshot) { [weak self] result in
                    // Capture delegate strongly to prevent deallocation during execution
                    guard let self else { return }
                    let delegate = self.delegate
                    
                    switch result {
                    case .success(let ocrResult):
                        if ocrResult.text.isEmpty {
                            DebugLogger.log("⚠️ CaptureCoordinator: OCR completed but no text was detected")
                            // Show user-friendly notification
                            self.showNotification(
                                title: "No Text Detected",
                                message: "The selected area doesn't contain any readable text."
                            )
                        } else {
                            DebugLogger.log("✅ CaptureCoordinator: OCR success, copying to clipboard")
                            self.clipboard?.copy(text: ocrResult.text)
                        }
                        delegate?.captureCoordinator(self, didFinishOCR: ocrResult)
                    case .failure(let error):
                        DebugLogger.log("❌ CaptureCoordinator: OCR error: \(error)")
                        // Show user-friendly notification for errors
                        self.showNotification(
                            title: "OCR Failed",
                            message: "Unable to extract text. Please try again."
                        )
                        delegate?.captureCoordinator(self, didFailWith: error)
                    }
                    
                    // Reset processing flag when OCR completes
                    self.isProcessing = false
                }
            } catch {
                DebugLogger.log("❌ CaptureCoordinator: error in capture/save: \(error)")
                await MainActor.run {
                    self.delegate?.captureCoordinator(self, didFailWith: error)
                    self.isProcessing = false
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    private func showNotification(title: String, message: String) {
        let notification = UNUserNotificationCenter.current()
        
        // Request authorization if needed
        notification.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            notification.add(request)
        }
    }

}
