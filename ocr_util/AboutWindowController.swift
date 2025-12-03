//
//  AboutWindowController.swift
//  ocr_util
//
//  Window controller for the About / Privacy dialog.
//

import Cocoa
import SwiftUI

final class AboutWindowController: NSWindowController {
    convenience init() {
        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About / Privacy"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


