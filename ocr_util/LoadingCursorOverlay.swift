//
//  LoadingCursorOverlay.swift
//  ocr_util
//
//  A loading cursor overlay that follows the mouse, similar to Windows' loading cursor.
//  Shows a spinner next to the cursor during async operations.
//

import AppKit
import CoreGraphics

final class LoadingCursorOverlay {
    // Store only the view - access window through view.window to avoid property conflicts
    private var overlayView: LoadingCursorView?
    private var mouseTimer: Timer?
    private var isActive = false // Flag to prevent timer access during cleanup
    
    private let spinnerSize: CGFloat = 12
    private let offsetFromCursor: CGFloat = 12
    
    func show() {
        // Always dispatch to main thread for UI operations
        if Thread.isMainThread {
            performShow()
        } else {
            // Use sync to ensure window is created before returning
            DispatchQueue.main.sync { [self] in
                self.performShow()
            }
        }
    }
    
    private func performShow() {
        // Ensure we're on main thread
        assert(Thread.isMainThread, "performShow must be called on main thread")
        
        // Clean up old view/timer BEFORE creating new ones
        isActive = false
        
        // Stop and clear timer first
        if let timer = mouseTimer {
            timer.invalidate()
            mouseTimer = nil
        }
        
        // Order out old window through view's window property (safer than storing window directly)
        if let oldView = overlayView, let oldWindow = oldView.window {
            oldWindow.orderOut(nil)
        }
        
        // Clear view reference - window will deallocate naturally
        overlayView = nil
        
        // Create new window
        let screenFrame = NSScreen.screens.map { $0.frame }.reduce(CGRect.zero) { $0.union($1) }
        let newWindow = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        newWindow.level = .screenSaver
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.ignoresMouseEvents = true
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Create view
        let newView = LoadingCursorView(frame: screenFrame, spinnerSize: spinnerSize, offset: offsetFromCursor)
        newWindow.contentView = newView
        
        // Store only the view - access window through view.window
        overlayView = newView
        isActive = true
        
        newWindow.makeKeyAndOrderFront(nil)
        
        // Start mouse tracking and animation
        startTracking()
    }
    
    func hide() {
        // Always dispatch to main thread for UI operations
        if Thread.isMainThread {
            performHide()
        } else {
            DispatchQueue.main.sync { [self] in
                self.performHide()
            }
        }
    }
    
    private func performHide() {
        // Set flag FIRST - this stops timer callbacks from proceeding
        isActive = false
        
        // Stop timer - prevents any more callbacks
        let timer = mouseTimer
        mouseTimer = nil
        timer?.invalidate()
        
        // Get view reference before clearing
        let viewRef = overlayView
        
        // Clear property reference immediately so timer callbacks see nil
        overlayView = nil
        
        // Order out window through view's window property (don't explicitly close - let it deallocate)
        if let view = viewRef, let win = view.window {
            win.orderOut(nil)
        }
    }
    
    private func startTracking() {
        // Single timer for both mouse tracking and animation
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            // Check flag first - if not active, stop immediately
            guard let self = self, self.isActive else {
                timer.invalidate()
                return
            }
            
            // Check isActive again before doing anything
            guard self.isActive else {
                timer.invalidate()
                return
            }
            
            // Get view - check it exists
            guard let v = self.overlayView else {
                timer.invalidate()
                return
            }
            
            // Check isActive again after getting view reference
            guard self.isActive, v == self.overlayView else {
                timer.invalidate()
                return
            }
            
            // Get window through view's window property
            guard let win = v.window else {
                timer.invalidate()
                return
            }
            
            // Update mouse position
            let screenLocation = NSEvent.mouseLocation
            
            // Check isActive and view is still valid before accessing window
            guard self.isActive, self.overlayView == v else { return }
            
            // Get window frame - access through view.window
            let windowFrame = win.frame
            
            // Check immediately after accessing frame
            guard self.isActive, self.overlayView == v else { return }
            
            let windowLocation = CGPoint(
                x: screenLocation.x - windowFrame.origin.x,
                y: screenLocation.y - windowFrame.origin.y
            )
            
            // Final check before updating
            guard self.isActive, self.overlayView == v else { return }
            
            // Update view - do this quickly
            v.updatePosition(windowLocation)
            v.incrementRotation()
            v.needsDisplay = true
        }
        
        if let timer = mouseTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

// MARK: - LoadingCursorView

private final class LoadingCursorView: NSView {
    private let spinnerSize: CGFloat
    private let offsetFromCursor: CGFloat
    private var cursorPosition: CGPoint = .zero
    private var rotationAngle: CGFloat = 0
    // Note: All access is on main thread (timer and draw), so no lock needed
    
    init(frame: NSRect, spinnerSize: CGFloat, offset: CGFloat) {
        self.spinnerSize = spinnerSize
        self.offsetFromCursor = offset
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePosition(_ position: CGPoint) {
        // Called from timer on main thread
        cursorPosition = position
    }
    
    func incrementRotation() {
        // Called from timer on main thread
        rotationAngle += 0.2
        if rotationAngle >= 2 * .pi {
            rotationAngle -= 2 * .pi
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw is always on main thread, timer is also on main thread
        let pos = cursorPosition
        let angle = rotationAngle
        
        let center = CGPoint(
            x: pos.x + offsetFromCursor,
            y: pos.y + offsetFromCursor
        )
        
        // Bounds check
        let margin: CGFloat = 50
        if center.x < -margin || center.x > bounds.width + margin ||
           center.y < -margin || center.y > bounds.height + margin {
            return
        }
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        
        let radius = spinnerSize / 2
        let lineWidth: CGFloat = 2.5
        
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: radius - lineWidth / 2,
            startAngle: 0,
            endAngle: 2 * .pi * 0.75,
            clockwise: false
        )
        
        context.setShadow(
            offset: CGSize(width: 0, height: -1),
            blur: 2,
            color: NSColor.black.withAlphaComponent(0.3).cgColor
        )
        
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.addPath(path)
        context.strokePath()
        
        context.restoreGState()
    }
}
