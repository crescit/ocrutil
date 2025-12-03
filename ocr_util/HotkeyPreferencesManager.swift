//
//  HotkeyPreferencesManager.swift
//  ocr_util
//
//  Manages hotkey preferences storage and retrieval.
//

import Foundation
import Cocoa
import Carbon.HIToolbox

struct HotkeyConfiguration: Codable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags.RawValue
    
    static let `default`: HotkeyConfiguration = {
        let modifiers: NSEvent.ModifierFlags = [.command, .option]
        return HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_Slash),
            modifiers: modifiers.rawValue
        )
    }()
}

final class HotkeyPreferencesManager {
    static let shared = HotkeyPreferencesManager()
    
    private let keyCodeKey = "hotkeyKeyCode"
    private let modifiersKey = "hotkeyModifiers"
    
    private init() {}
    
    func loadConfiguration() -> HotkeyConfiguration {
        let keyCode = UserDefaults.standard.object(forKey: keyCodeKey) as? UInt32 ?? HotkeyConfiguration.default.keyCode
        let modifiersRaw = UserDefaults.standard.object(forKey: modifiersKey) as? UInt ?? HotkeyConfiguration.default.modifiers
        
        return HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: modifiersRaw
        )
    }
    
    func saveConfiguration(_ config: HotkeyConfiguration) {
        UserDefaults.standard.set(config.keyCode, forKey: keyCodeKey)
        UserDefaults.standard.set(config.modifiers, forKey: modifiersKey)
        UserDefaults.standard.synchronize()
    }
    
    func getModifiers() -> NSEvent.ModifierFlags {
        let config = loadConfiguration()
        return NSEvent.ModifierFlags(rawValue: config.modifiers)
    }
    
    func getKeyCode() -> UInt32 {
        let config = loadConfiguration()
        return config.keyCode
    }
}

