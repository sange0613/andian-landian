# Lightweight Native Mac App

The user requests a directly usable lightweight Mac equivalent, preserving the
Chinese interface and author 戌無营造. Use Objective-C++ and system AppKit/Foundation.
Reuse the tested platform-independent native-win/NativeLogic.h timer and pointer
model. Target macOS 12+ with arm64 and x86_64 slices in one app. No Electron,
WebView, embedded fonts, third-party packages, or bundled runtime. Ship an app
plus a compressed DMG with an Applications shortcut. Enforce a 1MB app budget.

Keep a 78pt Klein blue circle, 0.36 running opacity, remaining minutes, double
click start/pause/resume, dragging, a small 8pt status-bar dot plus remaining
minutes, hide/show, 5/25/45 presets, custom 1-180 whole minutes, reset, settings,
author credit, and explicit quit. At expiry beep once, animate up to three times
size, blink the status title, and require three clicks to dismiss. Closing
settings or hiding the dot must not stop timing. Use a continuous monotonic
clock that includes sleep. Preserve duration and position in UserDefaults.

AppKit is used directly for the borderless, non-activating floating NSPanel,
custom pointer handling, NSStatusItem, and native settings controls. The core
timer and pointer model is separate and tested. Settings refreshes never
overwrite a custom-duration draft. Animation runs only while a visible alert
requires it; ordinary drawing occurs only when the visible state changes.

- [x] Implement and test timer deadlines, pause/resume, parsing, and pointer handling.
- [x] Implement native panel, status item, Chinese settings, and alert lifecycle.
- [x] Run AppKit interaction checks and capture/inspect rendered dot and settings.
- [x] Build universal release bundle, ad-hoc sign, validate dependencies, package DMG,
      verify installation contents and exact sizes, and deliver locally.

No Developer ID identity is installed. Local ad-hoc signing is possible;
Apple notarization is unavailable. This must be stated in the delivery notes.

Toolchain ruling: the installed SwiftPM/llbuild versions are incompatible and
the default SDK's Swift interfaces are newer than swiftc. Using the existing
Clang compiler directly avoids tool installation and yields a smaller binary.

Verification: native core and AppKit tests passed. Both universal slices target
macOS 12.0 and link only system libraries. All app files total 305,952 bytes;
the compressed DMG is approximately 106KB. Signature and DMG checksum validation
passed. Mounted DMG contents match the source app byte for byte. Settings, idle,
running, and alert renders were inspected. The independent review's two build
issues (Tests path case and reused DMG staging) were corrected and rebuilt.
Physical Intel hardware and Apple notarization remain outside local verification.
The stable Run entrypoint rebuilt the original 1.2.0 deliverable and passed an actual production
bundle launch check. Original DMG: 105,987 bytes, SHA256
7b25fc99459a7a3ec248de434725425d6397f5c996b2338a65b112bb63d82bf1.

User iterations through 1.2.6: status dot is 10pt opaque when idle/paused and
8pt at 60% opacity when running. Single-click opens a fully prepared,
non-blocking native popover immediately, with no animation or pause entry;
double-click closes it and toggles timing. Menu width 144pt, row height 22pt,
padding 6pt. No in-flight NSMenu rebuilding or double-click delay timer.
Transient event monitors only exist while the popover is open and are cleaned
up on close and shutdown. The hidden desktop dot is temporarily shown at
expiry and restored to hidden after dismissal/reset. Actual popover controls,
complete rendering, hidden timing, and cleanup passed tests.

Latest 1.2.6 local artifacts: universal app 307,216 bytes; PKG approximately 84KB;
DMG approximately 114KB. Installation receipt, signature, installed/source
executable hash equality, and a fresh production process were verified.

Pre-publication review found a stale visibility command if a timer expires while
the status popover is open. Regression reproduced the failure, then passed after
closing the popover before presenting the alarm and making show/hide commands
explicit rather than toggling live visibility. No other important findings.
