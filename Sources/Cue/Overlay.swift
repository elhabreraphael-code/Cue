import AppKit
import SwiftUI
import CueCore

struct CueEvent: Equatable {
    var kind: CueKind = .volume
    var value: Double = 0.65
    var title = "Volume"
    var flag = false
    var symbol: String {
        switch kind {
        case .volume: return flag || value == 0 ? "speaker.slash.fill" : value < 0.34 ? "speaker.wave.1.fill" : value < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness: return "sun.max.fill"
        case .charging: return flag ? "bolt.fill" : "battery.75percent"
        }
    }
    var percentage: String { "\(Int((value * 100).rounded()))%" }
}
final class OverlayState: ObservableObject {
    @Published var event = CueEvent()
    @Published var visible = false
    @Published var config = HUDConfiguration()
    @Published var effectiveScale = 1.0
}

struct HUDSurface: ViewModifier {
    let config: HUDConfiguration
    let radius: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || config.material == .solid {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.primary.opacity(0.08)))
        } else if #available(macOS 26.0, *), config.material == .liquid || config.material == .clear {
            if config.material == .clear {
                if config.tintAmount > 0 {
                    content.glassEffect(.clear.tint(config.color.opacity(config.tintAmount)), in: RoundedRectangle(cornerRadius: radius))
                } else { content.glassEffect(.clear, in: RoundedRectangle(cornerRadius: radius)) }
            } else {
                if config.tintAmount > 0 {
                    content.glassEffect(.regular.tint(config.color.opacity(config.tintAmount)), in: RoundedRectangle(cornerRadius: radius))
                } else { content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius)) }
            }
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .background(config.color.opacity(config.tintAmount), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.22), lineWidth: 0.75))
        }
    }
}

