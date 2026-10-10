#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>
#include <objidl.h>
#include <gdiplus.h>
#include <cwchar>
#include "NativeLogic.h"
#include "resource.h"

using dimblue::Status;
constexpr wchar_t kTitle[] = L"暗淡蓝点";
constexpr wchar_t kClass[] = L"DimBlueDotNative";
constexpr wchar_t kRegistry[] = L"Software\\Xuwu\\DimBlueDotNative";
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kShowMessage = WM_APP + 2;
constexpr UINT_PTR kTick = 1, kAnimate = 2;
constexpr int kDotSize = 78;

HINSTANCE gInstance;
HWND gWindow = nullptr, gSettings = nullptr;
HICON gIcon = nullptr;
NOTIFYICONDATAW gTray{};
UINT gTaskbarCreated = 0;
dimblue::Timer gTimer;
dimblue::Pointer gPointer;
RECT gDragOrigin{};
POINT gCenter{200, 200};
int gDpi = 96, gWindowSize = 0;
bool gHidden = false, gQuitting = false, gTrayAdded = false;
ULONGLONG gAlertStart = 0;
std::uint64_t gDisplayedMinute = ~std::uint64_t{0};
int gDisplayedClicks = -1;
Status gDisplayedStatus = Status::Finished;

INT_PTR CALLBACK SettingsProc(HWND, UINT, WPARAM, LPARAM);
void Refresh(bool force = false);

int Scale(int value) { return MulDiv(value, gDpi, 96); }
std::uint64_t Now() { return GetTickCount64(); }

const wchar_t* StatusText() {
    switch (gTimer.status) {
        case Status::Running: return L"Running";
        case Status::Paused: return L"Paused";
        case Status::Finished: return L"Finished";
        default: return L"Ready";
    }
}

void SavePreferences() {
    HKEY key;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kRegistry, 0, nullptr, 0, KEY_SET_VALUE,
                        nullptr, &key, nullptr) != ERROR_SUCCESS) return;
    DWORD minutes = gTimer.minutes;
    DWORD x = static_cast<DWORD>(gCenter.x), y = static_cast<DWORD>(gCenter.y);
    RegSetValueExW(key, L"Minutes", 0, REG_DWORD, reinterpret_cast<BYTE*>(&minutes), sizeof(minutes));
    RegSetValueExW(key, L"CenterX", 0, REG_DWORD, reinterpret_cast<BYTE*>(&x), sizeof(x));
    RegSetValueExW(key, L"CenterY", 0, REG_DWORD, reinterpret_cast<BYTE*>(&y), sizeof(y));
    RegCloseKey(key);
}

void LoadPreferences() {
    HKEY key;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kRegistry, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) return;
    DWORD value = 0, bytes = sizeof(value), type = 0;
    if (RegQueryValueExW(key, L"Minutes", nullptr, &type, reinterpret_cast<BYTE*>(&value), &bytes) == ERROR_SUCCESS && type == REG_DWORD)
        gTimer.select(static_cast<int>(value));
    bytes = sizeof(value);
    if (RegQueryValueExW(key, L"CenterX", nullptr, &type, reinterpret_cast<BYTE*>(&value), &bytes) == ERROR_SUCCESS && type == REG_DWORD)
        gCenter.x = static_cast<LONG>(value);
    bytes = sizeof(value);
    if (RegQueryValueExW(key, L"CenterY", nullptr, &type, reinterpret_cast<BYTE*>(&value), &bytes) == ERROR_SUCCESS && type == REG_DWORD)
        gCenter.y = static_cast<LONG>(value);
    RegCloseKey(key);
}

void KeepOnScreen(int size) {
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(MonitorFromPoint(gCenter, MONITOR_DEFAULTTONEAREST), &info)) return;
    int half = size / 2;
    if (gCenter.x < info.rcWork.left + half) gCenter.x = info.rcWork.left + half;
    if (gCenter.x > info.rcWork.right - half) gCenter.x = info.rcWork.right - half;
    if (gCenter.y < info.rcWork.top + half) gCenter.y = info.rcWork.top + half;
    if (gCenter.y > info.rcWork.bottom - half) gCenter.y = info.rcWork.bottom - half;
}

