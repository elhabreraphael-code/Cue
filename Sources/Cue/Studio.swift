import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CueCore

// Look files contain appearance only: never permissions, keyboard behavior,
// login settings, or app exclusions. A strict envelope rejects unrelated JSON.
struct LookDocument: Codable {
    let format: String
    let version: Int
    var name: String
    var configuration: HUDConfiguration
    init(name: String, configuration: HUDConfiguration) {
        format = "com.softlymac.cue.look"; version = 1
        self.name = name; self.configuration = configuration.sanitized()
    }
    static func decode(_ data: Data) throws -> LookDocument {
        guard data.count <= 256_000 else { throw LookError.tooLarge }
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let config = object?["configuration"] as? [String: Any], !config.isEmpty else { throw LookError.invalid }
        let look = try JSONDecoder().decode(Self.self, from: data)
        guard look.format == "com.softlymac.cue.look", look.version == 1,
              !look.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LookError.invalid }
        return LookDocument(name: String(look.name.prefix(60)), configuration: look.configuration)
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    enum LookError: LocalizedError {
        case tooLarge, invalid
        var errorDescription: String? { self == .tooLarge ? "This look file is too large." : "Choose a Cue look exported by a compatible version of Cue." }
    }
}

enum MotionPreset: String, CaseIterable, Identifiable {
    case silky = "Silky", responsive = "Responsive", playful = "Playful", quiet = "Quiet"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .silky: return "water.waves"; case .responsive: return "bolt"; case .playful: return "circle.dotted"; case .quiet: return "leaf" }
    }
    var detail: String {
        switch self { case .silky: return "Soft, continuous"; case .responsive: return "Quick, precise"; case .playful: return "A little spring"; case .quiet: return "A gentle fade" }
    }
    func apply(to old: HUDConfiguration) -> HUDConfiguration {
        var config = old
        switch self {
        case .silky: config.motion = .fluid; config.speed = 0.95; config.bounce = 0; config.smoothing = 0.28
        case .responsive: config.motion = .fluid; config.speed = 1.45; config.bounce = 0; config.smoothing = 0.15
        case .playful: config.motion = .spring; config.speed = 1; config.bounce = 0.35; config.smoothing = 0.24
        case .quiet: config.motion = .fade; config.speed = 0.85; config.bounce = 0; config.smoothing = 0.3
        }
        return config
    }
    func matches(_ config: HUDConfiguration) -> Bool {
        let applied = apply(to: config)
        return config.motion == applied.motion && config.speed == applied.speed && config.bounce == applied.bounce && config.smoothing == applied.smoothing
    }
}

struct StyleGallery: View {
    @Binding var configuration: HUDConfiguration
    let reduceMotion: Bool
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(CueStyle.allCases) { style in
                Button {
                    var transaction = Transaction(); transaction.disablesAnimations = true
                    withTransaction(transaction) { configuration.style = style }
                } label: {
                    VStack(spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035))
                            CueVisual(event: CueEvent(), config: miniature(style), reduceMotion: true)
                                .scaleEffect(thumbnailScale(style))
                                .frame(width: 140, height: 85)
                                .allowsHitTesting(false).accessibilityHidden(true)
                        }.frame(height: 85).clipped()
                        HStack(spacing: 4) {
                            Text(style.rawValue).font(.system(size: 11, weight: .medium))
                            if style == .slim { Text("NEW").font(.system(size: 7, weight: .bold)).foregroundStyle(.blue) }
                            Spacer(minLength: 2)
                            Image(systemName: configuration.style == style ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(configuration.style == style ? Color.accentColor : Color.secondary.opacity(0.3))
                        }.padding(.horizontal, 10).padding(.vertical, 10)
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(configuration.style == style ? Color.accentColor : Color.primary.opacity(0.07), lineWidth: configuration.style == style ? 1.5 : 1))
                    .contentShape(RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(style.rawValue) design")
                    .accessibilityAddTraits(configuration.style == style ? .isSelected : [])
                    .help(style.description)
            }
        }
    }
    private func miniature(_ style: CueStyle) -> HUDConfiguration {
        var value = HUDConfiguration(); value.style = style; value.material = .frosted
        value.theme = configuration.theme; value.accent = configuration.accent
        value.customRed = configuration.customRed; value.customGreen = configuration.customGreen; value.customBlue = configuration.customBlue
        value.shadow = 0.08; value.showLabel = style != .slim; return value
    }
    private func thumbnailScale(_ style: CueStyle) -> Double {
        let size = miniature(style).size
        return min(0.55, 126 / size.width, 65 / size.height)
    }
}

struct MotionGallery: View {
    @Binding var configuration: HUDConfiguration
    var body: some View {
        HStack(spacing: 9) {
            ForEach(MotionPreset.allCases) { preset in
                Button { configuration = preset.apply(to: configuration) } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Image(systemName: preset.symbol).font(.system(size: 17, weight: .medium))
                            Spacer(minLength: 0)
                            if preset.matches(configuration) { Image(systemName: "checkmark.circle.fill").font(.caption) }
                        }.foregroundStyle(Color.accentColor)
                        Text(preset.rawValue).font(.system(size: 12, weight: .semibold))
                        Text(preset.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(13)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(preset.matches(configuration) ? Color.accentColor : Color.primary.opacity(0.07)))
                }.buttonStyle(.plain).accessibilityLabel("\(preset.rawValue) motion")
            }
        }
    }
}
