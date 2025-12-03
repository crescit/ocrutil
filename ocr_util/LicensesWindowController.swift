//
//  LicensesWindowController.swift
//  ocr_util
//
//  Window controller for the Licenses dialog.
//

import Cocoa
import SwiftUI

final class LicensesWindowController: NSWindowController {
    convenience init() {
        let licensesView = LicensesView()
        let hostingView = NSHostingView(rootView: licensesView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Licenses"
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


