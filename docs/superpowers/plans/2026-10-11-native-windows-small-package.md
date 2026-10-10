# Small Native Windows App

The user has approved the native Win32 approach and requested direct execution.

## Design

Use C++17, Win32, and the GDI+ library built into Windows 10. Ship a single
x64 executable with no browser, .NET runtime, external DLLs, updater, or extra
language packs. Keep the product name and author, blue #002FA7, 0.36 running
opacity, remaining minutes, double-click start/pause/resume, dragging, tray,
5/25/45 presets, custom 1-180 whole minutes, reset, hide/show, close-to-tray,
explicit quit, a finish sound, three-times-size finish animation, and three
clicks to dismiss. Menus and controls use English, as requested previously.

Render with a transparent layered window and system fonts. A small header holds
platform-independent timer and pointer state, allowing tests on this Mac. The
settings dialog is modeless so entering a custom duration never blocks timing.
Only refresh the dot when its appearance changes; animate only visible alerts.
Use per-user registry settings for duration/position and restore the tray after
Explorer restarts. A single-instance mutex prevents duplicate timers.

Build locally with MinGW cross-compilation and package with NSIS LZMA solid
compression. Install per-user without administrator rights; include desktop and
Start menu shortcuts plus an uninstaller. Also supply the standalone executable.
Windows CI builds with MSVC and tests actual window messages and installation.

## Implementation

- [ ] Add failing portable timer/input tests, then implement the state model.
- [ ] Complete the native window, tray, settings, and reminder behavior.
- [ ] Build the Windows executable and compressed installer; check imports and size.
- [ ] Review the code, run portable tests and available runtime checks, and document
      remaining Windows 10 validation limits with concrete download links.

## Review Focus

Pause/resume must preserve seconds. Dragging must not toggle or dismiss. Fast
triple clicks include WM_LBUTTONDBLCLK and must dismiss exactly once. Invalid
custom input must not change the timer, and tick refreshes must not overwrite
editing. Closing settings or hiding the dot must leave the countdown running.
Tray recovery, multi-monitor positions, installation/uninstallation, and required
system libraries must not introduce a runtime download.
