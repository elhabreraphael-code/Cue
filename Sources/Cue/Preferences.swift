import SwiftUI
import CueCore

enum CueStyle: String, CaseIterable, Identifiable, Codable {
    case glass = "Glass", compact = "Compact", iphone = "iPhone", island = "Island"
    case slim = "Slim"
    case orbit = "Orbit", classic = "Classic", wave = "Wave", tile = "Tile"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .slim: return "slider.horizontal.3"
        case .glass: return "rectangle.roundedtop"
        case .compact: return "capsule"
        case .iphone: return "iphone"
        case .island: return "capsule.inset.filled"
        case .orbit: return "circle.dotted"
        case .classic: return "square.grid.3x3.fill"
        case .wave: return "waveform"
        case .tile: return "square.fill"
        }
    }
    var description: String {
        switch self {
        case .slim: return "A slimmer kind of familiar."
        case .glass: return "Light, layered, familiar."
        case .compact: return "Just the essentials."
        case .iphone: return "A touch of iPhone."
        case .island: return "A quiet floating capsule."
        case .orbit: return "A circle of feedback."
        case .classic: return "A nod to the original."
        case .wave: return "A softer rhythm."
        case .tile: return "Inspired by Control Center."
        }
    }
}
enum CuePosition: String, CaseIterable, Identifiable, Codable {
    case topLeft = "Top left", top = "Top", topRight = "Top right"
    case left = "Left", center = "Center", right = "Right"
    case bottomLeft = "Bottom left", bottom = "Bottom", bottomRight = "Bottom right"
    var id: String { rawValue }
    var anchor: HUDAnchor { HUDAnchor(rawValue: Self.allCases.firstIndex(of: self)!)! }
}
enum CueMaterial: String, CaseIterable, Identifiable, Codable {
    case liquid = "Liquid Glass", clear = "Clear Glass", frosted = "Frosted", solid = "Solid"
    var id: String { rawValue }
}
enum CueTheme: String, CaseIterable, Identifiable, Codable {
    case system = "Automatic", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var scheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
}
enum CueMotion: String, CaseIterable, Identifiable, Codable {
    case fluid = "Fluid", spring = "Spring", glide = "Glide", fade = "Fade"
    var id: String { rawValue }
}
enum CueScreen: String, CaseIterable, Identifiable, Codable {
    case pointer = "Pointer display", main = "Main display", builtIn = "Built-in display"
    var id: String { rawValue }
}
enum CueAccent: String, CaseIterable, Identifiable, Codable {
    case monochrome = "Monochrome", blue = "Blue", purple = "Violet", mint = "Mint", orange = "Amber"
    case pink = "Pink", red = "Red", coral = "Coral", yellow = "Yellow", green = "Green", cyan = "Cyan", indigo = "Indigo", custom = "Custom"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .monochrome: return .primary
        case .blue: return Color(red: 0.22, green: 0.52, blue: 1)
        case .purple: return Color(red: 0.65, green: 0.42, blue: 1)
        case .mint: return .mint
        case .orange: return .orange
        case .pink: return .pink
        case .red: return .red
        case .coral: return Color(red: 1, green: 0.43, blue: 0.38)
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .indigo: return .indigo
        case .custom: return .accentColor
        }
    }
}
struct HUDConfiguration: Codable, Equatable {
    var style: CueStyle = .glass
    var material: CueMaterial = .liquid
    var theme: CueTheme = .system
    var accent: CueAccent = .monochrome
    var customRed = 0.3, customGreen = 0.6, customBlue = 1.0
    var position: CuePosition = .bottom
    var screen: CueScreen = .pointer
    var scale = 1.0, width = 1.0, height = 1.0
    var edgeMargin = 32.0, offsetX = 0.0, offsetY = 0.0
    var duration = 1.6, speed = 1.0, bounce = 0.08, smoothing = 0.24
    var cornerRadius = 28.0, tintAmount = 0.0, opacity = 1.0, shadow = 0.22
    var showLabel = true, showPercentage = true, showIcon = true
    var motion: CueMotion = .fluid

