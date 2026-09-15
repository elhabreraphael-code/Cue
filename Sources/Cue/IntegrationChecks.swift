import AppKit
import CueCore

// Opt-in local diagnostics; no hardware writes and no changes to the user's
// preferences or Accessibility settings.
func runIntegrationChecks() -> Bool {
    var failures: [String] = []
    var count = 0
    func check(_ value: Bool, _ label: String) {
        count += 1
        if !value { failures.append(label) }
        print("\(value ? "PASS" : "FAIL"): \(label)")
    }
    let suite = "com.softlymac.cue.diagnostics.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "enabled"); defaults.set("Orbit", forKey: "style")
    defaults.set("Top", forKey: "position"); defaults.set(1.2, forKey: "scale")
    let preferences = Preferences(defaults: defaults)
    check(preferences.settings.appearance.style == .orbit && preferences.settings.appearance.position == .top, "Migrate alpha 1 appearance")
    preferences.settings.appearance.style = .glass
    var phone = HUDConfiguration(); phone.style = .iphone; phone.position = .right; phone.scale = 1.7
    phone.accent = .custom; phone.customRed = 0.8; phone.customGreen = 0.2; phone.customBlue = 0.6
    preferences.settings.overrides[CueKind.volume.rawValue] = phone
    preferences.settings.volumeStep = 2.5; preferences.settings.acceleration = 2.0
    let reloaded = Preferences(defaults: defaults)
    check(reloaded.configuration(for: .volume) == phone, "Per-event colors, position, and scale survive relaunch")
    check(reloaded.configuration(for: .brightness).style == .glass, "Volume override does not change brightness")
    check(reloaded.settings.volumeStep == 2.5 && reloaded.settings.acceleration == 2, "Keyboard response survives relaunch")
    reloaded.settings.overrides.removeValue(forKey: CueKind.volume.rawValue)
    check(reloaded.configuration(for: .volume).style == .glass, "Removing an override restores shared look")
    var invalid = HUDConfiguration(); invalid.scale = 100; invalid.speed = 0; invalid.duration = -5
    let safe = invalid.sanitized()
    check(safe.scale == 2 && safe.speed == 0.5 && safe.duration == 0.5, "Invalid saved ranges are clamped")
    reloaded.settings.enabled = false; reloaded.settings.volume = false
    reloaded.settings.brightness = false; reloaded.settings.charging = false
    reloaded.settings.replaceHUD = true
    reloaded.saveLook(name: "My quiet look", configuration: phone)
    reloaded.flush()
    let toggles = Preferences(defaults: defaults)
    check(!toggles.enabled && !toggles.settings.volume && !toggles.settings.brightness && !toggles.settings.charging && toggles.settings.replaceHUD, "All hidden-HUD choices survive reload")
    check(toggles.settings.savedLooks.first?.configuration == phone, "Saved look survives reload intact")
    let probe = Process(); probe.executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    probe.arguments = ["--settings-probe-suite", suite]
    let pipe = Pipe(); probe.standardOutput = pipe; probe.standardError = pipe
    do {
        try probe.run(); probe.waitUntilExit()
        check(probe.terminationStatus == 0, "Hidden-HUD settings and saved looks survive a separate process launch")
    } catch { check(false, "Preference probe launched: \(error.localizedDescription)") }
    let partial = Data(#"{"replaceHUD":true,"volume":false,"brightness":false,"appearance":{"style":"Compact","scale":0.9,"material":"FutureMaterial"}}"#.utf8)
    defaults.set(partial, forKey: "cueSettingsV2")
    let migratedPartial = Preferences(defaults: defaults)
    check(migratedPartial.settings.replaceHUD && !migratedPartial.settings.volume && !migratedPartial.settings.brightness, "Missing future fields do not reset hidden-HUD switches")
    check(migratedPartial.settings.appearance.style == .compact && migratedPartial.settings.appearance.scale == 0.9, "One unknown material does not erase the saved design")
    defaults.set(Data("broken-json".utf8), forKey: "cueSettingsV2")
    let recovered = Preferences(defaults: defaults)
    check(recovered.settings.replaceHUD && !recovered.settings.volume, "Damaged primary settings recover from last valid backup")
    recovered.settings.pauseUntil = Date().addingTimeInterval(120)
    let paused = Preferences(defaults: defaults)
    check(paused.temporarilyPaused && !paused.accepts(.volume) && paused.enabled, "Temporary pause survives relaunch without changing enable choice")
    paused.settings.pauseUntil = Date().addingTimeInterval(-1)
    let resumed = Preferences(defaults: defaults)
    check(resumed.active && resumed.settings.pauseUntil == nil, "Expired pause resumes without leaving Cue disabled")
    // V4 migration, portable looks, quiet policy, and preset scope.
    check(!migratedPartial.settings.showOutputChanges && !migratedPartial.settings.showOutputName && migratedPartial.settings.quietApps.isEmpty, "V3 migration leaves new optional features off")
    resumed.settings.quietApps = [QuietApp(id: "com.example.Presentation", name: "Presentation")]
    resumed.settings.showOutputChanges = true; resumed.settings.showOutputName = true
    let newFeatures = Preferences(defaults: defaults)
    check(newFeatures.settings.showOutputChanges && newFeatures.settings.showOutputName, "Output feedback choices survive reload")
    check(newFeatures.isQuiet(in: "com.example.Presentation"), "Chosen frontmost app is quiet")
    check(!newFeatures.isQuiet(in: "com.example.Other") && !newFeatures.isQuiet(in: nil), "Other and missing frontmost apps remain eligible")
    check(newFeatures.active && newFeatures.accepts(.charging), "Quiet list does not overwrite enable or event settings")
    for preset in MotionPreset.allCases {
        let next = preset.apply(to: phone)
        check(next.position == phone.position && next.style == phone.style && next.accent == phone.accent && next.scale == phone.scale, "Motion preset preserves design and placement: \(preset.rawValue)")
        check(preset.matches(next), "Motion preset is recognized: \(preset.rawValue)")
    }
    do {
        var exportConfig = phone; exportConfig.style = .slim
        let encoded = try LookDocument(name: "Portable look", configuration: exportConfig).encoded()
        let decoded = try LookDocument.decode(encoded)
        check(decoded.configuration == exportConfig && decoded.name == "Portable look", "Portable look round-trips all appearance values")
        let json = String(decoding: encoded, as: UTF8.self)
        check(!json.contains("replaceHUD") && !json.contains("quietApps") && !json.contains("volumeStep"), "Export contains no keyboard behavior or quiet app list")
        check((try? LookDocument.decode(Data("{}".utf8))) == nil, "Unrelated JSON is rejected")
        check((try? LookDocument.decode(Data(json.replacingOccurrences(of: "com.softlymac.cue.look", with: "another.format").utf8))) == nil, "Foreign look format is rejected")
        check((try? LookDocument.decode(Data(json.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99").utf8))) == nil, "Future incompatible look is rejected")
        check((try? LookDocument.decode(Data(repeating: 65, count: 256_001))) == nil, "Oversized look file is rejected")
    } catch { check(false, "Look round-trip: \(error)") }
    // Exercise actual scheduled panel lifecycle, including updates that arrive
    // while its exit animation is still running.
    resumed.settings.appearance.duration = 0.5; resumed.settings.appearance.speed = 2
    let overlay = OverlayController(preferences: resumed)
    overlay.show(CueEvent(value: 0.25))
    RunLoop.main.run(until: Date().addingTimeInterval(0.04))
    check(overlay.isPresented && overlay.isAnimatingIn, "HUD enters after first show")
    overlay.close()
    overlay.show(CueEvent(value: 0.8))
    RunLoop.main.run(until: Date().addingTimeInterval(0.35))
    check(overlay.isPresented && overlay.isAnimatingIn && overlay.currentEvent.value == 0.8, "New level reverses dismissal and stale hide cannot remove it")
    overlay.show(CueEvent(kind: .brightness, value: 0.4, title: "Brightness"))
    check(overlay.currentEvent.kind == .brightness && overlay.currentEvent.value == 0.4, "Switching event kinds immediately uses the correct level")
    overlay.show(CueEvent(value: .nan))
    check(overlay.currentEvent.value == 0, "Non-finite HUD payload is bounded")
    overlay.closeImmediately()
    RunLoop.main.run(until: Date().addingTimeInterval(0.04))
    check(!overlay.isPresented && !overlay.isAnimatingIn, "Immediate close cancels every pending entrance")
    overlay.show(CueEvent(value: 0.5))
    RunLoop.main.run(until: Date().addingTimeInterval(0.95))
    check(!overlay.isPresented, "HUD automatically leaves after hold and exit")
    let monitor = SystemMonitor()
    check(!monitor.readoutTimerActive, "No brightness polling timer at startup")
    monitor.setReadoutActive(true)
    check(monitor.readoutTimerActive, "Visible brightness readout starts its timer")
    monitor.setReadoutActive(false)
    check(!monitor.readoutTimerActive, "Closing brightness readout destroys its timer")
    var events: [CueKind] = []
    monitor.event = { kind, _, _, _ in events.append(kind) }
    monitor.sampleBrightness(origin: .system)
    monitor.sampleBrightness(origin: .system)
    check(events.isEmpty, "Real display polling emits no automatic-brightness events")
    if monitor.brightness != nil {
        monitor.sampleBrightness(origin: .keyboard)
        check(events == [.brightness], "Manual-key sampling emits one brightness event")
        monitor.sampleBrightness(origin: .system)
        check(events.count == 1, "Subsequent display telemetry remains silent")
        monitor.sampleBrightness(origin: .cueControl)
        check(events.count == 2, "Cue-control sampling emits an explicit brightness event")
    }
    for style in CueStyle.allCases {
        for scale in [0.5, 1.0, 2.0] {
            var config = HUDConfiguration(); config.style = style; config.scale = scale
            config.width = 1.5; config.height = 1.5
            let screen = CGRect(x: -800, y: 40, width: 800, height: 550)
            let fit = min(scale, (screen.width - 20) / config.size.width, (screen.height - 20) / config.size.height)
            let size = CGSize(width: config.size.width * fit, height: config.size.height * fit)
            let frame = hudFrame(in: screen, size: size, anchor: .bottomRight, margin: 180, offsetX: 500, offsetY: -350)
            check(screen.contains(frame), "Extreme size and offsets stay on screen: \(style.rawValue), \(scale)×")
        }
    }
    if let rootIndex = CommandLine.arguments.firstIndex(of: "--check-directory"), CommandLine.arguments.count > rootIndex + 1 {
        let root = URL(fileURLWithPath: CommandLine.arguments[rootIndex + 1]).appendingPathComponent("Guard-\(UUID().uuidString)")
        let bundle = root.appendingPathComponent("Disposable.app")
        do {
            try FileManager.default.createDirectory(at: bundle.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
            let plist: [String: Any] = ["CFBundleExecutable": "Probe", "CFBundleIdentifier": "com.softlymac.cue.guard-test", "CFBundlePackageType": "APPL"]
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Contents/Info.plist"))
            try Data("probe".utf8).write(to: bundle.appendingPathComponent("Contents/MacOS/Probe"))
            var removalDetected = false
            let guardObject = InstallationGuard(bundleURL: bundle) { removalDetected = true }
            check(!removalDetected, "Existing bundle does not trigger removal guard")
            try FileManager.default.moveItem(at: bundle, to: root.appendingPathComponent("Removed.app"))
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            check(removalDetected, "Moving a running bundle triggers release callback")
            withExtendedLifetime(guardObject) {}
            try FileManager.default.removeItem(at: root)
            let parentRoot = root.appendingPathComponent("Container")
            let nested = parentRoot.appendingPathComponent("Nested.app")
            try FileManager.default.createDirectory(at: nested.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: nested.appendingPathComponent("Contents/Info.plist"))
            try Data("probe".utf8).write(to: nested.appendingPathComponent("Contents/MacOS/Probe"))
            var parentMoveDetected = false
            let parentGuard = InstallationGuard(bundleURL: nested) { parentMoveDetected = true }
            try FileManager.default.moveItem(at: parentRoot, to: root.appendingPathComponent("MovedContainer"))
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            check(!parentGuard.verifyNow() && parentMoveDetected, "Containing-folder relocation is detected before the next control interaction")
            withExtendedLifetime(parentGuard) {}
            try FileManager.default.removeItem(at: root)
        } catch { check(false, "Removal guard test: \(error.localizedDescription)") }
    }
    print("CUE_INTEGRATION: \(count - failures.count)/\(count) passed")
    return failures.isEmpty
}
