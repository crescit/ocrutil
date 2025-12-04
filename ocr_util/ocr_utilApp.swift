//
//  ocr_utilApp.swift
//  ocr_util
//

import SwiftUI
import Cocoa
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var coordinator: CaptureCoordinator?
    private var overlayController: SelectionOverlayWindowController?
    private var openLogsItem: NSMenuItem?
    private var aboutWindowController: AboutWindowController?
    private var licensesWindowController: LicensesWindowController?
    private var hotkeyListener: MacHotkeyListener?
    private var hotkeySettingsWindowController: HotkeySettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only (no Dock)
        NSApp.setActivationPolicy(.accessory)

        // Ensure logger is initialized so log directory exists early
        DebugLogger.log("📒 ocr_util launched (version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"))")

        showFirstRunIntroIfNeeded()
        setupStatusItem()
        setupCapturePipeline()
    }

    /// Shows a one-time intro explaining how the tool works and what system
    /// permissions it will request the first time the user draws a bounding box.
    private func showFirstRunIntroIfNeeded() {
        let defaults = UserDefaults.standard
        // Use bundle identifier to ensure dev and distribution builds have separate flags
        let bundleID = Bundle.main.bundleIdentifier ?? "ocr_util"
        let hasShownIntroKey = "\(bundleID).hasShownIntro"

        guard defaults.bool(forKey: hasShownIntroKey) == false else {
            return
        }

        let introController = IntroWindowController {
            // On dismiss, mark as shown
            defaults.set(true, forKey: hasShownIntroKey)
        }
        
        introController.showModal()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Use any SF Symbol you like here
            button.image = NSImage(
                systemSymbolName: "text.viewfinder",
                accessibilityDescription: "Screen OCR"
            )
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(openStatusMenu(_:))
        }

        let menu = NSMenu()
        menu.delegate = self

        // About / Privacy
        let aboutItem = NSMenuItem(
            title: "About / Privacy…",
            action: #selector(openAboutWindow),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Licenses
        let licensesItem = NSMenuItem(
            title: "Licenses…",
            action: #selector(openLicensesWindow),
            keyEquivalent: ""
        )
        licensesItem.target = self
        menu.addItem(licensesItem)

        menu.addItem(NSMenuItem.separator())

        let openLogsItem = NSMenuItem(
            title: "Open Logs…",
            action: #selector(openLogs),
            keyEquivalent: "l"
        )
        openLogsItem.target = self
        self.openLogsItem = openLogsItem
        menu.addItem(openLogsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let preferencesItem = NSMenuItem(
            title: "Hot Keys…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupCapturePipeline() {
        let selectionVM = SelectionViewModel()

        // Load hotkey configuration from preferences
        let preferencesManager = HotkeyPreferencesManager.shared
        let config = preferencesManager.loadConfiguration()
        let modifiers = NSEvent.ModifierFlags(rawValue: config.modifiers)
        
        let hotkeyListener = MacHotkeyListener(
            keyCode: config.keyCode,
            modifiers: modifiers
        )
        self.hotkeyListener = hotkeyListener

        let screenshotService = MacScreenshotService()
        let screenshotSaver = MacScreenshotSaver()
        let clipboard = PasteboardClipboard()
        let ocrService = PaddleOCRService.shared

        let coordinator = CaptureCoordinator(
            hotkeyListener: hotkeyListener,
            screenshotService: screenshotService,
            screenshotSaver: screenshotSaver,
            selectionViewModel: selectionVM,
            ocrService: ocrService,
            clipboard: clipboard
        )
        self.coordinator = coordinator

        let overlayController = SelectionOverlayWindowController(viewModel: selectionVM)
        coordinator.delegate = overlayController
        self.overlayController = overlayController
    }

    // MARK: - Actions

    @objc private func openStatusMenu(_ sender: Any?) {
        // If you want a custom menu open behavior, you can tweak this.
        if let menu = statusItem.menu {
            statusItem.popUpMenu(menu)
        }
    }

    @objc private func openLogs() {
        let logURL = DebugLogger.logFileURL
        DebugLogger.log("📂 Opening log file in Finder at \(logURL.path)")
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }

    @objc private func openAboutWindow() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow()
    }

    @objc private func openLicensesWindow() {
        if licensesWindowController == nil {
            licensesWindowController = LicensesWindowController()
        }
        licensesWindowController?.showWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func openPreferences() {
        if hotkeySettingsWindowController == nil {
            hotkeySettingsWindowController = HotkeySettingsWindowController { [weak self] config in
                self?.updateHotkey(config)
            }
        }
        hotkeySettingsWindowController?.showWindow()
    }
    
    private func updateHotkey(_ config: HotkeyConfiguration) {
        let modifiers = NSEvent.ModifierFlags(rawValue: config.modifiers)
        hotkeyListener?.updateHotkey(keyCode: config.keyCode, modifiers: modifiers)
        DebugLogger.log("⌨️ Hotkey updated: \(HotkeySettingsView.formatHotkey(keyCode: config.keyCode, modifiers: modifiers))")
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Check if Option key is currently pressed
        let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
        openLogsItem?.isHidden = !optionKeyPressed
    }
}

@main
struct ocr_utilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No normal window – just an (optional) Settings window
        Settings {
            Text("Screen OCR runs from the menu bar.\nHotkey: ⌘⌥/")
                .padding()
        }
    }
}
