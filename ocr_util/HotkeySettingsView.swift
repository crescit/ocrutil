//
//  HotkeySettingsView.swift
//  ocr_util
//
//  SwiftUI view for configuring hotkeys.
//

import SwiftUI
import Cocoa
import Carbon.HIToolbox

struct HotkeySettingsView: View {
    @State private var keyCode: UInt32
    @State private var commandKey: Bool
    @State private var optionKey: Bool
    @State private var controlKey: Bool
    @State private var shiftKey: Bool
    @State private var isCapturing: Bool = false
    @State private var displayText: String = ""
    @State private var errorMessage: String? = nil
    @State private var globalMonitor: Any? = nil
    @State private var localMonitor: Any? = nil
    
    private let preferencesManager = HotkeyPreferencesManager.shared
    var onSave: ((HotkeyConfiguration) -> Void)?
    
    init(onSave: ((HotkeyConfiguration) -> Void)? = nil) {
        let config = HotkeyPreferencesManager.shared.loadConfiguration()
        let modifiers = NSEvent.ModifierFlags(rawValue: config.modifiers)
        
        _keyCode = State(initialValue: config.keyCode)
        _commandKey = State(initialValue: modifiers.contains(.command))
        _optionKey = State(initialValue: modifiers.contains(.option))
        _controlKey = State(initialValue: modifiers.contains(.control))
        _shiftKey = State(initialValue: modifiers.contains(.shift))
        self.onSave = onSave
        
        _displayText = State(initialValue: Self.formatHotkey(keyCode: config.keyCode, modifiers: modifiers))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configure Hotkey")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Press your desired hotkey combination:")
                    .font(.subheadline)
                
                HStack {
                    TextField("Press keys...", text: .constant(displayText))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                        .frame(width: 200)
                    
                    Button(isCapturing ? "Stop" : "Record") {
                        if isCapturing {
                            stopCapturing()
                        } else {
                            startCapturing()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Text("Current: \(displayText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Modifier Keys:")
                    .font(.subheadline)
                
                Toggle("Command (⌘)", isOn: $commandKey)
                Toggle("Option (⌥)", isOn: $optionKey)
                Toggle("Control (⌃)", isOn: $controlKey)
                Toggle("Shift (⇧)", isOn: $shiftKey)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            HStack {
                Button("Cancel") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    saveConfiguration()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            updateDisplayText()
        }
        .onChange(of: commandKey) { _ in updateDisplayText() }
        .onChange(of: optionKey) { _ in updateDisplayText() }
        .onChange(of: controlKey) { _ in updateDisplayText() }
        .onChange(of: shiftKey) { _ in updateDisplayText() }
        .onChange(of: keyCode) { _ in updateDisplayText() }
        .onDisappear {
            stopCapturing()
        }
    }
    
    private func startCapturing() {
        isCapturing = true
        errorMessage = nil
        displayText = "Press keys..."
        
        // Install a global event monitor to capture key events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            DispatchQueue.main.async {
                if self.isCapturing {
                    self.handleKeyDown(event)
                }
            }
        }
        
        // Also add a local monitor for when the window is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if self.isCapturing {
                self.handleKeyDown(event)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func stopCapturing() {
        isCapturing = false
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        let newKeyCode = UInt32(event.keyCode)
        let newModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        // Require at least one modifier key
        guard !newModifiers.isEmpty else {
            errorMessage = "Please include at least one modifier key (⌘, ⌥, ⌃, or ⇧)"
            return
        }
        
        keyCode = newKeyCode
        commandKey = newModifiers.contains(.command)
        optionKey = newModifiers.contains(.option)
        controlKey = newModifiers.contains(.control)
        shiftKey = newModifiers.contains(.shift)
        
        errorMessage = nil
        stopCapturing()
    }
    
    private func updateDisplayText() {
        var modifiers: NSEvent.ModifierFlags = []
        if commandKey { modifiers.insert(.command) }
        if optionKey { modifiers.insert(.option) }
        if controlKey { modifiers.insert(.control) }
        if shiftKey { modifiers.insert(.shift) }
        
        displayText = Self.formatHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func saveConfiguration() {
        var modifiers: NSEvent.ModifierFlags = []
        if commandKey { modifiers.insert(.command) }
        if optionKey { modifiers.insert(.option) }
        if controlKey { modifiers.insert(.control) }
        if shiftKey { modifiers.insert(.shift) }
        
        guard !modifiers.isEmpty else {
            errorMessage = "Please select at least one modifier key"
            return
        }
        
        let config = HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: modifiers.rawValue
        )
        
        preferencesManager.saveConfiguration(config)
        onSave?(config)
        
        NSApp.keyWindow?.close()
    }
    
    static func formatHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        
        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)
        
        return parts.joined()
    }
    
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_ANSI_Slash): return "/"
        case UInt32(kVK_ANSI_Backslash): return "\\"
        case UInt32(kVK_ANSI_Comma): return ","
        case UInt32(kVK_ANSI_Period): return "."
        case UInt32(kVK_ANSI_Semicolon): return ";"
        case UInt32(kVK_ANSI_Quote): return "'"
        case UInt32(kVK_ANSI_LeftBracket): return "["
        case UInt32(kVK_ANSI_RightBracket): return "]"
        case UInt32(kVK_ANSI_Minus): return "-"
        case UInt32(kVK_ANSI_Equal): return "="
        case UInt32(kVK_ANSI_Grave): return "`"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_ForwardDelete): return "Forward Delete"
        case UInt32(kVK_Escape): return "Esc"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        default:
            return "Key \(keyCode)"
        }
    }
}

