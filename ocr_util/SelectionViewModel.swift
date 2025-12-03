//
//  SelectionViewModel.swift
//  ocr_util
//
//  Core selection logic for drag-to-select bounding box.
//

import CoreGraphics

final class SelectionViewModel {
    private var startPoint: CGPoint?
    private(set) var selectionRect: CGRect?

    var onSelectionComplete: ((CGRect) -> Void)?

    init() {}

    func startDrag(at point: CGPoint) {
        startPoint = point
        selectionRect = CGRect(origin: point, size: .zero)
    }

    func updateDrag(to point: CGPoint) {
        guard let start = startPoint else { return }

        let minX = min(start.x, point.x)
        let minY = min(start.y, point.y)
        let maxX = max(start.x, point.x)
        let maxY = max(start.y, point.y)

        selectionRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func finishDrag() {
        guard let rect = selectionRect else { return }
        onSelectionComplete?(rect)
        startPoint = nil
    }

    func cancel() {
        startPoint = nil
        selectionRect = nil
    }
}
