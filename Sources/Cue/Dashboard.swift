import SwiftUI
import AppKit
import CueCore
import UniformTypeIdentifiers

enum CuePage: String, CaseIterable, Identifiable {
    case overview = "Overview", volume = "Volume", brightness = "Brightness", charging = "Charging"
    case appearance = "Appearance", position = "Position", motion = "Motion", keyboard = "Keyboard", general = "General"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .volume: return "speaker.wave.2"
        case .brightness: return "sun.max"
        case .charging: return "bolt"
        case .appearance: return "paintpalette"
        case .position: return "viewfinder"
        case .motion: return "water.waves"
        case .keyboard: return "keyboard"
        case .general: return "gearshape"
        }
    }
    var kind: CueKind? { CueKind(rawValue: rawValue.lowercased()) }
    var subtitle: String {
        switch self {
        case .overview: return "The little things, just how you like them."
        case .volume: return "Every adjustment, in your own rhythm."
        case .brightness: return "For the light you choose."
        case .charging: return "A little welcome when power arrives."
        case .appearance: return "Familiar shapes. Your personal touch."
        case .position: return "A place for every little moment."
        case .motion: return "Find the feel that belongs on your Mac."
        case .keyboard: return "Small steps. A smoother response."
        case .general: return "Quietly at home on your Mac."
        }
    }
}

