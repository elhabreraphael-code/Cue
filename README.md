# Cue · V3 Alpha (0.3.0)

Give your Mac a little character.

Cue is a standalone native macOS menu bar app from Softly Mac. It customizes volume, deliberate brightness, and power-connection feedback with SwiftUI, AppKit, and native Apple materials.

## Open

Open `../Releases/0.3.0 Alpha/Cue.app`. Closing settings leaves Cue in the menu bar. Choose **Quit Cue** to stop it. Settings from previous alphas migrate automatically; this update preserves existing switches, keyboard response, and shared/per-event appearances.

## V3: simpler, remembered, quieter

- Four sidebar sections: Overview, Appearance, Controls, General. Appearance contains Design/Position/Motion; Controls contains Volume/Brightness/Charging/Keyboard. Detailed adjustments live in disclosure sections.
- All HUD switches persist, including Apple HUD visibility and disabled Cue events. Critical switches are flushed when changed, and settings flush on window close or quit. Missing fields or an unknown enum no longer discard the entire configuration; a last-valid backup recovers damaged primary data.
- The app explicitly shows when an off preference is saved but Accessibility access is missing. An ad-hoc alpha rebuild can invalidate macOS's permission for the previous binary; that is independent of the saved choice.
- **Looks → Save this look** stores a named design, material, color, size, position, and motion. Saved looks apply to the currently selected event scope. Built-in presets remain in the same menu.
- **Pause…** on Overview or the menu bar pauses for 15 minutes or an hour. The deadline survives relaunch and does not overwrite the permanent enable switch. Resume now ends a temporary pause early.
- A new copy asks an older running Cue copy to quit before loading settings, preventing simultaneous versions from handling the same keys or writing stale settings.
- Native untinted Liquid Glass uses Apple's unmodified material. Glass icons and shadows are more restrained; entrances are shorter and less bouncy. All existing numeric appearance choices are preserved.
- Idle Cue has **no repeating app timers**. Brightness readout polling exists only while the brightness controls are visible and the app is active, at two seconds with tolerance. Permission status refreshes on activation or menu opening. App removal and ancestor-folder moves use file-system notifications. Audio and charging remain event-driven.
- No reduced animation quality or changed keyboard increments are imposed to save power. Duplicate HUD values and unchanged window frames avoid redundant updates. This is a reduction in idle work, not a measured battery-life percentage.

## Customization retained from V2


- **Automatic brightness is silent.** Display telemetry only updates the reading. Brightness cues are explicitly triggered by brightness keys or Cue’s actual brightness slider. Keyboard detection requires Accessibility access. Control Center brightness changes also stay silent because macOS does not expose reliable origin metadata for arbitrary brightness changes.
- **Eight designs:** Glass, Compact, iPhone, Island, Orbit, Classic, Wave, and Tile.
- **Apple materials:** native Liquid Glass and Clear Glass on macOS 26+, with frosted fallback on macOS 14–15; Frosted and Solid are also selectable.
- **Colors:** 12 presets including adaptive Monochrome, plus a native color picker for any custom color. Appearance can follow macOS or use Light or Dark. Glass tint, opacity, and shadow are adjustable.
- **Size and details:** 50–200% HUD scale, independent width/height, corner radius, icon, percentage, and label controls. Labels are intentionally absent from the iPhone and Compact layouts.
- **Placement:** nine anchors, edge spacing, horizontal/vertical offsets, and pointer/main/built-in display selection. iPhone Left and iPhone Right presets are available. HUDs are constrained to the visible display and scaled to fit small screens.
- **Motion:** Fluid, Spring, Glide, or Fade; speed, bounce, level smoothing, and hold duration. Repeated changes update the visible HUD without restarting its entrance. Reduce Motion and Reduce Transparency are respected.
- **Per-event looks:** choose All events, Volume, Brightness, or Charging in Appearance’s Design, Position, and Motion sections. Editing an event creates its own configuration; Use shared look removes that override.
- **Keyboard response:** volume/brightness steps from 0.5% to 25%, volume ceiling, and hold acceleration with adjustable delay, ramp, and multiplier. Option–Shift uses quarter steps without acceleration. Option-only keeps normal system shortcuts.
- **Power:** optional disconnect cue and optional Glass connection chime. Battery percentage and optimized-charging changes remain silent.

