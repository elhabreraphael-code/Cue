import Foundation
import CoreGraphics

public enum CueKind: String, CaseIterable, Identifiable, Codable {
    case volume, brightness, charging
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct PowerSnapshot: Equatable {
    public let percent: Double
    public let connected: Bool
    public let charging: Bool
    public init(percent: Double, connected: Bool, charging: Bool) {
        self.percent = min(1, max(0, percent))
        self.connected = connected
        self.charging = charging
    }
    public var label: String {
        if !connected { return "On battery" }
        if percent >= 0.995 { return "Fully charged" }
        return charging ? "Charging" : "Power connected"
    }
    public func shouldAnnounce(after previous: PowerSnapshot?) -> Bool {
        guard let previous else { return false }
        return connected != previous.connected
    }
}

public struct LevelTracker {
    private var previous: Double?
    public init() {}
    public mutating func reset() { previous = nil }
    public mutating func update(_ value: Double?) -> Bool {
        guard let value, value.isFinite else { previous = nil; return false }
        let old = previous
        previous = value
        guard let old else { return false }
        return abs(value - old) > 0.004
    }
}

public enum MediaKey: Int {
    case volumeUp = 0, volumeDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    public var kind: CueKind {
        self == .brightnessUp || self == .brightnessDown ? .brightness : .volume
    }
    public func adjusted(_ value: Double, fine: Bool = false) -> Double {
        let step = fine ? 1.0 / 64 : 1.0 / 16
        switch self {
        case .volumeUp, .brightnessUp: return min(1, value + step)
        case .volumeDown, .brightnessDown: return max(0, value - step)
        case .mute: return value
        }
    }
}

// Brightness telemetry never implies user intent. Only a key or our own control
// may request a cue; ambient-light changes remain silent, regardless of size.
public enum BrightnessOrigin { case system, keyboard, cueControl }
public func shouldShowBrightness(origin: BrightnessOrigin) -> Bool { origin != .system }

public struct KeyResponse {
    public var step: Double
    public var acceleration: Double
    public var delay: Double
    public var ramp: Double
    public var ceiling: Double
    public init(step: Double = 0.0625, acceleration: Double = 0, delay: Double = 0.35, ramp: Double = 1.4, ceiling: Double = 1) {
        self.step = step; self.acceleration = acceleration; self.delay = delay; self.ramp = ramp; self.ceiling = ceiling
    }
    public func increment(held: Double, fine: Bool) -> Double {
        let base = min(0.25, max(0.005, step))
        if fine { return base / 4 }
        let progress = min(1, max(0, (held - delay) / max(0.1, ramp)))
        let ease = progress * progress * (3 - 2 * progress)
        return base * (1 + max(0, acceleration) * ease)
    }
    public func adjusted(_ level: Double, key: MediaKey, held: Double, fine: Bool) -> Double {
        let amount = increment(held: held, fine: fine)
        switch key {
        case .volumeUp, .brightnessUp:
            // If output is already above the user's ceiling, an Up press must
            // never turn it down. The ceiling governs only increases from below.
            return level >= ceiling ? min(1, level) : min(ceiling, level + amount)
        case .volumeDown, .brightnessDown: return max(0, level - amount)
        case .mute: return level
        }
    }
}
public enum HUDAnchor: Int, CaseIterable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
    public var x: Double { Double(rawValue % 3) / 2 }
    public var y: Double { 1 - Double(rawValue / 3) / 2 }
}
public func hudFrame(in screen: CGRect, size: CGSize, anchor: HUDAnchor, margin: Double, offsetX: Double, offsetY: Double) -> CGRect {
    let insetX = min(margin, max(0, (screen.width - size.width) / 2))
    let insetY = min(margin, max(0, (screen.height - size.height) / 2))
    let minX = screen.minX + insetX, maxX = max(minX, screen.maxX - insetX - size.width)
    let minY = screen.minY + insetY, maxY = max(minY, screen.maxY - insetY - size.height)
    let x = min(maxX, max(minX, minX + (maxX - minX) * anchor.x + offsetX))
    let y = min(maxY, max(minY, minY + (maxY - minY) * anchor.y + offsetY))
    return CGRect(origin: CGPoint(x: x, y: y), size: size)
}