struct CueVisual: View {
    let event: CueEvent
    let config: HUDConfiguration
    var reduceMotion = false
    @Environment(\.colorScheme) private var systemScheme
    private var ink: Color { config.color }
    private var radius: Double {
        switch config.style {
        case .compact, .island: return min(config.size.height / 2, config.cornerRadius + 12)
        case .iphone: return min(config.size.width / 2, config.cornerRadius)
        default: return config.cornerRadius
        }
    }
    var body: some View {
        content
            .frame(width: config.size.width, height: config.size.height)
            .modifier(HUDSurface(config: config, radius: radius))
            .shadow(color: .black.opacity(config.shadow), radius: 14, y: 5)
            .opacity(config.opacity)
            .animation(reduceMotion ? nil : .smooth(duration: config.smoothing), value: event.value)
            .environment(\.colorScheme, config.theme.scheme ?? systemScheme)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(event.title), \(event.percentage)")
    }
    @ViewBuilder private var content: some View {
        switch config.style {
        case .glass: glass
        case .compact: compact
        case .iphone: iphone
        case .island: island
        case .orbit: orbit
        case .classic: classic
        case .wave: wave
        case .tile: tile
        }
    }
    @ViewBuilder private var icon: some View {
        if reduceMotion { Image(systemName: event.symbol).foregroundStyle(ink) }
        else { Image(systemName: event.symbol).foregroundStyle(ink).contentTransition(.symbolEffect(.replace)) }
    }
    private var percentage: some View {
        Text(event.percentage).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
            .contentTransition(.numericText(value: event.value * 100))
    }
    private var title: some View { Text(event.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8) }
    private var glass: some View {
        HStack(spacing: 15) {
            if config.showIcon {
                icon.font(.system(size: 23, weight: .medium)).frame(width: 35, height: 42)
            }
            VStack(spacing: 12) {
                if config.showLabel || config.showPercentage {
                    HStack { if config.showLabel { title }; Spacer(minLength: 4); if config.showPercentage { percentage.foregroundStyle(.secondary) } }
                }
                levelBar(height: 5)
            }
        }.padding(20)
    }
    private var compact: some View {
        HStack(spacing: 13) {
            if config.showIcon { icon.font(.system(size: 17, weight: .medium)).frame(width: 23) }
            levelBar(height: 5)
            if config.showPercentage { percentage.frame(width: 36, alignment: .trailing) }
        }.padding(.horizontal, 20)
    }
    private var iphone: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: radius).fill(.primary.opacity(0.05))
                Rectangle().fill(config.accent == .monochrome ? Color.white : ink)
                    .frame(height: geometry.size.height * max(0, min(1, event.value)))
                VStack {
                    if config.showPercentage {
                        percentage.font(.caption2).foregroundStyle(event.value > 0.84 ? Color.black.opacity(0.65) : Color.primary.opacity(0.7)).padding(.top, 20)
                    }
                    Spacer()
                    if config.showIcon {
                        Image(systemName: event.symbol).font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(event.value > 0.18 ? Color.black.opacity(0.65) : Color.primary.opacity(0.7)).padding(.bottom, 22)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }
    private var island: some View {
        HStack(spacing: 14) {
            if config.showIcon { icon.font(.system(size: 21, weight: .medium)) }
            VStack(alignment: .leading, spacing: 9) {
                if config.showLabel { title }
                levelBar(height: 4)
            }
            if config.showPercentage { percentage.foregroundStyle(.secondary) }
        }.padding(.horizontal, 23)
    }
    private var orbit: some View {
        VStack(spacing: 11) {
            ZStack {
                Circle().stroke(.primary.opacity(0.09), lineWidth: 5)
                Circle().trim(from: 0, to: max(0.001, event.value)).stroke(ink.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                if config.showIcon { icon.font(.system(size: 28, weight: .medium)) }
            }.frame(width: min(config.size.width - 50, config.size.height - 88), height: min(config.size.width - 50, config.size.height - 88))
            if config.showLabel { title.foregroundStyle(.secondary) }
            if config.showPercentage { percentage }
        }.padding(18)
    }
    private var classic: some View {
        VStack(spacing: 16) {
            if config.showIcon { icon.font(.system(size: min(54, config.size.height * 0.27), weight: .regular)) }
            if config.showLabel || config.showPercentage {
                HStack(spacing: 7) { if config.showLabel { title }; if config.showPercentage { percentage.foregroundStyle(.secondary) } }
            }
            HStack(spacing: 3) {
                ForEach(0..<16) { index in
                    RoundedRectangle(cornerRadius: 1.5).fill(Double(index) / 16 < event.value ? ink : ink.opacity(0.13))
                }
            }.frame(height: 7)
        }.padding(22)
    }
    private var wave: some View {
        HStack(spacing: 14) {
            if config.showIcon { icon.font(.system(size: 23)) }
            VStack(alignment: .leading, spacing: 10) {
                if config.showLabel || config.showPercentage {
                    HStack { if config.showLabel { title }; Spacer(); if config.showPercentage { percentage.foregroundStyle(.secondary) } }
                }
                HStack(alignment: .center, spacing: 3) {
                    ForEach(0..<24) { index in
                        Capsule().fill(Double(index) / 24 < event.value ? ink : ink.opacity(0.14))
                            .frame(height: 6 + 18 * abs(sin(Double(index) * 0.61)))
                    }
                }.frame(height: 25)
            }
        }.padding(20)
    }
    private var tile: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle().fill(ink.opacity(0.13)).frame(height: geometry.size.height * event.value)
                VStack(alignment: .leading, spacing: 8) {
                    if config.showIcon { icon.font(.system(size: 28, weight: .medium)) }
                    Spacer(minLength: 6)
                    if config.showPercentage { Text(event.percentage).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit().contentTransition(.numericText(value: event.value * 100)) }
                    if config.showLabel { title.foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(21)
            }.clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }
    private func levelBar(height: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.10))
                Capsule().fill(ink.gradient).frame(width: max(0, geometry.size.width * min(1, max(0, event.value))))
            }
        }.frame(height: height)
    }
}

