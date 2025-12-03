//
//  SelectionOverlayView.swift
//  ocr_util
//
//  Transparent full-screen view that tracks drag selection.
//

import Cocoa

final class SelectionOverlayView: NSView {

    private let viewModel: SelectionViewModel

    init(frame frameRect: NSRect, viewModel: SelectionViewModel) {
        self.viewModel = viewModel
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        let locInWindow = event.locationInWindow
        let global = window.convertPoint(toScreen: locInWindow)
        viewModel.startDrag(at: global)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let locInWindow = event.locationInWindow
        let global = window.convertPoint(toScreen: locInWindow)
        viewModel.updateDrag(to: global)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        viewModel.finishDrag()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let rect = viewModel.selectionRect, let window = window else {
            // No selection yet → nothing to draw
            return
        }

        // Convert the screen rect back into local view coords
        let originInWindow = window.convertPoint(fromScreen: rect.origin)
        let drawRect = CGRect(
            x: originInWindow.x,
            y: originInWindow.y,
            width: rect.width,
            height: rect.height
        )

        let path = NSBezierPath(rect: drawRect)

        // “Punch out” the selection region a bit visually
        NSColor.clear.setFill()
        path.fill()

        NSColor.red.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

}
