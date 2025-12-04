//
//  IntroWindowController.swift
//  ocr_util
//
//  Window controller for the intro/welcome dialog.
//

import Cocoa
import SwiftUI

struct IntroView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to ocr_util")
                .font(.title)
                .bold()
            
            Text("Thank you for installing ocr_util.")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Use the hot key (⌘⌥/) to start a capture from anywhere.")
                Text("• Draw a bounding box around the text you want to copy and ocr_util will run OCR and put the result on your clipboard.")
                Text("• The first time you capture, macOS will show a Screen Recording dialog that says ocr_util is requesting to bypass the system private window picker and directly access your screen (and possibly audio). This is a system privacy check from Apple.")
                Text("• After granting permission, you will need to redraw the bounding box for the capture to complete.")
            }
            
            Text("ocr_util only uses this permission to read the pixels inside the box you draw so it can extract text. It does not record or save video or audio.")
            
            Text("You can later revoke or change this permission in System Settings → Privacy & Security → Screen Recording.")
            
            HStack {
                Spacer()
                Button("Got it") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }
}

final class IntroWindowController: NSWindowController, NSWindowDelegate {
    private var onDismiss: (() -> Void)?
    
    convenience init(onDismiss: @escaping () -> Void) {
        let introView = IntroView(onDismiss: {
            // Will be handled by the button action
        })
        let hostingView = NSHostingView(rootView: introView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ocr_util"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = true
        window.level = .modalPanel
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        self.init(window: window)
        self.onDismiss = onDismiss
        window.delegate = self
    }
    
    func showModal() {
        guard let window = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Create a new view with the dismiss callback
        let introView = IntroView(onDismiss: { [weak self] in
            self?.dismiss()
        })
        let hostingView = NSHostingView(rootView: introView)
        window.contentView = hostingView
        
        NSApp.runModal(for: window)
    }
    
    func dismiss() {
        guard let window = window else { return }
        onDismiss?()
        NSApp.stopModal()
        window.close()
    }
    
    // Handle window close via red X button
    func windowWillClose(_ notification: Notification) {
        // If window is closing and modal is still running, stop it
        if NSApp.modalWindow == window {
            onDismiss?()
            NSApp.stopModal()
        }
    }
}

