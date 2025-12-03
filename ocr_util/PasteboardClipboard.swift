//
//  PasteboardClipboard.swift
//  ocr_util
//
//  Writes recognized text into NSPasteboard (pbcopy-like).
//

import AppKit

final class PasteboardClipboard: ClipboardWriting {
    func copy(text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
