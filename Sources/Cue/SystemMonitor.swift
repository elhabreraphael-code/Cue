import AppKit
import CoreAudio
import IOKit.ps
import CueCore
import Darwin

final class AudioControl {
    private(set) var device = AudioDeviceID(0)
    private var observers: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    var changed: (() -> Void)?
    init() { reconnect() }
    func reconnect() {
        for (id, var address, block) in observers { AudioObjectRemovePropertyListenerBlock(id, &address, .main, block) }
        observers.removeAll()
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        device = 0
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        listen(AudioObjectID(kAudioObjectSystemObject), address) { [weak self] in self?.reconnect(); self?.changed?() }
        for selector in [kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyMute] {
            for element: UInt32 in [0, 1, 2] {
                listen(device, AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)) { [weak self] in self?.changed?() }
            }
        }
    }
    private func listen(_ id: AudioObjectID, _ address: AudioObjectPropertyAddress, action: @escaping () -> Void) {
        var address = address
        guard AudioObjectHasProperty(id, &address) else { return }
        let block: AudioObjectPropertyListenerBlock = { _, _ in action() }
        if AudioObjectAddPropertyListenerBlock(id, &address, .main, block) == noErr { observers.append((id, address, block)) }
    }
    private func read<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, element: UInt32 = 0, initial: T) -> T? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        var value = initial; var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
    private func write<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, element: UInt32 = 0, value: T) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        var writable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &writable) == noErr, writable.boolValue else { return false }
        var value = value
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value) == noErr
    }
    var volume: Double? {
        if let value: Float32 = read(kAudioDevicePropertyVolumeScalar, initial: Float32(0)) { return Double(value) }
        let channels: [Float32] = [1, 2].compactMap { read(kAudioDevicePropertyVolumeScalar, element: $0, initial: Float32(0)) }
        return channels.isEmpty ? nil : Double(channels.reduce(0, +) / Float(channels.count))
    }
    var muted: Bool { (read(kAudioDevicePropertyMute, initial: UInt32(0)) ?? 0) != 0 }
    func setVolume(_ level: Double) -> Bool {
        let value = Float32(min(1, max(0, level)))
        if write(kAudioDevicePropertyVolumeScalar, value: value) { return true }
        let left = write(kAudioDevicePropertyVolumeScalar, element: 1, value: value)
        let right = write(kAudioDevicePropertyVolumeScalar, element: 2, value: value)
        return left || right
    }
    func setMuted(_ muted: Bool) -> Bool { write(kAudioDevicePropertyMute, value: UInt32(muted ? 1 : 0)) }
    deinit {
        for (id, var address, block) in observers { AudioObjectRemovePropertyListenerBlock(id, &address, .main, block) }
    }
}

// macOS has no public built-in display brightness API. Resolve this optional
// framework dynamically and leave normal keyboard behavior intact if unavailable.
final class BrightnessControl {
    typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private let handle: UnsafeMutableRawPointer?
    private let getter: GetBrightness?
    private let setter: SetBrightness?
    init() {
        let library = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        handle = library
        getter = library.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetBrightness.self) }
        setter = library.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetBrightness.self) }
    }
    private var display: CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16); var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
    var level: Double? {
        guard let display, let getter else { return nil }
        var value: Float = 0
        guard getter(display, &value) == 0, value.isFinite else { return nil }
        return Double(value)
    }
    func set(_ level: Double) -> Bool {
        guard let display, let setter else { return false }
        return setter(display, Float(min(1, max(0, level)))) == 0
    }
    deinit { if let handle { dlclose(handle) } }
}

