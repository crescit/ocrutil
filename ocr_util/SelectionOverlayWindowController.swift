//
//  SelectionOverlayWindowController.swift
//  ocr_util
//
//  Hosts SelectionOverlayView in a borderless full-screen window.
//

import Cocoa

final class SelectionOverlayWindowController: NSWindowController, CaptureCoordinatorDelegate {

    private let viewModel: SelectionViewModel
    private let overlayView: SelectionOverlayView

    init(viewModel: SelectionViewModel) {
        self.viewModel = viewModel

        let screenFrame = NSScreen.main?.frame ?? .zero
        let window = OverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        overlayView = SelectionOverlayView(frame: screenFrame, viewModel: viewModel)
        window.contentView = overlayView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - CaptureCoordinatorDelegate

    func captureCoordinatorDidStartSelection(_ coordinator: CaptureCoordinator) {
        DispatchQueue.main.async {
            // Make sure we start from a clean state
            self.viewModel.cancel()
            self.overlayView.needsDisplay = true

            self.showWindow(nil)
            self.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    func captureCoordinatorDidStartProcessing(_ coordinator: CaptureCoordinator) {
        DispatchQueue.main.async {
            // Close overlay when processing starts
            self.viewModel.cancel()
            self.overlayView.needsDisplay = true
            self.close()
        }
    }

    func captureCoordinator(_ coordinator: CaptureCoordinator, didFinishOCR result: OCRResult) {
        // Call directly - delegate methods should handle their own thread safety
        self.handleOCRComplete()
    }

    func captureCoordinator(_ coordinator: CaptureCoordinator, didFailWith error: Error) {
        // Call directly - delegate methods should handle their own thread safety
        self.handleOCRComplete()
    }
    
    private func handleOCRComplete() {
        // Clear any selection so it doesn't stick around between runs
        viewModel.cancel()
        overlayView.needsDisplay = true
        close()
    }
}