void DrawDot(float diameter) {
    using namespace Gdiplus;
    if (!gWindow || gHidden) return;
    const int size = Scale(kDotSize * (gTimer.status == dimblue::Status::Finished ? 3 : 1));
    if (size != gWindowSize) {
        KeepOnScreen(size);
        gWindowSize = size;
    }
    Bitmap image(size, size, PixelFormat32bppPARGB);
    {
        Graphics graphics(&image);
        graphics.SetSmoothingMode(SmoothingModeAntiAlias);
        graphics.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
        const float circleSize = diameter * gDpi / 96.0f - 2.0f;
        const float offset = (size - circleSize) / 2.0f;
        SolidBrush blue(Color(gTimer.status == dimblue::Status::Running ? 92 : 255, 0, 47, 167));
        graphics.FillEllipse(&blue, offset, offset, circleSize, circleSize);
        SolidBrush white(Color(235, 255, 255, 255));
        Font font(L"Segoe UI", static_cast<REAL>(Scale(18)), FontStyleBold, UnitPixel);
        StringFormat format;
        format.SetAlignment(StringAlignmentCenter);
        format.SetLineAlignment(StringAlignmentCenter);
        wchar_t text[16];
        const auto minute = (gTimer.remaining(Now()) + 59999) / 60000;
        swprintf(text, 16, L"%u", static_cast<unsigned>(minute));
        graphics.DrawString(text, -1, &font, RectF(0, 0, static_cast<REAL>(size), static_cast<REAL>(size)), &format, &white);
        if (gTimer.status == dimblue::Status::Finished) {
            Font small(L"Segoe UI", static_cast<REAL>(Scale(11)), FontStyleRegular, UnitPixel);
            swprintf(text, 16, L"%d/3", gTimer.dismissClicks);
            graphics.DrawString(text, -1, &small, RectF(0, static_cast<REAL>(Scale(18)), static_cast<REAL>(size), static_cast<REAL>(size)), &format, &white);
        }
    }
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = size;
    info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void* pixels = nullptr;
    HDC screen = GetDC(nullptr);
    HDC memory = CreateCompatibleDC(screen);
    HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &pixels, nullptr, 0);
    if (memory && bitmap && pixels) {
        BitmapData data{};
        Rect rect(0, 0, size, size);
        if (image.LockBits(&rect, ImageLockModeRead, PixelFormat32bppPARGB, &data) == Ok) {
            for (int y = 0; y < size; ++y)
                CopyMemory(static_cast<BYTE*>(pixels) + y * size * 4, static_cast<BYTE*>(data.Scan0) + y * data.Stride, size * 4);
            image.UnlockBits(&data);
            HGDIOBJ old = SelectObject(memory, bitmap);
            POINT destination{gCenter.x - size / 2, gCenter.y - size / 2}, source{0, 0};
            SIZE dimensions{size, size};
            BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
            UpdateLayeredWindow(gWindow, screen, &destination, &dimensions, memory, &source, 0, &blend, ULW_ALPHA);
            SelectObject(memory, old);
        }
    }
    if (bitmap) DeleteObject(bitmap);
    if (memory) DeleteDC(memory);
    ReleaseDC(nullptr, screen);
}

void UpdateTray() {
    const unsigned minutes = static_cast<unsigned>((gTimer.remaining(Now()) + 59999) / 60000);
    swprintf(gTray.szTip, ARRAYSIZE(gTray.szTip), L"暗淡蓝点 | %u min | %ls", minutes, StatusText());
    if (gTrayAdded) Shell_NotifyIconW(NIM_MODIFY, &gTray);
}

void AddTray() {
    gTray.cbSize = sizeof(gTray);
    gTray.hWnd = gWindow;
    gTray.uID = 1;
    gTray.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    gTray.uCallbackMessage = kTrayMessage;
    gTray.hIcon = gIcon;
    UpdateTray();
    gTrayAdded = Shell_NotifyIconW(NIM_ADD, &gTray) != FALSE;
}

