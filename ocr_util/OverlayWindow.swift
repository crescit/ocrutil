//
//  OverlayWindow.swift
//  ocr_util
//
//  Borderless window that *can* become key/main so it can receive mouse events.
//

import Cocoa

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