final class SystemMonitor: ObservableObject {
    let audio = AudioControl()
    let display = BrightnessControl()
    @Published var volume: Double?
    @Published var muted = false
    @Published var brightness: Double?
    @Published var power: PowerSnapshot?
    var event: ((CueKind, Double, String, Bool) -> Void)?
    private var volumeTracker = LevelTracker()
    private var lastDevice: AudioDeviceID = 0
    private var lastMute: Bool?
    private var timer: Timer?
    private var powerSource: CFRunLoopSource?
    private var wakeObserver: NSObjectProtocol?
    init() {
        sampleAudio(); sampleBrightness(); samplePower()
        audio.changed = { [weak self] in self?.sampleAudio() }
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<SystemMonitor>.fromOpaque(context).takeUnretainedValue().samplePower()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.volumeTracker.reset()
            self?.audio.reconnect(); self?.sampleAudio(); self?.sampleBrightness(); self?.samplePower()
        }
    }
    var readoutTimerActive: Bool { timer != nil }
    func setReadoutActive(_ enabled: Bool) {
        guard enabled != (timer != nil) else { return }
        timer?.invalidate(); timer = nil
        guard enabled else { return }
        sampleBrightness()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sampleBrightness() }
        timer?.tolerance = 0.8
    }
    func sampleAudio() {
        if lastDevice != audio.device { volumeTracker.reset(); lastMute = nil; lastDevice = audio.device }
        let level = audio.volume; let mute = audio.muted
        let changed = volumeTracker.update(level)
        let muteChanged = lastMute.map { $0 != mute } ?? false
        if volume != level { volume = level }; if muted != mute { muted = mute }; lastMute = mute
        if changed || muteChanged, let level { event?(.volume, mute ? 0 : level, mute ? "Muted" : "Volume", mute) }
    }
    func sampleBrightness(origin: BrightnessOrigin = .system) {
        let level = display.level
        if brightness != level { brightness = level }
        if shouldShowBrightness(origin: origin), let level { event?(.brightness, level, "Brightness", false) }
    }
    func samplePower() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { power = nil; return }
        for source in sources {
            guard let raw = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  raw[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let capacity = raw[kIOPSCurrentCapacityKey] as? Double,
                  let maximum = raw[kIOPSMaxCapacityKey] as? Double, maximum > 0 else { continue }
            let next = PowerSnapshot(percent: capacity / maximum,
                connected: raw[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                charging: raw[kIOPSIsChargingKey] as? Bool ?? false)
            let announce = next.shouldAnnounce(after: power)
            if power != next { power = next }
            if announce { event?(.charging, next.percent, next.label, next.connected) }
            return
        }
        power = nil
    }
    deinit {
        timer?.invalidate()
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
}

final class MediaKeyController: ObservableObject {
    @Published var active = false
    @Published var trusted = AXIsProcessTrusted()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var consumed = Set<Int>()
    private var heldKey: Int?
    private var heldSince = 0.0
    var handle: ((MediaKey, Bool, Double) -> Bool)?
    func start() {
        trusted = AXIsProcessTrusted()
        guard trusted, tap == nil else { return }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14), callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<MediaKeyController>.fromOpaque(context).takeUnretainedValue().receive(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { active = false; return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true); active = true
    }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil; active = false; consumed.removeAll(); heldKey = nil
    }
    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            consumed.removeAll(); heldKey = nil
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined, ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
        let code = (ns.data1 & 0xFFFF0000) >> 16
        guard let key = MediaKey(rawValue: code) else { return Unmanaged.passUnretained(event) }
        let down = ((ns.data1 & 0xFF00) >> 8) == 0xA
        if down {
            if key == .mute && consumed.contains(code) { return nil }
            // Option-only normally opens System Settings. Preserve that shortcut.
            if ns.modifierFlags.contains(.option) && !ns.modifierFlags.contains(.shift) { return Unmanaged.passUnretained(event) }
            let now = ProcessInfo.processInfo.systemUptime
            let repeated = (ns.data1 & 1) != 0
            if heldKey != code || !repeated { heldKey = code; heldSince = now }
            if handle?(key, ns.modifierFlags.contains([.option, .shift]), now - heldSince) == true { consumed.insert(code); return nil }
        } else {
            heldKey = nil
            if consumed.remove(code) != nil { return nil }
        }
        return Unmanaged.passUnretained(event)
    }
    deinit { stop() }
}