void UpdateSettings(bool syncInput) {
    if (!gSettings) return;
    wchar_t text[80];
    swprintf(text, 80, L"%u min  ·  %ls", static_cast<unsigned>((gTimer.remaining(Now()) + 59999) / 60000), StatusText());
    SetDlgItemTextW(gSettings, IDC_STATUS, text);
    SetDlgItemTextW(gSettings, IDC_TOGGLE, gTimer.status == Status::Running ? L"Pause" : gTimer.status == Status::Paused ? L"Resume" : L"Start");
    EnableWindow(GetDlgItem(gSettings, IDC_TOGGLE), gTimer.status != Status::Finished);
    CheckDlgButton(gSettings, IDC_PRESET5, gTimer.minutes == 5 ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(gSettings, IDC_PRESET25, gTimer.minutes == 25 ? BST_CHECKED : BST_UNCHECKED);
    CheckDlgButton(gSettings, IDC_PRESET45, gTimer.minutes == 45 ? BST_CHECKED : BST_UNCHECKED);
    if (syncInput) {
        SetDlgItemInt(gSettings, IDC_CUSTOM, gTimer.minutes, FALSE);
        SetDlgItemTextW(gSettings, IDC_ERROR, L"");
    }
}

void Refresh(bool force) {
    const auto minute = (gTimer.remaining(Now()) + 59999) / 60000;
    if (!force && minute == gDisplayedMinute && gTimer.status == gDisplayedStatus && gTimer.dismissClicks == gDisplayedClicks) return;
    gDisplayedMinute = minute;
    gDisplayedStatus = gTimer.status;
    gDisplayedClicks = gTimer.dismissClicks;
    DrawDot(gTimer.status == Status::Finished ? static_cast<float>(kDotSize * 3) : static_cast<float>(kDotSize));
    UpdateTray();
    UpdateSettings(false);
}

void OnFinished() {
    gAlertStart = Now();
    if (!gHidden) SetTimer(gWindow, kAnimate, 33, nullptr);
    MessageBeep(MB_ICONEXCLAMATION);
    lstrcpynW(gTray.szInfoTitle, kTitle, ARRAYSIZE(gTray.szInfoTitle));
    lstrcpynW(gTray.szInfo, L"Time is up.", ARRAYSIZE(gTray.szInfo));
    gTray.dwInfoFlags = NIIF_INFO | NIIF_NOSOUND;
    gTray.uFlags |= NIF_INFO;
    Shell_NotifyIconW(NIM_MODIFY, &gTray);
    gTray.uFlags &= ~NIF_INFO;
    Refresh(true);
}

void ToggleTimer() {
    if (gTimer.tick(Now())) OnFinished();
    gTimer.toggle(Now());
    Refresh(true);
}

void SelectDuration(int minutes) {
    if (!gTimer.select(minutes)) return;
    KillTimer(gWindow, kAnimate);
    SavePreferences();
    UpdateSettings(true);
    Refresh(true);
}

void Dismiss() {
    if (gTimer.status != Status::Finished) return;
    if (gTimer.dismiss()) KillTimer(gWindow, kAnimate);
    Refresh(true);
}

void SetVisible(bool visible) {
    gHidden = !visible;
    if (visible) {
        KeepOnScreen(Scale(kDotSize * (gTimer.status == Status::Finished ? 3 : 1)));
        Refresh(true);
        ShowWindow(gWindow, SW_SHOWNOACTIVATE);
        if (gTimer.status == Status::Finished) SetTimer(gWindow, kAnimate, 33, nullptr);
    } else {
        ShowWindow(gWindow, SW_HIDE);
        KillTimer(gWindow, kAnimate);
    }
}

void ShowSettings() {
    if (!gSettings) gSettings = CreateDialogParamW(gInstance, MAKEINTRESOURCEW(IDD_SETTINGS), nullptr, SettingsProc, 0);
    if (gSettings) {
        ShowWindow(gSettings, SW_SHOW);
        SetForegroundWindow(gSettings);
    }
}

void Quit() { gQuitting = true; DestroyWindow(gWindow); }

void Command(UINT command) {
    switch (command) {
        case IDM_SETTINGS: ShowSettings(); break;
        case IDM_HIDE: SetVisible(gHidden); break;
        case IDC_PRESET5: SelectDuration(5); break;
        case IDC_PRESET25: SelectDuration(25); break;
        case IDC_PRESET45: SelectDuration(45); break;
        case IDC_TOGGLE: ToggleTimer(); break;
        case IDC_RESET: SelectDuration(gTimer.minutes); break;
        case IDM_EXIT: Quit(); break;
    }
}

void ShowMenu() {
    HMENU menu = CreatePopupMenu();
    AppendMenuW(menu, MF_STRING, IDM_HIDE, gHidden ? L"Show blue dot" : L"Hide blue dot");
    AppendMenuW(menu, MF_STRING, IDM_SETTINGS, L"Settings...");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING | (gTimer.minutes == 5 ? MF_CHECKED : 0), IDC_PRESET5, L"5 minutes");
    AppendMenuW(menu, MF_STRING | (gTimer.minutes == 25 ? MF_CHECKED : 0), IDC_PRESET25, L"25 minutes");
    AppendMenuW(menu, MF_STRING | (gTimer.minutes == 45 ? MF_CHECKED : 0), IDC_PRESET45, L"45 minutes");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING | (gTimer.status == Status::Finished ? MF_GRAYED : 0), IDC_TOGGLE,
                gTimer.status == Status::Running ? L"Pause" : gTimer.status == Status::Paused ? L"Resume" : L"Start");
    AppendMenuW(menu, MF_STRING, IDC_RESET, L"Reset");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, IDM_EXIT, L"Quit");
    POINT point{};
    GetCursorPos(&point);
    SetForegroundWindow(gWindow);
    UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, gWindow, nullptr);
    DestroyMenu(menu);
    PostMessageW(gWindow, WM_NULL, 0, 0);
    Command(command);
}