    init() {}
    private enum CodingKeys: String, CodingKey { case style, material, theme, accent, customRed, customGreen, customBlue, position, screen, scale, width, height, edgeMargin, offsetX, offsetY, duration, speed, bounce, smoothing, cornerRadius, tintAmount, opacity, shadow, showLabel, showPercentage, showIcon, motion }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        style = values.value(for: .style, default: style)
        material = values.value(for: .material, default: material)
        theme = values.value(for: .theme, default: theme)
        accent = values.value(for: .accent, default: accent)
        customRed = values.value(for: .customRed, default: customRed)
        customGreen = values.value(for: .customGreen, default: customGreen)
        customBlue = values.value(for: .customBlue, default: customBlue)
        position = values.value(for: .position, default: position)
        screen = values.value(for: .screen, default: screen)
        scale = values.value(for: .scale, default: scale)
        width = values.value(for: .width, default: width)
        height = values.value(for: .height, default: height)
        edgeMargin = values.value(for: .edgeMargin, default: edgeMargin)
        offsetX = values.value(for: .offsetX, default: offsetX)
        offsetY = values.value(for: .offsetY, default: offsetY)
        duration = values.value(for: .duration, default: duration)
        speed = values.value(for: .speed, default: speed)
        bounce = values.value(for: .bounce, default: bounce)
        smoothing = values.value(for: .smoothing, default: smoothing)
        cornerRadius = values.value(for: .cornerRadius, default: cornerRadius)
        tintAmount = values.value(for: .tintAmount, default: tintAmount)
        opacity = values.value(for: .opacity, default: opacity)
        shadow = values.value(for: .shadow, default: shadow)
        showLabel = values.value(for: .showLabel, default: showLabel)
        showPercentage = values.value(for: .showPercentage, default: showPercentage)
        showIcon = values.value(for: .showIcon, default: showIcon)
        motion = values.value(for: .motion, default: motion)
    }
    var color: Color { accent == .custom ? Color(red: customRed, green: customGreen, blue: customBlue) : accent.color }
    var size: CGSize {
        let base: CGSize
        switch style {
        case .slim: base = CGSize(width: max(230, 300 * width), height: max(42, 48 * height))
        case .glass: base = CGSize(width: max(256, 316 * width), height: max(84, 98 * height))
        case .compact: base = CGSize(width: max(195, 265 * width), height: max(48, 56 * height))
        case .iphone: base = CGSize(width: max(52, 66 * width), height: max(144, 218 * height))
        case .island: base = CGSize(width: max(218, 292 * width), height: max(58, 76 * height))
        case .orbit: base = CGSize(width: max(136, 166 * width), height: max(158, 198 * height))
        case .classic: base = CGSize(width: max(158, 194 * width), height: max(150, 190 * height))
        case .wave: base = CGSize(width: max(200, 284 * width), height: max(80, 108 * height))
        case .tile: base = CGSize(width: max(112, 138 * width), height: max(130, 172 * height))
        }
        return base
    }
    func animation(reduceMotion: Bool) -> Animation {
        if reduceMotion || motion == .fade { return .easeOut(duration: 0.18 / speed) }
        switch motion {
        case .fluid: return .interpolatingSpring(duration: 0.42 / speed, bounce: bounce * 0.15)
        case .spring: return .spring(response: 0.4 / speed, dampingFraction: 1 - bounce * 0.45)
        case .glide: return .easeInOut(duration: 0.36 / speed)
        case .fade: return .easeOut(duration: 0.18 / speed)
        }
    }
    func sanitized() -> Self {
        var copy = self
        copy.scale = clamp(scale, 0.5...2); copy.width = clamp(width, 0.75...1.5); copy.height = clamp(height, 0.75...1.5)
        copy.duration = clamp(duration, 0.5...8); copy.speed = clamp(speed, 0.5...2); copy.bounce = clamp(bounce, 0...0.8)
        copy.smoothing = clamp(smoothing, 0.05...0.6); copy.edgeMargin = clamp(edgeMargin, 8...180)
        copy.offsetX = clamp(offsetX, -500...500); copy.offsetY = clamp(offsetY, -350...350)
        copy.cornerRadius = clamp(cornerRadius, 8...48); copy.tintAmount = clamp(tintAmount, 0...0.5)
        copy.opacity = clamp(opacity, 0.4...1); copy.shadow = clamp(shadow, 0...0.5)
        copy.customRed = clamp(customRed, 0...1); copy.customGreen = clamp(customGreen, 0...1); copy.customBlue = clamp(customBlue, 0...1)
        return copy
    }
    private func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double { value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound }
}
struct CueSettings: Codable, Equatable {
    var enabled = true, volume = true, brightness = true, charging = true
    var replaceHUD = false, chargingSound = false, reduceMotion = false
    var appearance = HUDConfiguration()
    var overrides: [String: HUDConfiguration] = [:]
    var volumeStep = 6.25, brightnessStep = 6.25
    var acceleration = 0.0, accelerationDelay = 0.35, accelerationRamp = 1.4
    var maximumVolume = 100.0
    var showDisconnect = true
    var savedLooks: [SavedLook] = []
    var pauseUntil: Date? = nil
    var quietApps: [QuietApp] = []
    var showOutputChanges = false
    var showOutputName = false

