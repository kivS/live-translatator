import SwiftUI

@main
struct RegionTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { SettingsView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private let coordinator = CaptureCoordinator()
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Translate a screen region")
        status.button?.target = self
        status.button?.action = #selector(clicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hotKey = GlobalHotKey { [weak self] in self?.coordinator.begin() }
        if hotKey?.registered == false {
            coordinator.showError("⌥⌘T is already in use. You can still start a capture from the menu bar icon.")
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Translate Region  ⌥⌘T", action: #selector(capture), keyEquivalent: "")
            menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit RegionTranslate", action: #selector(quit), keyEquivalent: "")
            menu.items.forEach { $0.target = self }
            status.menu = menu
            status.button?.performClick(nil)
            status.menu = nil
        } else { coordinator.begin() }
    }
    @objc private func capture() { coordinator.begin() }
    @objc private func settings() { coordinator.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
