//
//  HotkeySettingsWindowController.swift
//  ocr_util
//
//  Window controller for hotkey settings dialog.
//

import Cocoa
import SwiftUI

final class HotkeySettingsWindowController: NSWindowController {
    private var onSave: ((HotkeyConfiguration) -> Void)?
    
    convenience init(onSave: @escaping (HotkeyConfiguration) -> Void) {
        let settingsView = HotkeySettingsView(onSave: onSave)
        let hostingView = NSHostingView(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hotkey Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        self.init(window: window)
        self.onSave = onSave
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

