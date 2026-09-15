import AppKit
import SwiftUI
import ServiceManagement
import CueCore

final class CueModel: ObservableObject {
    let preferences = Preferences()
    let monitor = SystemMonitor()
    let keyboard = MediaKeyController()
    lazy var overlay = OverlayController(preferences: preferences)
    @Published var page: CuePage = .overview { didSet { updateReadoutActivity() } }
    @Published var windowVisible = false
    @Published var message = ""
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    private var activationObserver: NSObjectProtocol?
    private var deactivationObserver: NSObjectProtocol?
    private var resumeWork: DispatchWorkItem?
    private var scheduledResume: Date?
    private var pendingBrightness: DispatchWorkItem?
    private var installationGuard: InstallationGuard?
    init() {
        preferences.changed = { [weak self] in self?.apply() }
        monitor.event = { [weak self] kind, value, title, flag in
            guard let self, self.preferences.accepts(kind) else { return }
            if kind == .charging && !flag && !self.preferences.settings.showDisconnect { return }
            self.overlay.show(CueEvent(kind: kind, value: value, title: title, flag: flag))
            if kind == .charging, flag, self.preferences.settings.chargingSound { NSSound(named: "Glass")?.play() }
        }
        keyboard.handle = { [weak self] key, fine, held in self?.handleKey(key, fine: fine, held: held) ?? false }
        activationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.apply() }
        deactivationObserver = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.updateReadoutActivity() }
        installationGuard = InstallationGuard { [weak self] in
            self?.keyboard.stop(); self?.overlay.closeImmediately()
            if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
            NSApp.terminate(nil)
        }
        apply()
    }
    private func handleKey(_ key: MediaKey, fine: Bool, held: Double) -> Bool {
        guard preferences.active else { return false }
        let settings = preferences.settings
        if !settings.replaceHUD {
            if key.kind == .brightness && preferences.accepts(.brightness) {
                // Deliberate media-key input is the trigger, never display polling.
                if pendingBrightness == nil {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.pendingBrightness = nil
                        guard self.preferences.accepts(.brightness) else { return }
                        self.monitor.sampleBrightness(origin: .keyboard)
                    }
                    pendingBrightness = work
                    // Throttle rather than debounce: a held key still updates
                    // continuously instead of waiting until the user releases it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
                }
            }
            return false
        }
        let response = KeyResponse(step: (key.kind == .volume ? settings.volumeStep : settings.brightnessStep) / 100,
            acceleration: settings.acceleration, delay: settings.accelerationDelay, ramp: settings.accelerationRamp,
            ceiling: key.kind == .volume ? settings.maximumVolume / 100 : 1)
        if key.kind == .brightness {
            guard let level = monitor.display.level else { return false }
            let next = response.adjusted(level, key: key, held: held, fine: fine)
            guard monitor.display.set(next) else { return false }
            monitor.sampleBrightness(origin: .keyboard)
            return true
        }
        if key == .mute {
            guard monitor.audio.setMuted(!monitor.audio.muted) else { return false }
        } else {
            guard let level = monitor.audio.volume else { return false }
            let next = response.adjusted(level, key: key, held: held, fine: fine)
            guard monitor.audio.setVolume(next) else { return false }
            if monitor.audio.muted { _ = monitor.audio.setMuted(false) }
        }
        monitor.sampleAudio()
        if preferences.accepts(.volume) { overlay.show(CueEvent(kind: .volume, value: monitor.muted ? 0 : (monitor.volume ?? 0), title: monitor.muted ? "Muted" : "Volume", flag: monitor.muted)) }
        return true
    }
    func apply() {
        keyboard.trusted = AXIsProcessTrusted()
        if preferences.active && keyboard.trusted { keyboard.start() } else { keyboard.stop() }
        updateReadoutActivity()
        scheduleResume()
        if !preferences.active { pendingBrightness?.cancel(); pendingBrightness = nil; overlay.closeImmediately() }
        else { overlay.refreshAppearance() }
    }
    func setWindowVisible(_ visible: Bool) { windowVisible = visible; updateReadoutActivity() }
    func updateReadoutActivity() {
        monitor.setReadoutActive(windowVisible && NSApp.isActive && page == .brightness)
    }
    func pause(minutes: Double) { preferences.settings.pauseUntil = Date().addingTimeInterval(minutes * 60) }
    func resume() { preferences.settings.pauseUntil = nil }
    private func scheduleResume() {
        guard scheduledResume != preferences.settings.pauseUntil else { return }
        resumeWork?.cancel(); resumeWork = nil
        scheduledResume = preferences.settings.pauseUntil
        guard let date = scheduledResume else { return }
        let work = DispatchWorkItem { [weak self] in self?.preferences.settings.pauseUntil = nil }
        resumeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, date.timeIntervalSinceNow), execute: work)
    }
    func preview(_ kind: CueKind, value: Double? = nil, shared: Bool = false) {
        let number = value ?? (kind == .volume ? monitor.volume : kind == .brightness ? monitor.brightness : monitor.power?.percent) ?? 0.65
        overlay.show(CueEvent(kind: kind, value: number, title: kind == .charging ? "Charging" : kind.title, flag: kind == .charging), shared: shared)
    }
    func setLevel(_ kind: CueKind, value: Double) {
        if kind == .brightness {
            if monitor.display.set(value) { monitor.sampleBrightness(origin: .cueControl) }
            else { message = "This display does not support brightness control." }
        } else {
            guard monitor.audio.setVolume(min(value, preferences.settings.maximumVolume / 100)) else { message = "This output does not support software volume control."; return }
            if monitor.audio.muted { _ = monitor.audio.setMuted(false) }
            monitor.sampleAudio()
        }
    }
    func restoreAppleHUDsAndQuit() {
        preferences.settings.replaceHUD = false
        keyboard.stop(); overlay.closeImmediately()
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
        NSApp.terminate(nil)
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { message = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    deinit {
        resumeWork?.cancel(); pendingBrightness?.cancel()
        if let deactivationObserver { NotificationCenter.default.removeObserver(deactivationObserver) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }
}

@main
struct CueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: CueModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let index = CommandLine.arguments.firstIndex(of: "--settings-probe-suite"), CommandLine.arguments.count > index + 1 {
            let suite = CommandLine.arguments[index + 1]
            guard suite.hasPrefix("com.softlymac.cue.diagnostics.") else { exit(2) }
            let saved = Preferences(defaults: UserDefaults(suiteName: suite)!).settings
            exit(!saved.enabled && !saved.volume && !saved.brightness && !saved.charging && saved.replaceHUD && !saved.savedLooks.isEmpty ? 0 : 1)
        }
        if CommandLine.arguments.contains("--integration-check") {
            let success = runIntegrationChecks()
            exit(success ? 0 : 1)
        }
        launchWhenPreviousCopyExits(attempt: 0)
    }
    private func launchWhenPreviousCopyExits(attempt: Int) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Preferences.domain).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }
        if !others.isEmpty {
            if attempt == 0 { others.forEach { _ = $0.terminate() } }
            guard attempt < 20 else {
                let alert = NSAlert(); alert.messageText = "Cue is already running"
                alert.informativeText = "Quit the other copy of Cue, then open this one. Your settings are safe."
                alert.runModal(); NSApp.terminate(nil); return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.launchWhenPreviousCopyExits(attempt: attempt + 1) }
            return
        }
        finishLaunching()
    }
    private func finishLaunching() {
        model = CueModel()
        let menu = NSMenu()
        menu.addItem(withTitle: "About Cue", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cue Settings…", action: #selector(showWindow), keyEquivalent: ",")
        menu.addItem(withTitle: "Pause Cue", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Pause for 15 Minutes", action: #selector(pauseBriefly), keyEquivalent: "")
        menu.addItem(withTitle: "Pause for 1 Hour", action: #selector(pauseHour), keyEquivalent: "")
        menu.addItem(withTitle: "Show Apple Keyboard HUDs", action: #selector(toggleAppleHUDs), keyEquivalent: "")
        menu.addItem(.separator())
        for (title, action) in [("Preview Volume", #selector(previewVolume)), ("Preview Brightness", #selector(previewBrightness)), ("Preview Charging", #selector(previewCharging))] { menu.addItem(withTitle: title, action: action, keyEquivalent: "") }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cue", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        menu.delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Cue")
        statusItem.button?.toolTip = "Cue — your Mac, with a little character"
        statusItem.menu = menu
        let root = CueDashboard(model: model, preferences: model.preferences, monitor: model.monitor, keyboard: model.keyboard)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Cue"; window.titlebarAppearsTransparent = true
        window.delegate = self; window.setFrameAutosaveName("CueSettingsWindow")
        window.toolbar = NSToolbar(identifier: "CueToolbar"); window.toolbarStyle = .unified
        window.minSize = NSSize(width: 860, height: 640)
        window.contentView = NSHostingView(rootView: root)
        window.isReleasedWhenClosed = false
        window.center()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "About Cue", action: #selector(showAbout), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit Cue", action: #selector(quit), keyEquivalent: "q")
        for item in applicationMenu.items { item.target = self }
        appItem.submenu = applicationMenu; appMenu.addItem(appItem)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.submenu = editMenu; appMenu.addItem(edit); NSApp.mainMenu = appMenu
        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue ?? false
        if !CommandLine.arguments.contains("--background") && !loginLaunch { showWindow() }
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                print("CUE_SMOKE volume=\(self.model.monitor.volume.map(String.init(describing:)) ?? "unavailable") brightness=\(self.model.monitor.brightness.map(String.init(describing:)) ?? "unavailable") battery=\(self.model.monitor.power?.label ?? "unavailable")")
                self.model.preview(.volume, value: 0.65)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
            }
        }
    }
    @objc func showWindow() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); model.setWindowVisible(true); model.apply() }
    func windowWillClose(_ notification: Notification) { model.setWindowVisible(false); model.preferences.flush() }
    func windowDidMiniaturize(_ notification: Notification) { model.setWindowVisible(false) }
    func windowDidDeminiaturize(_ notification: Notification) { model.setWindowVisible(true) }
    func windowDidChangeOcclusionState(_ notification: Notification) { model.setWindowVisible(window.occlusionState.contains(.visible)) }
    @objc func pauseBriefly() { model.pause(minutes: 15) }
    @objc func pauseHour() { model.pause(minutes: 60) }
    @objc func showAbout() { model.page = .general; showWindow() }
    @objc func toggle() { if model.preferences.temporarilyPaused { model.resume() } else { model.preferences.enabled.toggle() } }
    @objc func toggleAppleHUDs() { model.preferences.settings.replaceHUD.toggle() }
    @objc func previewVolume() { model.preview(.volume) }
    @objc func previewBrightness() { model.preview(.brightness) }
    @objc func previewCharging() { model.preview(.charging) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model?.preferences.flush(); model?.keyboard.stop(); model?.overlay.closeImmediately() }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        model.apply()
        menu.items.first { $0.action == #selector(toggleAppleHUDs) }?.state = model.preferences.settings.replaceHUD ? .off : .on
        menu.items.first { $0.action == #selector(toggle) }?.title = model.preferences.temporarilyPaused ? "Resume Cue Now" : model.preferences.enabled ? "Pause Cue" : "Resume Cue"
    }
}
