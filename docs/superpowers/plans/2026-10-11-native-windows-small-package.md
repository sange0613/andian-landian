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

- [x] Add failing portable timer/input tests, then implement the state model.
- [x] Complete the native window, tray, settings, and reminder behavior.
- [x] Build the Windows executable and compressed installer; check imports and size.
- [x] Review the code, run portable tests and available runtime checks, and document
      remaining Windows 10 validation limits with concrete download links.

## Evidence So Far

Portable C++ tests pass, including address/undefined-behavior sanitizer checks.
Local MinGW executable: 91,136 bytes. NSIS package: 114,246 bytes after the
Windows SDK macro fix. PE imports contain Windows system libraries only;
7-Zip archive verification passed. Independent source/installer review found no
important issues. Windows CI is running real window and installation tests.
The first MSVC build found an SDK `small` macro collision in a font variable;
renaming it to `smallFont` addresses the diagnosed compile error.

## Final Verification

Windows run 38097249105 at commit ff44c3e passed all build, portable logic,
real Win32 window/settings messages, install, installed launch, close-to-tray,
explicit quit, and uninstall checks. The PowerShell smoke test was corrected
to pass an actual C# null title to FindWindow, and to pass the uninstaller
arguments as one string. Temporary product startup logging was removed.

Verified Windows/MSVC delivery: executable 198,656 bytes, installer 160,964
bytes, complete installed directory 271,516 bytes. Only user32, gdi32,
shell32, gdiplus, advapi32, and kernel32 are imported. Artifacts and their
SHA-256 report were downloaded to dist/暗淡蓝点-Win10-轻量版/.
The validation OS is Windows NT 10.0.26100.0, not a Windows 10 physical
machine; physical Windows 10 verification remains a user trial.
The independent review found no important product issues. The implementation
is retained on codex/native-windows-small; no Release was created.

## Review Focus

Pause/resume must preserve seconds. Dragging must not toggle or dismiss. Fast
triple clicks include WM_LBUTTONDBLCLK and must dismiss exactly once. Invalid
custom input must not change the timer, and tick refreshes must not overwrite
editing. Closing settings or hiding the dot must leave the countdown running.
Tray recovery, multi-monitor positions, installation/uninstallation, and required
system libraries must not introduce a runtime download.