struct CueDashboard: View {
    @ObservedObject var model: CueModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var keyboard: MediaKeyController
    @State private var previewKind: CueKind = .volume
    @State private var previewValue = 0.65
    @State private var editKind: CueKind?
    @State private var resetConfirmation = false
    @State private var savingLook = false
    @State private var lookName = ""
    @State private var alternatePreview = false
    @State private var previewBackdrop = 0
    @State private var previewVisible = true
    @State private var motionTask: Task<Void, Never>?
    @State private var previousAppearance: HUDConfiguration?
    @State private var previousScope: CueKind?
    @State private var previousHadOverride = false
    @State private var lastAppearanceEdit = Date.distantPast
    @State private var importingLook: LookDocument?
    @State private var showImport = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var isControlPage: Bool { [.volume, .brightness, .charging, .keyboard].contains(model.page) }
    private var isDesignPage: Bool { [.appearance, .position, .motion].contains(model.page) }
    private var selectedKind: CueKind { model.page.kind ?? (isDesignPage ? editKind : nil) ?? previewKind }
    private var config: HUDConfiguration { isDesignPage ? configuration.wrappedValue : preferences.configuration(for: selectedKind) }
    private var configuration: Binding<HUDConfiguration> {
        Binding(get: { editKind.map { preferences.configuration(for: $0) } ?? preferences.settings.appearance }, set: { value in
            if Date().timeIntervalSince(lastAppearanceEdit) > 0.45 || previousScope != editKind || previousAppearance == nil {
                previousAppearance = editKind.map { preferences.configuration(for: $0) } ?? preferences.settings.appearance
                previousScope = editKind
                previousHadOverride = editKind.map { preferences.settings.overrides[$0.rawValue] != nil } ?? false
            }
            lastAppearanceEdit = Date()
            if let editKind { preferences.settings.overrides[editKind.rawValue] = value }
            else { preferences.settings.appearance = value }
        })
    }
    private var event: CueEvent {
        CueEvent(kind: selectedKind, value: alternatePreview && selectedKind == .volume ? 0 : previewValue,
            title: selectedKind == .charging ? (alternatePreview ? "On battery" : "Charging") : selectedKind == .volume && alternatePreview ? "Muted" : selectedKind.title,
            flag: selectedKind == .charging ? !alternatePreview : selectedKind == .volume && alternatePreview)
    }
    private var appleHUDs: Binding<Bool> { Binding(get: { !preferences.settings.replaceHUD }, set: { preferences.settings.replaceHUD = !$0 }) }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    CueMark().frame(width: 35, height: 35)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cue").font(.system(size: 18, weight: .semibold))
                        Text("BY SOFTLY MAC").font(.system(size: 8, weight: .semibold)).tracking(1.3).foregroundStyle(.secondary)
                    }; Spacer()
                }.padding(.horizontal, 19).padding(.top, 18).padding(.bottom, 20)
                List {
                    ForEach([CuePage.overview, .appearance, .volume, .general]) { navigationRow($0) }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Label(preferences.active ? "Cue is ready" : "Cue is paused", systemImage: "circle.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(preferences.active ? .green : .secondary)
                    Text("Thoughtfully quiet.\nEntirely yours.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                Divider()
                HStack { Text("V4"); Spacer(); Text("ALPHA").font(.system(size: 9, weight: .semibold)).tracking(1) }.font(.caption).foregroundStyle(.tertiary).padding(17)
            }.navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 230)
        } detail: {
            VStack(spacing: 0) {
                if isDesignPage {
                    VStack(alignment: .leading, spacing: 12) {
                        pageHeader
                        Picker("Appearance section", selection: $model.page) {
                            Text("Design").tag(CuePage.appearance); Text("Position").tag(CuePage.position); Text("Motion").tag(CuePage.motion)
                        }.pickerStyle(.segmented).labelsHidden()
                        scopePicker
                        preview
                    }.padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 16)
                    Divider()
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !isDesignPage { pageHeader }
                        if isControlPage {
                            Picker("Control", selection: $model.page) {
                                Text("Volume").tag(CuePage.volume); Text("Brightness").tag(CuePage.brightness)
                                Text("Charging").tag(CuePage.charging); Text("Keyboard").tag(CuePage.keyboard)
                            }.pickerStyle(.segmented).labelsHidden()
                        }
                        pageContent
                        HStack(spacing: 5) {
                            Image(systemName: "lock.shield"); Text("Made for your Mac. Stays on your Mac.")
                            Spacer(); Text("Cue V4 Alpha")
                        }.font(.system(size: 10)).foregroundStyle(.tertiary)
                    }.padding(26).frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity)
                }.id(model.page)
            }.background(Color(nsColor: .windowBackgroundColor)).navigationTitle("Cue")
        }
        .frame(minWidth: 850, minHeight: 650)
        .onChange(of: model.page) { _, _ in stopMotionPreview() }
        .onDisappear { stopMotionPreview() }
        .onChange(of: editKind) { _, _ in alternatePreview = false }
        .onChange(of: previewKind) { _, _ in alternatePreview = false }
        .sheet(isPresented: $showImport) {
            if let look = importingLook {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Import \(look.name)").font(.title2.weight(.semibold))
                    CueVisual(event: CueEvent(), config: look.configuration, reduceMotion: true)
                        .scaleEffect(min(0.8, 300 / look.configuration.size.width, 190 / look.configuration.size.height))
                        .frame(width: 340, height: 200)
                    Text("Adds this look to your collection. Apply it whenever you like. Your current appearance stays in place.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack { Spacer(); Button("Cancel") { showImport = false }.keyboardShortcut(.cancelAction)
                        Button("Add to My Looks") { preferences.saveLook(name: look.name, configuration: look.configuration); showImport = false }.keyboardShortcut(.defaultAction)
                    }
                }.padding(24).frame(width: 360)
            }
        }
        .tint(Color(red: 0.20, green: 0.43, blue: 0.96))
        .sheet(isPresented: $savingLook) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Save this look").font(.title3.weight(.semibold))
                TextField("Name", text: $lookName).textFieldStyle(.roundedBorder).onSubmit { saveNamedLook() }
                Text("Keep this design, color, position, and motion together.").font(.caption).foregroundStyle(.secondary)
                HStack { Spacer(); Button("Cancel") { savingLook = false }.keyboardShortcut(.cancelAction)
                    Button("Save") { saveNamedLook() }.keyboardShortcut(.defaultAction).disabled(lookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24).frame(width: 350)
        }
        .alert("Restore appearance defaults?", isPresented: $resetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") { preferences.resetAppearance() }
        } message: { Text("Resets all shared and per-event designs, colors, positions, and motion settings. Keyboard settings are preserved.") }
        .alert("Cue", isPresented: Binding(get: { !model.message.isEmpty }, set: { if !$0 { model.message = "" } })) {
            Button("OK") { model.message = "" }
        } message: { Text(model.message) }
    }
    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.page == .overview ? "Your Mac. Your Cue." : isControlPage ? "Controls" : isDesignPage ? "Make it yours." : "General")
                    .font(.system(size: isDesignPage ? 24 : 28, weight: .semibold))
                Text(model.page == .overview ? "Just the feedback you want." : isControlPage ? "Make each adjustment feel right." : isDesignPage ? "Choose a shape. Find your feel." : "The essentials, taken care of.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }; Spacer()
            Toggle("Cue", isOn: $preferences.settings.enabled).toggleStyle(.switch).labelsHidden().help("Enable Cue")
        }
    }
    @ViewBuilder private var pageContent: some View {
        switch model.page {
        case .overview: overview
        case .volume: volumeSettings
        case .brightness: brightnessSettings
        case .charging: chargingSettings
        case .appearance: appearanceSettings
        case .position: positionSettings
        case .motion: motionSettings
        case .keyboard: keyboardSettings
        case .general: generalSettings
        }
    }
    private func navigationRow(_ page: CuePage) -> some View {
        let selected = model.page == page || page == .appearance && isDesignPage || page == .volume && isControlPage
        return Button { model.page = page } label: {
            Label(page == .volume ? "Controls" : page.rawValue, systemImage: page == .volume ? "slider.horizontal.3" : page.symbol)
                .font(.system(size: 13)).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).listRowBackground(selected ? Color.accentColor.opacity(0.14) : Color.clear)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Apply to", selection: $editKind) {
                    Text("All events").tag(nil as CueKind?)
                    ForEach(CueKind.allCases) { Text($0.title).tag(Optional($0)) }
                }.frame(width: 210)
                Spacer()
                if previousAppearance != nil {
                    Button { undoAppearance() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }.buttonStyle(.borderless).font(.caption)
                }
                Label("Autosaved", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
            }
            if let editKind {
                HStack {
                    Text(preferences.settings.overrides[editKind.rawValue] == nil ? "Using the shared look. Changes here create a \(editKind.title.lowercased()) look." : "A look just for \(editKind.title.lowercased()).")
                    Spacer()
                    if preferences.settings.overrides[editKind.rawValue] != nil { Button("Use shared look") { preferences.settings.overrides.removeValue(forKey: editKind.rawValue) }.buttonStyle(.link) }
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var preview: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: previewBackdrop == 1 ? [Color(red: 0.73, green: 0.8, blue: 0.91), Color(red: 0.92, green: 0.91, blue: 0.96)] : previewBackdrop == 2 ? [Color(white: 0.12), Color(white: 0.23)] : [Color(red: 0.22, green: 0.34, blue: 0.65), Color(red: 0.45, green: 0.48, blue: 0.79), Color(red: 0.74, green: 0.56, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                GeometryReader { geometry in
                    Ellipse().fill(.white.opacity(0.18)).frame(width: 460, height: 130).blur(radius: 45).rotationEffect(.degrees(-25)).offset(x: -80, y: -40)
                    Ellipse().fill(.blue.opacity(0.2)).frame(width: 440, height: 140).blur(radius: 45).offset(x: 210, y: 220)
                    let factor = min(config.scale * 0.74, (geometry.size.width - 64) / config.size.width, (geometry.size.height - 82) / config.size.height)
                    let hudSize = CGSize(width: config.size.width * factor, height: config.size.height * factor)
                    let frame = hudFrame(in: CGRect(x: 18, y: 39, width: geometry.size.width - 36, height: geometry.size.height - 78), size: hudSize, anchor: config.position.anchor, margin: 7, offsetX: config.offsetX * 0.15, offsetY: config.offsetY * 0.15)
                    CueVisual(event: event, config: config, reduceMotion: preferences.settings.reduceMotion || systemReduceMotion)
                        .scaleEffect(factor * (previewVisible || preferences.settings.reduceMotion || systemReduceMotion ? 1 : 0.975))
                        .opacity(previewVisible ? 1 : 0)
                        .offset(y: previewVisible || preferences.settings.reduceMotion || systemReduceMotion ? 0 : 8)
                        .animation(config.animation(reduceMotion: preferences.settings.reduceMotion || systemReduceMotion), value: previewVisible)
                        .frame(width: hudSize.width, height: hudSize.height)
                        .position(x: frame.midX, y: geometry.size.height - frame.midY)
                }.clipped()
                VStack {
                    HStack {
                        Label("PREVIEW", systemImage: "viewfinder").font(.system(size: 9, weight: .semibold)).tracking(1.3)
                        Spacer()
                        ForEach(0..<3) { index in
                            Button { previewBackdrop = index } label: {
                                Circle().fill(index == 0 ? Color.indigo : index == 1 ? Color.white : Color.black)
                                    .frame(width: 13, height: 13).overlay(Circle().strokeBorder(.white.opacity(previewBackdrop == index ? 1 : 0.3), lineWidth: 1.5))
                            }.buttonStyle(.plain).accessibilityLabel(["Color preview background", "Light preview background", "Dark preview background"][index])
                        }
                    }.foregroundStyle(.white.opacity(0.66))
                    Spacer()
                    HStack {
                        Text("\(config.position.rawValue) · \(Int(config.scale * 100))%").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button { model.preview(selectedKind, value: previewValue, shared: isDesignPage && editKind == nil, alternate: alternatePreview) } label: { Label("Play on desktop", systemImage: "play.fill").font(.system(size: 11, weight: .medium)) }
                            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.9)).accessibilityIdentifier("desktop-preview")
                    }
                }.padding(17)
            }.frame(height: isDesignPage ? 180 : 235).clipShape(RoundedRectangle(cornerRadius: 18))
            HStack(spacing: 16) {
                if model.page.kind == nil && (!isDesignPage || editKind == nil) {
                    Picker("Preview", selection: $previewKind) { ForEach(CueKind.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 125)
                } else { Text(selectedKind.title).font(.caption).foregroundStyle(.secondary).frame(width: 75, alignment: .leading) }
                Slider(value: $previewValue, in: 0...1).accessibilityLabel("Preview level").onChange(of: previewValue) { _, _ in alternatePreview = false }
                Text(event.percentage).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 35, alignment: .trailing)
            }
            HStack {
                if selectedKind != .brightness {
                    Toggle(selectedKind == .volume ? "Preview muted" : "Preview unplugged", isOn: $alternatePreview).toggleStyle(.checkbox).font(.caption)
                }
                Spacer()
                Button { playMotionPreview() } label: { Label(motionTask == nil ? "Try motion" : "Replay motion", systemImage: "play.circle") }.buttonStyle(.borderless).font(.caption)
            }
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            preview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A small detail. A better everyday.").font(.system(size: 16, weight: .semibold))
                    Text("Volume, brightness, and power — with your own touch.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Make it yours") { model.page = .appearance }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            sectionTitle("YOUR EVERYDAY CUES")
            card {
                settingsToggle("Volume", detail: "Feedback for your sound.", symbol: "speaker.wave.2.fill", color: .blue, binding: $preferences.settings.volume)
                Divider().padding(.leading, 50)
                settingsToggle("Brightness", detail: "Only when you use the keys or Cue controls.", symbol: "sun.max.fill", color: .orange, binding: $preferences.settings.brightness)
                Divider().padding(.leading, 50)
                settingsToggle("Charging", detail: "A welcome for power. A goodbye for the cable.", symbol: "bolt.fill", color: .green, binding: $preferences.settings.charging)
            }
            HStack {
                Button("Choose your look…") { model.page = .appearance }
                Spacer()
                if preferences.temporarilyPaused {
                    Button("Resume now") { model.resume() }
                } else {
                    Menu("Pause…") { Button("15 minutes") { model.pause(minutes: 15) }; Button("1 hour") { model.pause(minutes: 60) } }.fixedSize()
                }
            }
            if let date = preferences.settings.pauseUntil, preferences.temporarilyPaused {
                Text("Paused until \(date.formatted(date: .omitted, time: .shortened)). Your settings stay in place.").font(.caption).foregroundStyle(.secondary)
            }
            appleHUDCard
            Label("Your choices are remembered when Cue reopens.", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var appleHUDCard: some View {
        card {
            settingsToggle("Show Apple HUDs", detail: "The standard volume and brightness indicators.", symbol: "macbook", color: .gray, binding: appleHUDs)
            Divider()
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: keyboard.active && preferences.settings.replaceHUD ? "checkmark.circle.fill" : "info.circle").foregroundStyle(keyboard.active && preferences.settings.replaceHUD ? Color.green : Color.secondary)
                    Text(!preferences.active ? "Cue is paused. Apple HUDs are active." : !preferences.settings.replaceHUD ? "Apple HUDs are on." : keyboard.active ? "Cue is handling supported media keys." : "Off is saved. Keyboard access is needed to apply it.").font(.system(size: 12, weight: .medium))
                    Spacer()
                    if !keyboard.active { Button(keyboard.trusted ? "Retry" : "Allow Keyboard Access…") { if keyboard.trusted { model.apply() } else { keyboard.requestAccess() } } }
                }
                DisclosureGroup("How this works") {
                    Text("Your choice is saved, even if access is missing. Accessibility access lets Cue replace supported keyboard HUDs. Quitting or removing Cue restores normal controls. Control Center can still show its own feedback.")
                        .font(.caption).foregroundStyle(.secondary).lineSpacing(3).padding(.top, 6)
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(14)
        }
    }
    private var volumeSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingsToggle("Volume animations", detail: "Follow your selected sound output.", symbol: "speaker.wave.2.fill", color: .blue, binding: $preferences.settings.volume)
                Divider(); liveControl(.volume, label: monitor.muted ? "Output volume · Muted" : "Output volume", value: monitor.volume)
                Divider(); statusRow("Sound output", value: monitor.outputName)
            }
            appearanceLink(.volume)
            card {
                settingsToggle("Output connection cue", detail: "See when your Mac switches speakers or headphones.", symbol: "hifispeaker.fill", color: .purple, binding: $preferences.settings.showOutputChanges)
                Divider(); simpleToggle("Use output name as the label", binding: $preferences.settings.showOutputName)
            }
            card {
                sliderRow("Volume step", value: $preferences.settings.volumeStep, range: 0.5...25, step: 0.25, label: String(format: "%.2g%%", preferences.settings.volumeStep))
                Divider()
                sliderRow("Volume ceiling", value: $preferences.settings.maximumVolume, range: 10...100, step: 1, label: "\(Int(preferences.settings.maximumVolume))%")
            }
            note("Step size and the ceiling apply to Cue’s keyboard handling when Apple HUDs are off. The ceiling is not a system-wide limit; other apps and Control Center can exceed it.")
            Button("Adjust hold acceleration…") { model.page = .keyboard }
            if monitor.volume == nil { note("This audio output does not expose software volume control. Its media keys remain with macOS.") }
        }
    }
    private var brightnessSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingsToggle("Brightness animations", detail: "For your brightness keys and Cue’s own control.", symbol: "sun.max.fill", color: .orange, binding: $preferences.settings.brightness)
                Divider(); liveControl(.brightness, label: "Built-in display", value: monitor.brightness)
            }
            Label("Automatic brightness stays quiet", systemImage: "sun.max.trianglebadge.exclamationmark").font(.system(size: 12, weight: .medium))
            note("Changes made automatically by macOS never trigger an animation. Cue reacts to brightness keys when keyboard access is enabled, and to the control above. Control Center changes stay quiet too.")
            if !keyboard.active { Button("Enable brightness-key detection…") { model.page = .keyboard } }
            appearanceLink(.brightness)
            card { sliderRow("Brightness step", value: $preferences.settings.brightnessStep, range: 0.5...25, step: 0.25, label: String(format: "%.2g%%", preferences.settings.brightnessStep)) }
            note("Custom steps apply with Apple HUDs off. This alpha controls the built-in display; external display brightness is not supported.")
        }
    }
    private var chargingSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingsToggle("Charging animations", detail: "Play when power connects.", symbol: "bolt.fill", color: .green, binding: $preferences.settings.charging)
                Divider()
                settingsToggle("Show disconnect", detail: "A quiet cue when the cable comes out.", symbol: "powerplug", color: .orange, binding: $preferences.settings.showDisconnect)
                Divider()
                settingsToggle("Connection sound", detail: "A soft Glass chime when power connects.", symbol: "bell.fill", color: .purple, binding: $preferences.settings.chargingSound)
                Divider(); statusRow("Battery", value: monitor.power.map { "\(Int(($0.percent * 100).rounded()))% · \($0.label)" } ?? "No internal battery")
            }
            appearanceLink(.charging)
            note("Opening Cue, battery percentage updates, and optimized charging changes stay quiet. The preview simulates a charging event.")
        }
    }
    private func appearanceLink(_ kind: CueKind) -> some View {
        card {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(kind.title) appearance").font(.system(size: 12, weight: .medium))
                    Text("\(preferences.configuration(for: kind).style.rawValue) · \(preferences.settings.overrides[kind.rawValue] == nil ? "Shared look" : "Personal look")").font(.caption).foregroundStyle(.secondary)
                }; Spacer()
                Button("Customize…") { editKind = kind; model.page = .appearance }
            }.padding(14)
        }
    }
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { sectionTitle("CHOOSE YOUR SHAPE"); Spacer(); presetMenu }
            StyleGallery(configuration: configuration, reduceMotion: preferences.settings.reduceMotion || systemReduceMotion)
            if !preferences.settings.savedLooks.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("MY LOOKS")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(preferences.settings.savedLooks) { look in
                                Button { configuration.wrappedValue = look.configuration } label: { Label(look.name, systemImage: look.configuration.style.symbol) }
                                    .contextMenu { Button("Remove look", role: .destructive) { preferences.settings.savedLooks.removeAll { $0.id == look.id } } }
                            }
                        }.padding(.vertical, 2)
                    }
                }
            }
            card {
                pickerRow("Material", selection: configuration.material, values: CueMaterial.allCases)
                Divider(); pickerRow("Appearance", selection: configuration.theme, values: CueTheme.allCases)
                Divider(); sliderRow("Size", value: configuration.scale, range: 0.5...2, step: 0.05, label: "\(Int((config.scale * 100).rounded()))%")
                Divider()
                HStack(spacing: 10) {
                    Text("Color").font(.system(size: 12)); Spacer(minLength: 8)
                    ForEach(CueAccent.allCases.filter { $0 != .custom }) { accent in
                        Button { configuration.wrappedValue.accent = accent } label: {
                            Circle().fill(accent.color).frame(width: 21, height: 21)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.1)))
                                .overlay { if config.accent == accent { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(accent == .monochrome ? Color(nsColor: .windowBackgroundColor) : Color.white) } }
                        }.buttonStyle(.plain).accessibilityLabel("\(accent.rawValue) accent").help(accent.rawValue)
                    }
                    ColorPicker("Custom color", selection: customColor, supportsOpacity: false).labelsHidden().help("Any color")
                }.padding(14)
            }
            DisclosureGroup("Fine-tune appearance") {
                card {
                    sliderRow("Width", value: configuration.width, range: 0.75...1.5, step: 0.05, label: "\(Int(config.width * 100))%")
                    Divider(); sliderRow("Height", value: configuration.height, range: 0.75...1.5, step: 0.05, label: "\(Int(config.height * 100))%")
                    Divider(); sliderRow("Corner radius", value: configuration.cornerRadius, range: 8...48, step: 1, label: "\(Int(config.cornerRadius)) pt")
                    Divider(); sliderRow("Glass tint", value: configuration.tintAmount, range: 0...0.5, step: 0.01, label: "\(Int(config.tintAmount * 100))%")
                    Divider(); sliderRow("Opacity", value: configuration.opacity, range: 0.4...1, step: 0.01, label: "\(Int(config.opacity * 100))%")
                    Divider(); sliderRow("Shadow", value: configuration.shadow, range: 0...0.5, step: 0.01, label: "\(Int(config.shadow * 100))%")
                    Divider(); simpleToggle("Show icon", binding: configuration.showIcon)
                    Divider(); simpleToggle("Show percentage", binding: configuration.showPercentage)
                    Divider(); simpleToggle("Show label", binding: configuration.showLabel)
                }.padding(.top, 10)
                note("iPhone and Compact keep labels hidden. Native Liquid Glass requires macOS 26; earlier systems use frosted glass.").padding(.top, 8)
            }
        }
    }
    private var customColor: Binding<Color> {
        Binding(get: { config.color }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            var next = configuration.wrappedValue
            next.accent = .custom; next.customRed = rgb.redComponent; next.customGreen = rgb.greenComponent; next.customBlue = rgb.blueComponent
            configuration.wrappedValue = next
        })
    }
    private var presetMenu: some View {
        Menu("Looks") {
            Button("Save this look…") { lookName = config.style.rawValue; savingLook = true }
            Button("Export this look…") { exportLook() }
            Button("Import a look…") { importLook() }
            Button("Reset this look") { configuration.wrappedValue = HUDConfiguration() }
            if !preferences.settings.savedLooks.isEmpty {
                Section("Saved looks") {
                    ForEach(preferences.settings.savedLooks) { look in
                        Button(look.name) { configuration.wrappedValue = look.configuration }
                    }
                }
                Menu("Remove saved look") {
                    ForEach(preferences.settings.savedLooks) { look in
                        Button(look.name) { preferences.settings.savedLooks.removeAll { $0.id == look.id } }
                    }
                }
            }
            Divider()
            Button("Silky Slim") { var value = MotionPreset.silky.apply(to: HUDConfiguration()); value.style = .slim; value.showLabel = false; configuration.wrappedValue = value }
            Button("Apple Glass") { var value = HUDConfiguration(); value.material = .liquid; configuration.wrappedValue = value }
            Button("iPhone · Left") { applyPhonePreset(.left) }
            Button("iPhone · Right") { applyPhonePreset(.right) }
            Button("Quiet capsule") { var value = HUDConfiguration(); value.style = .compact; value.scale = 0.85; value.position = .top; value.motion = .fade; value.showPercentage = false; configuration.wrappedValue = value }
            Button("Classic Mac") { var value = HUDConfiguration(); value.style = .classic; value.material = .frosted; value.position = .bottom; configuration.wrappedValue = value }
            Button("Floating island") { var value = HUDConfiguration(); value.style = .island; value.position = .top; value.theme = .dark; value.material = .solid; configuration.wrappedValue = value }
        }.fixedSize()
    }
    private func saveNamedLook() {
        guard !lookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        preferences.saveLook(name: lookName, configuration: config); savingLook = false
    }
    private func applyPhonePreset(_ position: CuePosition) {
        var value = HUDConfiguration(); value.style = .iphone; value.position = position
        value.material = .liquid; value.showPercentage = false; value.showLabel = false; value.cornerRadius = 25; value.motion = .spring
        configuration.wrappedValue = value
    }
    private var positionSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 28) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(63), spacing: 8), count: 3), spacing: 8) {
                    ForEach(CuePosition.allCases) { position in
                        Button { configuration.wrappedValue.position = position } label: {
                            RoundedRectangle(cornerRadius: 9).fill(config.position == position ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.035))
                                .overlay(Image(systemName: config.position == position ? "checkmark" : "circle.fill").font(.system(size: config.position == position ? 14 : 5, weight: .semibold)).foregroundStyle(config.position == position ? Color.accentColor : Color.secondary.opacity(0.35)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(config.position == position ? Color.accentColor : Color.primary.opacity(0.06)))
                                .frame(width: 63, height: 43)
                        }.buttonStyle(.plain).accessibilityLabel("Position \(position.rawValue)").help(position.rawValue)
                    }
                }.frame(width: 205)
                VStack(alignment: .leading, spacing: 9) {
                    Text(config.position.rawValue).font(.title3.weight(.semibold))
                    Text("Pick a spot, then fine-tune it below. Cue keeps your HUD inside the visible display.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    HStack { Button("iPhone left") { applyPhonePreset(.left) }; Button("iPhone right") { applyPhonePreset(.right) } }.font(.caption)
                }
            }.padding(18).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            card {
                pickerRow("Show on", selection: configuration.screen, values: CueScreen.allCases)
                Divider(); sliderRow("Edge spacing", value: configuration.edgeMargin, range: 8...180, step: 1, label: "\(Int(config.edgeMargin)) pt")
            }
            DisclosureGroup("Fine-tune position") {
              card {
                sliderRow("Horizontal offset", value: configuration.offsetX, range: -500...500, step: 1, label: "\(Int(config.offsetX)) pt")
                Divider(); sliderRow("Vertical offset", value: configuration.offsetY, range: -350...350, step: 1, label: "\(Int(config.offsetY)) pt")
            }
              Button("Center offsets") { configuration.wrappedValue.offsetX = 0; configuration.wrappedValue.offsetY = 0 }.padding(.top, 8)
            }
            note("Cue keeps the HUD inside your display. Positive offsets move right and up.")
        }
    }
    private var motionSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("PICK YOUR FEEL")
            MotionGallery(configuration: configuration)
            card {
                pickerRow("Transition", selection: configuration.motion, values: CueMotion.allCases)
                Divider(); sliderRow("Stay on screen", value: configuration.duration, range: 0.5...8, step: 0.1, label: String(format: "%.1f s", config.duration))
                Divider(); simpleToggle("Reduce motion", binding: $preferences.settings.reduceMotion)
            }
            DisclosureGroup("Fine-tune motion") {
                card {
                    sliderRow("Animation speed", value: configuration.speed, range: 0.5...2, step: 0.05, label: String(format: "%.2g×", config.speed))
                    Divider(); sliderRow("Spring bounce", value: configuration.bounce, range: 0...0.8, step: 0.01, label: "\(Int(config.bounce * 100))%")
                    Divider(); sliderRow("Level smoothing", value: configuration.smoothing, range: 0.05...0.6, step: 0.01, label: String(format: "%.2f s", config.smoothing))
                }.padding(.top, 10)
            }
            note("Repeated presses flow into the same HUD. Reduce Motion also follows your Mac’s accessibility setting.")
        }
    }
    private var keyboardSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            appleHUDCard
            sectionTitle("KEY RESPONSE")
            card {
                sliderRow("Volume step", value: $preferences.settings.volumeStep, range: 0.5...25, step: 0.25, label: String(format: "%.2f%%", preferences.settings.volumeStep))
                Divider(); sliderRow("Brightness step", value: $preferences.settings.brightnessStep, range: 0.5...25, step: 0.25, label: String(format: "%.2f%%", preferences.settings.brightnessStep))
                Divider(); sliderRow("Volume ceiling", value: $preferences.settings.maximumVolume, range: 10...100, step: 1, label: "\(Int(preferences.settings.maximumVolume))%")
            }
            DisclosureGroup("Hold acceleration") {
              card {
                sliderRow("Acceleration", value: $preferences.settings.acceleration, range: 0...5, step: 0.1, label: preferences.settings.acceleration == 0 ? "Off" : String(format: "%.1f×", 1 + preferences.settings.acceleration))
                Divider(); sliderRow("Starts after", value: $preferences.settings.accelerationDelay, range: 0.1...1.5, step: 0.05, label: String(format: "%.2f s", preferences.settings.accelerationDelay))
                Divider(); sliderRow("Build-up time", value: $preferences.settings.accelerationRamp, range: 0.3...3, step: 0.1, label: String(format: "%.1f s", preferences.settings.accelerationRamp))
            }
              note("Holding a key gradually increases each step. Option–Shift stays fine and unaccelerated.").padding(.top, 8)
            }
            note("Keyboard access is also used to recognize manual brightness changes when Apple HUDs are on. Cue never records text or other keys. Unsupported outputs keep normal macOS behavior.")
            Button("Restore keyboard defaults") {
                preferences.settings.volumeStep = 6.25; preferences.settings.brightnessStep = 6.25
                preferences.settings.maximumVolume = 100; preferences.settings.acceleration = 0
                preferences.settings.accelerationDelay = 0.35; preferences.settings.accelerationRamp = 1.4
            }
        }
    }
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                CueMark().frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Cue").font(.title.weight(.semibold)); Text("ALPHA").font(.system(size: 9, weight: .bold)).tracking(1).padding(.horizontal, 7).padding(.vertical, 4).background(.blue.opacity(0.1), in: Capsule()).foregroundStyle(.blue) }
                    Text("Give your Mac a little character.").foregroundStyle(.secondary)
                    Text("V4 Alpha · Version 0.4.0 (4) · By Softly Mac").font(.caption).foregroundStyle(.tertiary)
                }
            }.padding(.vertical, 12)
            card {
                settingsToggle("Open at login", detail: "Have Cue ready when you start your Mac.", symbol: "power", color: .gray, binding: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                Divider(); settingsToggle("Reduce motion", detail: "Keep transitions gentle.", symbol: "figure.stand", color: .blue, binding: $preferences.settings.reduceMotion)
            }
            quietAppsCard
            card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Your Mac always gets its controls back", systemImage: "checkmark.shield").font(.system(size: 13, weight: .semibold))
                    Text("Cue only intercepts media keys while it runs. Pausing, quitting, or a crash releases them. Moving or deleting Cue’s bundle releases it. Moving a containing folder is detected on activation or before the next media key. It doesn’t install a background helper or permanently disable any macOS component.")
                    Button("Restore Apple HUDs & Quit") { model.restoreAppleHUDsAndQuit() }
                }.font(.caption).lineSpacing(3).padding(16)
            }
            DisclosureGroup("About this alpha") {
              card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("The finishing touches", systemImage: "sparkles").font(.system(size: 13, weight: .semibold))
                    Text("Cue runs locally, without accounts or analytics. Keyboard replacement is experimental and depends on your keyboard and macOS version. Brightness uses an optional system interface and supports the built-in display only.")
                    Text("Native Liquid Glass requires macOS 26 or later. This alpha is locally signed for testing.")
                }.font(.caption).foregroundStyle(.secondary).lineSpacing(3).padding(16)
            }
            }
            Label("Quiet in the background", systemImage: "leaf").font(.system(size: 12, weight: .medium))
            note("Cue uses system notifications while idle. Brightness readings refresh only while their settings are visible; there are no repeating background timers.")
            HStack { Button("Restore all appearance defaults…") { resetConfirmation = true }; Spacer(); Button("Quit Cue") { NSApp.terminate(nil) } }.font(.caption)
        }
    }
    private var quietAppsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Quiet in these apps", systemImage: "moon.zzz").font(.system(size: 13, weight: .semibold))
                    Spacer(); Button("Add app…") { addQuietApp() }
                }
                Text("Hide Cue’s HUDs and chime while a chosen app is in front. Your volume and brightness keys keep working with your saved response.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if preferences.settings.quietApps.isEmpty {
                    Text("No apps added").font(.caption).foregroundStyle(.tertiary)
                }
                ForEach(preferences.settings.quietApps) { app in
                    HStack {
                        Image(systemName: "app").foregroundStyle(.secondary)
                        Text(app.name).font(.callout); Spacer()
                        Button { preferences.settings.quietApps.removeAll { $0.id == app.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove \(app.name) from quiet apps")
                    }
                }
            }.padding(16)
        }
    }
    private func addQuietApp() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.prompt = "Add Apps"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier, id != Preferences.domain,
                  !preferences.settings.quietApps.contains(where: { $0.id == id }) else { continue }
            preferences.settings.quietApps.append(QuietApp(id: id, name: url.deletingPathExtension().lastPathComponent))
        }
    }
    private func undoAppearance() {
        guard let previousAppearance else { return }
        if let scope = previousScope {
            if previousHadOverride { preferences.settings.overrides[scope.rawValue] = previousAppearance }
            else { preferences.settings.overrides.removeValue(forKey: scope.rawValue) }
        }
        else { preferences.settings.appearance = previousAppearance }
        self.previousAppearance = nil
    }
    private func exportLook() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(config.style.rawValue).cue-look.json"
        panel.title = "Export Cue Look"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try LookDocument(name: config.style.rawValue, configuration: config).encoded().write(to: url, options: .atomic) }
        catch { model.message = error.localizedDescription }
    }
    private func importLook() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.title = "Import Cue Look"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (attributes.fileSize ?? 0) <= 256_000 else { throw LookDocument.LookError.tooLarge }
            importingLook = try LookDocument.decode(Data(contentsOf: url)); showImport = true
        } catch { model.message = error.localizedDescription }
    }
    private func stopMotionPreview() {
        motionTask?.cancel(); motionTask = nil; previewVisible = true
    }
    private func playMotionPreview() {
        motionTask?.cancel()
        motionTask = Task { @MainActor in
            previewVisible = false
            do {
                try await Task.sleep(for: .milliseconds(500))
                alternatePreview = false; previewValue = 0.25; previewVisible = true
                try await Task.sleep(for: .milliseconds(550))
                for value in [0.4, 0.55, 0.7, 0.85, 0.65] {
                    try Task.checkCancellation(); previewValue = value
                    try await Task.sleep(for: .milliseconds(180))
                }
                motionTask = nil
            } catch { }
        }
    }
    private func liveControl(_ kind: CueKind, label: String, value: Double?) -> some View {
        HStack {
            Text(label).font(.system(size: 12)); Spacer()
            if let value {
                Slider(value: Binding(get: { kind == .volume ? monitor.volume ?? value : monitor.brightness ?? value }, set: { model.setLevel(kind, value: $0) }), in: 0...1).frame(width: 160).accessibilityLabel("Actual \(kind.title.lowercased())")
                Text("\(Int((value * 100).rounded()))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40)
            } else { Text("Unavailable").font(.caption).foregroundStyle(.secondary) }
        }.padding(14)
    }
    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        HStack(spacing: 14) {
            Text(title).font(.system(size: 12)); Spacer(minLength: 6)
            Slider(value: value, in: range, step: step).frame(width: 172).accessibilityLabel(title)
            Text(label).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary).frame(width: 58, alignment: .trailing)
        }.padding(14)
    }
    private func pickerRow<T: RawRepresentable & Identifiable & Hashable>(_ title: String, selection: Binding<T>, values: [T]) -> some View where T.RawValue == String {
        HStack { Text(title).font(.system(size: 12)); Spacer(); Picker(title, selection: selection) { ForEach(values) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 175) }.padding(14)
    }
    private func simpleToggle(_ title: String, binding: Binding<Bool>) -> some View { HStack { Text(title).font(.system(size: 12)); Spacer(); Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.small) }.padding(14) }
    private func sectionTitle(_ title: String) -> some View { Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary) }
    private func note(_ text: String) -> some View { Text(text).font(.caption).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
    private func statusRow(_ title: String, value: String) -> some View { HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }.font(.system(size: 12)).padding(14) }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0, content: content).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
    }
    private func settingsToggle(_ title: String, detail: String, symbol: String, color: Color, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(.white).frame(width: 30, height: 30).background(color.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 12, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Spacer(minLength: 8)
            Toggle(title, isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }.padding(14)
    }
}

struct CueMark: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: geometry.size.width * 0.24).fill(LinearGradient(colors: [Color(red: 0.30, green: 0.56, blue: 1), Color(red: 0.24, green: 0.28, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().trim(from: 0.14, to: 0.86).stroke(.white, style: StrokeStyle(lineWidth: geometry.size.width * 0.09, lineCap: .round)).padding(geometry.size.width * 0.23)
                Circle().fill(.white).frame(width: geometry.size.width * 0.105, height: geometry.size.width * 0.105).offset(x: geometry.size.width * 0.22)
            }
        }.accessibilityLabel("Cue app icon")
    }
}