struct OverlayRoot: View {
    @ObservedObject var state: OverlayState
    @ObservedObject var preferences: Preferences
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { preferences.settings.reduceMotion || systemReduceMotion }
    private var travel: CGSize {
        guard !reduceMotion, state.config.motion != .fade else { return .zero }
        let anchor = state.config.position.anchor
        return CGSize(width: (anchor.x - 0.5) * 30, height: (0.5 - anchor.y) * 24)
    }
    var body: some View {
        CueVisual(event: state.event, config: state.config, reduceMotion: reduceMotion)
            .scaleEffect(state.effectiveScale * (state.visible || reduceMotion || state.config.motion == .fade ? 1 : 0.94))
            .opacity(state.visible ? 1 : 0)
            .offset(x: state.visible ? 0 : travel.width, y: state.visible ? 0 : travel.height)
            .animation(state.config.animation(reduceMotion: reduceMotion), value: state.visible)
            .frame(width: state.config.size.width * state.effectiveScale + 100, height: state.config.size.height * state.effectiveScale + 100)
    }
}
final class CuePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class OverlayController {
    private let state = OverlayState()
    private let preferences: Preferences
    private let panel: CuePanel
    private var dismiss: DispatchWorkItem?
    private var hide: DispatchWorkItem?
    private var entrance: DispatchWorkItem?
    private var targetScreen: NSScreen?
    private var previewShared = false
    init(preferences: Preferences) {
        self.preferences = preferences
        panel = CuePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .statusBar; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: OverlayRoot(state: state, preferences: preferences))
    }
    func show(_ event: CueEvent, shared: Bool = false) {
        dismiss?.cancel(); hide?.cancel(); entrance?.cancel()
        let wasVisible = state.visible
        if state.event != event { state.event = event }
        previewShared = shared
        let configuration = shared ? preferences.settings.appearance : preferences.configuration(for: event.kind)
        if state.config != configuration { state.config = configuration }
        if !wasVisible { targetScreen = selectScreen(state.config.screen) }
        layout()
        panel.orderFrontRegardless()
        if !wasVisible {
            panel.displayIfNeeded()
            let work = DispatchWorkItem { [weak self] in self?.state.visible = true }
            entrance = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
        }
        scheduleDismiss()
    }
    func refreshAppearance() {
        guard panel.isVisible else { return }
        let config = previewShared ? preferences.settings.appearance : preferences.configuration(for: state.event.kind)
        guard config != state.config else { return }
        if config.screen != state.config.screen { targetScreen = selectScreen(config.screen) }
        state.config = config; layout(); scheduleDismiss()
    }
    private func selectScreen(_ choice: CueScreen) -> NSScreen? {
        switch choice {
        case .pointer: return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        case .main: return NSScreen.screens.first ?? NSScreen.main
        case .builtIn: return NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        } ?? NSScreen.main
        }
    }
    private func layout() {
        guard let screen = targetScreen ?? NSScreen.main else { return }
        let config = state.config
        let fit = min(config.scale, (screen.visibleFrame.width - 20) / config.size.width, (screen.visibleFrame.height - 20) / config.size.height)
        if state.effectiveScale != max(0.1, fit) { state.effectiveScale = max(0.1, fit) }
        let size = CGSize(width: config.size.width * state.effectiveScale, height: config.size.height * state.effectiveScale)
        let rect = hudFrame(in: screen.visibleFrame, size: size, anchor: config.position.anchor, margin: config.edgeMargin, offsetX: config.offsetX, offsetY: config.offsetY)
        let frame = rect.insetBy(dx: -50, dy: -50)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }
    private func scheduleDismiss() {
        dismiss?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        dismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + state.config.duration, execute: work)
    }
    func close() {
        dismiss?.cancel(); hide?.cancel(); entrance?.cancel(); state.visible = false
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65 / state.config.speed, execute: work)
    }
    func closeImmediately() {
        dismiss?.cancel(); hide?.cancel(); entrance?.cancel()
        state.visible = false; panel.orderOut(nil)
    }
}
