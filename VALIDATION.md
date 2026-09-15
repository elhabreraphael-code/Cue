# Cue V3 Alpha · validation

September 15, 2026. Apple silicon, macOS 27.0 (26A428), Swift 6.2 command line tools.

## Verified

- Optimized build with no compiler warnings.
- **56 core checks** for power transitions, silent brightness telemetry, key response, ceilings, fine adjustments, and screen placement.
- **48 integration checks** for migration, all hidden-HUD switches, named looks, real cross-process preference reload, missing fields, unknown enum recovery, damaged-data backup recovery, temporary pause persistence/expiry, brightness timer creation/removal, actual read-only brightness samples, extreme HUD dimensions, and event-driven removal detection (including a containing folder being moved).
- A launch failure discovered during UI verification was corrected: the app's own preference domain uses `UserDefaults.standard`; opening that same domain as an extra named suite can return nil on this macOS build. Diagnostic suites remain explicitly isolated. The corrected app passed the normal packaged smoke launch and exit.
- Pre-upgrade preference snapshot compared to migrated settings: all existing keys and values preserved, including `replaceHUD = true` (Apple HUDs off), existing event switches, and the full appearance configuration. User changes during subsequent exploration remain user-controlled.
- Native accessibility/screenshot checks: four sidebar destinations, clean Overview with Apple HUDs off remembered, Design/Position/Motion organization, saved-state explanation when keyboard access is missing, appearance controls, and collapsed detailed sections.
- Local signature, plist, and ZIP validation during packaging.

## Energy work

V2 had repeating brightness, permission, and installation checks. V3 has no repeating app timer when idle in the background. Its only repeating timer is a two-second brightness readout refresh, created only while that page is visible and the app is active and invalidated when it is not. Permission refresh uses app/menu events. Installation monitoring watches rename/delete events on the executable, bundle, and ancestors. Audio and power use system notifications. Duplicate values and unchanged panel frames do not request redundant updates.

This verifies reduced idle work; it is not a measured battery-runtime improvement or a promise of zero CPU/GPU use. Existing settings, system controls, and animation quality are not reduced for power savings.

## Limits

Keyboard access was still ungranted during inspection. The saved Apple-HUD-off preference is independent of macOS Accessibility permission, so physical media-key suppression and custom steps still require the user's authorized test. Ad-hoc rebuilt binaries may need their macOS permission re-enabled. Control Center may retain its own feedback.

Manual charger operations, additional hardware/output devices, login launch, other macOS versions, and exhaustive visual combinations remain physical-device checks. Automatic brightness suppression and pause/persistence logic were tested without changing hardware levels or granting permissions. Temporary diagnostic data was removed from the test suite and workspace check directory.
