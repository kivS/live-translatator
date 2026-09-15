import AppKit
import SwiftUI
import ScreenCaptureKit

final class TranslationPanel: NSPanel {
    var onDismiss: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
        orderOut(sender)
    }
}

@MainActor
final class CaptureCoordinator {
    private var overlays: [NSWindow] = []
    private var resultWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let state = TranslationState()
    private var task: Task<Void, Never>?
    private var preparing = false
    private var lastCapture: Data?

    func begin() {
        guard !preparing, overlays.isEmpty else { return }
        preloadModel()
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showError("Screen Recording access is not available to this copy of RegionTranslate. In System Settings → Privacy & Security → Screen Recording, remove the old RegionTranslate entry and add /Applications/RegionTranslate.app, then enable it and quit and reopen the app.")
            return
        }
        task?.cancel()
        state.loading = false
        preparing = true
        resultWindow?.orderOut(nil)
        settingsWindow?.orderOut(nil)
        Task { [self] in
            defer { preparing = false }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                var snapshots: [(NSScreen, CGImage)] = []
                for screen in NSScreen.screens {
                    guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                          let display = content.displays.first(where: { $0.displayID == id }) else { continue }
                    let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
                    let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
                    let config = SCStreamConfiguration()
                    config.width = Int(screen.frame.width * screen.backingScaleFactor)
                    config.height = Int(screen.frame.height * screen.backingScaleFactor)
                    config.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    snapshots.append((screen, image))
                }
                guard !snapshots.isEmpty else { throw TranslationClient.Failure.message("No display is available to capture.") }
                for (screen, image) in snapshots {
                    let window = SelectionWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
                    window.level = .screenSaver
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.isReleasedWhenClosed = false
                    let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), screenshot: image)
                    view.onCancel = { [weak self] in self?.dismissOverlays() }
                    view.onConfirm = { [weak self] rect in self?.submit(rect: rect, image: image, size: screen.frame.size) }
                    window.contentView = view
                    overlays.append(window)
                    window.orderFrontRegardless()
                    if screen.frame.contains(NSEvent.mouseLocation) {
                        window.makeKey()
                        window.makeFirstResponder(view)
                    }
                }
                NSApp.activate(ignoringOtherApps: true)
            } catch { showError(error.localizedDescription) }
        }
    }

    private func preloadModel() {
        let endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "http://localhost:8080/v1"
        let model = UserDefaults.standard.string(forKey: "model") ?? TranslationClient.defaultModel
        Task {
            try? await TranslationClient().loadModel(endpoint: endpoint, model: model)
        }
    }

    private func dismissOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    private func submit(rect: CGRect, image: CGImage, size: CGSize) {
        let pixelRect = CGRect(x: rect.minX * CGFloat(image.width) / size.width,
                               y: (size.height - rect.maxY) * CGFloat(image.height) / size.height,
                               width: rect.width * CGFloat(image.width) / size.width,
                               height: rect.height * CGFloat(image.height) / size.height).integral
        guard let cropped = image.cropping(to: pixelRect),
              let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:]) else {
            dismissOverlays()
            showError("Could not capture this region. Please select it again.")
            return
        }
        dismissOverlays()
        state.preview = NSImage(cgImage: cropped, size: rect.size)
        lastCapture = png
        translateLastCapture()
    }

    private func translateLastCapture() {
        guard let png = lastCapture, !state.loading else { return }
        task?.cancel()
        state.text = ""
        state.error = nil
        state.loading = true
        showResult()
        let endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "http://localhost:8080/v1"
        let model = UserDefaults.standard.string(forKey: "model") ?? TranslationClient.defaultModel
        task = Task {
            do {
                let text = try await TranslationClient().translate(image: png, endpoint: endpoint, model: model)
                guard !Task.isCancelled else { return }
                state.text = text
            } catch {
                guard !Task.isCancelled else { return }
                state.error = error.localizedDescription
            }
            state.loading = false
        }
    }

    func showError(_ message: String) {
        state.loading = false
        state.text = ""
        state.error = message
        showResult()
    }

    private func showResult() {
        if resultWindow == nil {
            let window = TranslationPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            window.title = "RegionTranslate"
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.onDismiss = { [weak self] in
                self?.task?.cancel()
                self?.state.loading = false
            }
            window.contentView = NSHostingView(rootView: TranslationView(state: state, capture: { [weak self] in self?.begin() }, cancel: { [weak self] in
                self?.task?.cancel()
                self?.state.loading = false
                self?.state.text = "Translation cancelled."
            }, retry: { [weak self] in self?.translateLastCapture() }, settings: { [weak self] in self?.showSettings() }))
            window.center()
            resultWindow = window
        }
        resultWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 350), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "RegionTranslate Settings"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
