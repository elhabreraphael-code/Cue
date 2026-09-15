import AppKit
import SwiftUI
import CueCore

// Renders only Cue-owned windows with synthetic values and isolated preferences.
// This path does not grant permissions, intercept keys, or modify hardware.
@MainActor func runVisualChecks() -> Bool {
    guard let index = CommandLine.arguments.firstIndex(of: "--check-directory"), CommandLine.arguments.count > index + 1 else { return false }
    let output = URL(fileURLWithPath: CommandLine.arguments[index + 1]).appendingPathComponent("V4 Visual Checks")
    let suite = "com.softlymac.cue.diagnostics.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    do {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let preferences = Preferences(defaults: defaults)
        let model = CueModel(preferences: preferences, diagnostics: true)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 820), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.title = "Cue Visual Check"; window.center()
        defer { window.orderOut(nil); model.overlay.closeImmediately() }
        func capture<V: View>(_ view: V, name: String, size: NSSize) throws {
            window.setContentSize(size)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(origin: .zero, size: size)
            window.contentView = hosting; window.makeKeyAndOrderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            hosting.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw CocoaError(.fileWriteUnknown) }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try png.write(to: output.appendingPathComponent(name + ".png"))
            print("RENDER: \(name)")
        }
        for theme in [CueTheme.light, .dark] {
            window.appearance = NSAppearance(named: theme == .light ? .aqua : .darkAqua)
            for page in [CuePage.overview, .appearance, .motion, .position, .volume, .general] {
                model.page = page
                try capture(CueDashboard(model: model, preferences: preferences, monitor: model.monitor, keyboard: model.keyboard), name: "\(page.rawValue)-\(theme.rawValue)", size: NSSize(width: 1060, height: 820))
            }
            try capture(HUDContactSheet(theme: theme), name: "HUDs-\(theme.rawValue)", size: NSSize(width: 1120, height: 980))
        }
        model.page = .appearance
        try capture(CueDashboard(model: model, preferences: preferences, monitor: model.monitor, keyboard: model.keyboard), name: "Appearance-Compact", size: NSSize(width: 860, height: 680))
        print("CUE_VISUAL: 15 renders saved to \(output.path)")
        return true
    } catch { print("CUE_VISUAL_FAIL: \(error)"); return false }
}

private struct HUDContactSheet: View {
    let theme: CueTheme
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Cue").font(.system(size: 32, weight: .semibold))
                Text("Nine ways to make it yours.").foregroundStyle(.secondary)
                Spacer(); Text("V4 ALPHA").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                ForEach(CueStyle.allCases) { style in
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: theme == .dark ? [.indigo.opacity(0.35), .black.opacity(0.3)] : [.blue.opacity(0.17), .purple.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            CueVisual(event: CueEvent(), config: configuration(style), reduceMotion: true)
                                .scaleEffect(min(0.9, 290 / configuration(style).size.width, 220 / configuration(style).size.height))
                        }.frame(height: 247)
                        Text(style.rawValue).font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, theme.scheme!)
    }
    private func configuration(_ style: CueStyle) -> HUDConfiguration {
        var config = HUDConfiguration(); config.style = style; config.theme = theme; return config
    }
}