    init() {}
    private enum CodingKeys: String, CodingKey { case enabled, volume, brightness, charging, replaceHUD, chargingSound, reduceMotion, appearance, overrides, volumeStep, brightnessStep, acceleration, accelerationDelay, accelerationRamp, maximumVolume, showDisconnect, savedLooks, pauseUntil, quietApps, showOutputChanges, showOutputName }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = values.value(for: .enabled, default: enabled)
        volume = values.value(for: .volume, default: volume)
        brightness = values.value(for: .brightness, default: brightness)
        charging = values.value(for: .charging, default: charging)
        replaceHUD = values.value(for: .replaceHUD, default: replaceHUD)
        chargingSound = values.value(for: .chargingSound, default: chargingSound)
        reduceMotion = values.value(for: .reduceMotion, default: reduceMotion)
        appearance = values.value(for: .appearance, default: appearance)
        overrides = values.value(for: .overrides, default: overrides)
        volumeStep = values.value(for: .volumeStep, default: volumeStep)
        brightnessStep = values.value(for: .brightnessStep, default: brightnessStep)
        acceleration = values.value(for: .acceleration, default: acceleration)
        accelerationDelay = values.value(for: .accelerationDelay, default: accelerationDelay)
        accelerationRamp = values.value(for: .accelerationRamp, default: accelerationRamp)
        maximumVolume = values.value(for: .maximumVolume, default: maximumVolume)
        showDisconnect = values.value(for: .showDisconnect, default: showDisconnect)
        savedLooks = values.value(for: .savedLooks, default: savedLooks)
        pauseUntil = values.value(for: .pauseUntil, default: pauseUntil)
        quietApps = values.value(for: .quietApps, default: quietApps)
        showOutputChanges = values.value(for: .showOutputChanges, default: showOutputChanges)
        showOutputName = values.value(for: .showOutputName, default: showOutputName)
    }
}
struct QuietApp: Codable, Equatable, Identifiable {
    var id: String
    var name: String
}