INT_PTR CALLBACK SettingsProc(HWND dialog, UINT message, WPARAM wParam, LPARAM) {
    switch (message) {
        case WM_INITDIALOG: {
            gSettings = dialog;
            SendDlgItemMessageW(dialog, IDC_CUSTOM, EM_SETLIMITTEXT, 8, 0);
            UpdateSettings(true);
            RECT rect{};
            GetWindowRect(dialog, &rect);
            MONITORINFO info{};
            info.cbSize = sizeof(info);
            GetMonitorInfoW(MonitorFromPoint(gCenter, MONITOR_DEFAULTTONEAREST), &info);
            SetWindowPos(dialog, HWND_TOP, info.rcWork.left + (info.rcWork.right - info.rcWork.left - (rect.right - rect.left)) / 2,
                         info.rcWork.top + (info.rcWork.bottom - info.rcWork.top - (rect.bottom - rect.top)) / 2,
                         0, 0, SWP_NOSIZE);
            return TRUE;
        }
        case WM_COMMAND:
            switch (LOWORD(wParam)) {
                case IDOK: {
                    wchar_t text[32];
                    GetDlgItemTextW(dialog, IDC_CUSTOM, text, ARRAYSIZE(text));
                    int minutes = 0;
                    if (!dimblue::parseMinutes(text, minutes)) {
                        SetDlgItemTextW(dialog, IDC_ERROR, L"Enter a whole number from 1 to 180.");
                        SetFocus(GetDlgItem(dialog, IDC_CUSTOM));
                        return TRUE;
                    }
                    SelectDuration(minutes);
                    return TRUE;
                }
                case IDCANCEL: DestroyWindow(dialog); return TRUE;
                case IDC_PRESET5: case IDC_PRESET25: case IDC_PRESET45:
                case IDC_TOGGLE: case IDC_RESET: Command(LOWORD(wParam)); return TRUE;
                case IDC_QUIT: Quit(); return TRUE;
            }
            break;
        case WM_CLOSE: DestroyWindow(dialog); return TRUE;
        case WM_DESTROY: gSettings = nullptr; return TRUE;
    }
    return FALSE;
}

LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == gTaskbarCreated) { gTrayAdded = false; AddTray(); return 0; }
    switch (message) {
        case WM_LBUTTONDOWN: case WM_LBUTTONDBLCLK: {
            POINT point{};
            GetCursorPos(&point);
            GetWindowRect(window, &gDragOrigin);
            gPointer.down(point.x, point.y, message == WM_LBUTTONDBLCLK);
            SetCapture(window);
            return 0;
        }
        case WM_MOUSEMOVE: {
            if (!gPointer.pressed) return 0;
            POINT point{};
            GetCursorPos(&point);
            if (gPointer.move(point.x, point.y)) {
                int x = gDragOrigin.left + point.x - gPointer.startX;
                int y = gDragOrigin.top + point.y - gPointer.startY;
                gCenter = {x + gWindowSize / 2, y + gWindowSize / 2};
                SetWindowPos(window, HWND_TOPMOST, x, y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
            }
            return 0;
        }
        case WM_LBUTTONUP: {
            const bool dragged = gPointer.dragged;
            const auto action = gPointer.up(gTimer.status == Status::Finished);
            ReleaseCapture();
            if (dragged) {
                KeepOnScreen(gWindowSize);
                SetWindowPos(window, HWND_TOPMOST, gCenter.x - gWindowSize / 2, gCenter.y - gWindowSize / 2, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
                SavePreferences();
            } else if (action == dimblue::ClickAction::Toggle) ToggleTimer();
            else if (action == dimblue::ClickAction::Dismiss) Dismiss();
            return 0;
        }
        case WM_CAPTURECHANGED: case WM_CANCELMODE: gPointer.cancel(); return 0;
        case WM_RBUTTONUP: ShowMenu(); return 0;
        case WM_COMMAND: Command(LOWORD(wParam)); return 0;
        case WM_TIMER:
            if (wParam == kTick) {
                if (gTimer.tick(Now())) OnFinished();
                Refresh();
            } else if (wParam == kAnimate && gTimer.status == Status::Finished && !gHidden) {
                const ULONGLONG elapsed = (Now() - gAlertStart) % 2500;
                const float phase = static_cast<float>(elapsed <= 1250 ? elapsed : 2500 - elapsed) / 1250.0f;
                const float eased = phase * phase * (3.0f - 2.0f * phase);
                DrawDot(kDotSize * (1.0f + 2.0f * eased));
            }
            return 0;
        case kTrayMessage:
            if (lParam == WM_LBUTTONUP || lParam == NIN_BALLOONUSERCLICK) {
                if (gHidden) SetVisible(true);
                else if (gTimer.status == Status::Finished) Dismiss();
                else ToggleTimer();
            } else if (lParam == WM_RBUTTONUP) ShowMenu();
            return 0;
        case kShowMessage: SetVisible(true); return 0;
        case WM_DPICHANGED:
            gDpi = HIWORD(wParam);
            Refresh(true);
            return 0;
        case WM_DISPLAYCHANGE: KeepOnScreen(gWindowSize); Refresh(true); return 0;
        case WM_POWERBROADCAST:
            if (wParam == PBT_APMRESUMEAUTOMATIC || wParam == PBT_APMRESUMESUSPEND) {
                if (gTimer.tick(Now())) OnFinished();
                Refresh();
            }
            return TRUE;
        case WM_CLOSE:
            if (!gQuitting) { SetVisible(false); return 0; }
            break;
        case WM_QUERYENDSESSION: return TRUE;
        case WM_ENDSESSION:
            if (wParam) Quit();
            return 0;
        case WM_DESTROY:
            SavePreferences();
            if (gSettings) DestroyWindow(gSettings);
            KillTimer(window, kTick);
            KillTimer(window, kAnimate);
            if (gTrayAdded) Shell_NotifyIconW(NIM_DELETE, &gTray);
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(window, message, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    gInstance = instance;
    HANDLE mutex = CreateMutexW(nullptr, FALSE, L"Local\\DimBlueDotNativeInstance");
    if (!mutex) return 1;
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        if (HWND existing = FindWindowW(kClass, nullptr)) PostMessageW(existing, kShowMessage, 0, 0);
        CloseHandle(mutex);
        return 0;
    }
    SetProcessDPIAware();
    HDC screen = GetDC(nullptr);
    gDpi = GetDeviceCaps(screen, LOGPIXELSX);
    ReleaseDC(nullptr, screen);
    LoadPreferences();
    Gdiplus::GdiplusStartupInput startup;
    ULONG_PTR token = 0;
    if (Gdiplus::GdiplusStartup(&token, &startup, nullptr) != Gdiplus::Ok) { CloseHandle(mutex); return 1; }
    gIcon = static_cast<HICON>(LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP), IMAGE_ICON, 16, 16, LR_SHARED));
    gTaskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpfnWndProc = WindowProc;
    wc.lpszClassName = kClass;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = gIcon;
    wc.style = CS_DBLCLKS;
    int result = 1;
    if (RegisterClassExW(&wc)) {
        KeepOnScreen(Scale(kDotSize));
        gWindow = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
                                  kClass, kTitle, WS_POPUP, gCenter.x - Scale(kDotSize) / 2,
                                  gCenter.y - Scale(kDotSize) / 2, Scale(kDotSize), Scale(kDotSize),
                                  nullptr, nullptr, instance, nullptr);
        if (gWindow) {
            AddTray();
            Refresh(true);
            ShowWindow(gWindow, SW_SHOWNOACTIVATE);
            SetTimer(gWindow, kTick, 1000, nullptr);
            MSG message{};
            BOOL fetched;
            while ((fetched = GetMessageW(&message, nullptr, 0, 0)) > 0) {
                if (!gSettings || !IsDialogMessageW(gSettings, &message)) {
                    TranslateMessage(&message);
                    DispatchMessageW(&message);
                }
            }
            result = fetched == -1 ? 1 : static_cast<int>(message.wParam);
        }
    }
    Gdiplus::GdiplusShutdown(token);
    CloseHandle(mutex);
    return result;
}