## Apple HUD switch

**Overview → Show Apple HUDs** is the main switch; it is also available in Keyboard and the menu bar.

- **On:** media keys pass through to macOS. Cue may add its own enabled overlays. Custom key step sizes and acceleration are not applied.
- **Off:** with Accessibility access, Cue handles supported volume, mute, and brightness keys and consumes the corresponding events. Enabled Cue overlays show instead. Turning off a Cue event can therefore give silent key control while Apple HUDs are also off.
- **Access missing or unsupported control:** keys continue to macOS; the settings page clearly reports that Apple HUDs remain active.
- **Paused, quit, or crashed:** the event tap is released, and normal macOS behavior resumes. Cue does not alter system daemons or persistently disable Apple’s HUD service.
- **Moved or deleted while running:** file-system watches on the bundle, executable, and containing folders stop Cue if its app bundle or executable disappears. The General page also has **Restore Apple HUDs & Quit**, which turns replacement off and unregisters login launch when possible.

To enable key handling, click **Allow Keyboard Access…**, allow this Cue app under System Settings → Privacy & Security → Accessibility, and return to Cue. Detection refreshes automatically. This alpha is ad-hoc signed; rebuilding or switching app copies may require permission to be granted again.

The switch covers supported **keyboard** HUDs, not every possible macOS indicator. Control Center, unsupported devices, other key utilities, or OS-reserved event paths may still show Apple feedback. Replacement remains experimental until verified with the user’s physical keyboard and authorized access.

## Technical scope

- macOS 14+; packaged build is Apple silicon.
- Default output volume and mute use Core Audio notifications.
- Built-in brightness uses optional, dynamically resolved private DisplayServices functions. They may change with macOS; external display DDC is not included.
- Brightness telemetry refreshes only while the active brightness settings are visible; it never triggers a HUD on its own.
- Charger events use IOKit notifications.
- Overlays never take keyboard focus and ignore pointer events.
- Settings are stored locally under `com.softlymac.cue`, using a tolerant JSON preference with a backup and migration from previous alphas. No accounts, network requests, analytics, screen recording, helper process, or third-party dependencies.
- The volume ceiling applies to Cue-controlled increases and the Cue volume slider; it is not a system-wide restriction on other software.
- This is a locally signed alpha, not a Developer ID signed/notarized public release.

## Build and validation

Requires Apple Command Line Tools with a Swift 6.2/macOS 26-capable SDK (the app still supports macOS 14+ through availability checks).

```sh
swift run CueChecks
./scripts/build.sh
"../Releases/0.3.0 Alpha/Cue.app/Contents/MacOS/Cue" --integration-check --check-directory "$PWD/.build"
```

Quit the running Cue before rebuilding its packaged app. The build script generates `Cue.app` and `Cue-0.3.0-alpha-mac.zip` under Releases. `--smoke-test` is also available to show a preview, report hardware readings, and exit.

- `CueCore`: event policy, level baselines, custom key response, screen placement.
- `Cue`: original SwiftUI/AppKit interface, materials, system integration, preferences, and removal guard.
- `CueChecks`: deterministic core checks.
- `IntegrationChecks.swift`: opt-in checks for migration, persistent event overrides, real read-only brightness sampling, extreme layouts, and a disposable bundle removal callback. No hardware values are changed.

See `VALIDATION.md` for evidence and remaining physical-device checks.

## API references

- [Apple’s Liquid Glass materials](https://developer.apple.com/documentation/swiftui/glass)
- [Core Audio property listeners](https://developer.apple.com/documentation/coreaudio/audioobjectaddpropertylistenerblock(_:_:_:_:))
- [IOKit power notifications](https://developer.apple.com/documentation/iokit/1523868-iopsnotificationcreaterunloopsou)
- [Core Graphics event taps](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [File-system dispatch sources](https://developer.apple.com/documentation/dispatch/dispatchsourcefilesystemobject)

Copyright © 2026 Softly Mac. All rights reserved.