struct SavedLook: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var configuration: HUDConfiguration
}
private extension KeyedDecodingContainer {
    func value<T: Decodable>(for key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    static let domain = "com.softlymac.cue"
    @Published var settings: CueSettings { didSet { if settings != oldValue { save(previous: oldValue) } } }
    var changed: (() -> Void)?
    static var appDefaults: UserDefaults {
        // The app's own bundle domain belongs to .standard. Some macOS
        // versions reject opening it as an additional named suite.
        if Bundle.main.bundleIdentifier == domain { return .standard }
        return UserDefaults(suiteName: domain) ?? .standard
    }
    init(defaults: UserDefaults = Preferences.appDefaults) {
        self.defaults = defaults
        let data = defaults.data(forKey: "cueSettingsV2")
        let backup = defaults.data(forKey: "cueSettingsBackup")
        if var saved = [data, backup].compactMap({ $0 }).compactMap({ try? JSONDecoder().decode(CueSettings.self, from: $0) }).first {
            saved.appearance = saved.appearance.sanitized()
            saved.overrides = saved.overrides.mapValues { $0.sanitized() }
            saved.savedLooks = saved.savedLooks.map { var look = $0; look.configuration = look.configuration.sanitized(); return look }
            saved.volumeStep = min(25, max(0.5, saved.volumeStep)); saved.brightnessStep = min(25, max(0.5, saved.brightnessStep))
            saved.maximumVolume = min(100, max(10, saved.maximumVolume))
            saved.acceleration = min(5, max(0, saved.acceleration))
            saved.accelerationDelay = min(1.5, max(0.1, saved.accelerationDelay)); saved.accelerationRamp = min(3, max(0.3, saved.accelerationRamp))
            if let until = saved.pauseUntil, until <= Date() { saved.pauseUntil = nil }
            settings = saved
        } else {
            var migrated = CueSettings()
            if defaults.object(forKey: "enabled") != nil {
                migrated.enabled = defaults.bool(forKey: "enabled")
                migrated.volume = defaults.object(forKey: "volume") as? Bool ?? true
                migrated.brightness = defaults.object(forKey: "brightness") as? Bool ?? true
                migrated.charging = defaults.object(forKey: "charging") as? Bool ?? true
                migrated.replaceHUD = defaults.bool(forKey: "replaceHUD")
                migrated.chargingSound = defaults.bool(forKey: "chargingSound"); migrated.reduceMotion = defaults.bool(forKey: "reduceMotion")
                migrated.appearance.style = CueStyle(rawValue: defaults.string(forKey: "style") ?? "") ?? .glass
                migrated.appearance.position = CuePosition(rawValue: defaults.string(forKey: "position") ?? "") ?? .bottom
                migrated.appearance.accent = CueAccent(rawValue: defaults.string(forKey: "accent") ?? "") ?? .monochrome
                migrated.appearance.duration = defaults.object(forKey: "duration") as? Double ?? 1.8
                migrated.appearance.scale = defaults.object(forKey: "scale") as? Double ?? 1
                migrated.appearance = migrated.appearance.sanitized()
            }
            settings = migrated
        }
        // Materialize migration immediately, before the first user interaction.
        persist()
    }
    var enabled: Bool { get { settings.enabled } set { settings.enabled = newValue } }
    var temporarilyPaused: Bool { settings.pauseUntil.map { $0 > Date() } ?? false }
    var active: Bool { enabled && !temporarilyPaused }
    func isQuiet(in bundleID: String?) -> Bool {
        guard let bundleID else { return false }; return settings.quietApps.contains { $0.id == bundleID }
    }
    func accepts(_ kind: CueKind) -> Bool { active && (kind == .volume ? settings.volume : kind == .brightness ? settings.brightness : settings.charging) }
    func configuration(for kind: CueKind) -> HUDConfiguration { settings.overrides[kind.rawValue] ?? settings.appearance }
    func resetAppearance() { settings.appearance = HUDConfiguration(); settings.overrides = [:] }
    func saveLook(name: String, configuration: HUDConfiguration) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !trimmed.isEmpty else { return }
        settings.savedLooks.append(SavedLook(name: trimmed, configuration: configuration))
    }
    func flush() { defaults.synchronize() }
    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: "cueSettingsV2")
            defaults.set(data, forKey: "cueSettingsBackup")
        }
    }
    private func save(previous: CueSettings) {
        persist()
        // Flush switches immediately; dragging an appearance slider avoids a
        // disk synchronization for each frame. Ordinary quit also flushes.
        if settings.replaceHUD != previous.replaceHUD || settings.enabled != previous.enabled ||
            settings.volume != previous.volume || settings.brightness != previous.brightness || settings.charging != previous.charging {
            flush()
        }
        changed?()
    }
}
