# Cue V4 Alpha · validation

September 15, 2026 · Apple silicon · macOS 27.0 (26A428) · Swift 6.2

## Passed

- Optimized packaged build with no compiler warnings; local code signature verified.
- **56 core checks** for event policies, silent automatic brightness, keyboard response, volume ceilings, and display placement.
- **76 integration checks** in the final packaged executable: earlier-alpha migration; switches and saved looks across process launches; quiet-app policy and persistence; output-feedback preferences; motion preset scope; appearance-only export round-trip and invalid/oversized import rejection; actual overlay entrance, dismissal interruption, stale callback cancellation, automatic exit, event switching, and invalid level handling; brightness readout lifecycle; all nine layouts at extreme sizes; removal detection.
- **15 layout renders** covering six settings destinations in light and dark, both HUD contact sheets, and compact-window Appearance. Bitmap captures omit parts of native Liquid Glass compositor effects; they are layout diagnostics, not exact glass screenshots.
- Live native UI inspected: glass rendering, nine-design gallery, Slim selection and Undo, motion presets, keyboard navigation, fixed preview while scrolling, advanced controls, and saved Apple-HUD-off status.
- Final packaged smoke launch/preview/exit succeeded, followed by normal launch.
- Existing V3 preference values compared before/after migration and preserved. New optional features default off. UI design-test changes were undone.

## Launch correction

Live launch exposed a blocking parent-directory open in the inherited installation monitor. V4 watches only Cue-owned bundle files. Relocating a containing folder is checked on activation, menu opening, and before consuming a media key. This preserves event-driven idle behavior without opening protected ancestor directories at startup. A fresh packaged launch after this change succeeded.

## Remaining release gates

- Accessibility permission was not granted during this run. Physical media-key replacement, key holds, and custom steps need an authorized keyboard test with this signed copy; ad-hoc rebuilding can invalidate earlier approval.
- Physical charger/output switching, other monitors and hardware, login launch, and other macOS versions still need device checks. Quiet-app policy is tested; a full presentation-app workflow remains a manual check.
- Native Liquid Glass requires macOS 26+. Built-in brightness uses an optional private system interface. Control Center can retain its own feedback.
- This is an ad-hoc signed alpha, not a notarized public release. Animation behavior is tuned and inspected; no universal frame-rate or battery-runtime guarantee is made.

Diagnostic logs and layout renders stay in Source/.build. No diagnostic path grants permissions or changes hardware levels.
