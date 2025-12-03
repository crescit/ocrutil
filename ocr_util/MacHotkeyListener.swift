//
//  MacHotkeyListener.swift
//  ocr_util
//
//  Global hotkey listener using Carbon.
//

import Cocoa
import Carbon.HIToolbox

final class MacHotkeyListener: HotkeyListening {
    var onHotkeyPressed: (() -> Void)?

    private var keyCode: UInt32
    private var modifiers: NSEvent.ModifierFlags

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func startListening() {
        stopListening() // Clean up any existing registration
        
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { (_, _, userData) -> OSStatus in
            guard let userData else { return noErr }
            let listener = Unmanaged<MacHotkeyListener>.fromOpaque(userData).takeUnretainedValue()
            listener.onHotkeyPressed?()
            return noErr
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPointer, &eventHandler)

        var hotKeyID = EventHotKeyID(signature: OSType(FOUR_CHAR_CODE("OCR1")), id: 1)

        let carbonModifiers = carbonModifierFlags(from: modifiers)
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func updateHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        startListening() // Restart with new configuration
    }
    
    private func stopListening() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            self.eventHandler = nil
        }
    }

    deinit {
        stopListening()
    }

    private func carbonModifierFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }
}

private func FOUR_CHAR_CODE(_ code: String) -> Int {
    var result: Int = 0
    for char in code.utf16 {
        result = (result << 8) + Int(char)
    }
    return result
}
