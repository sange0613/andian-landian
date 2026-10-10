#define wWinMain DimBlueDotEntryPoint
#include "../DianDian.cpp"
#undef wWinMain
#include <cstdio>
#include <cstdlib>

#define CHECK(expr) do { if (!(expr)) { std::fprintf(stderr, "FAIL line %d: %s (Win32 error %lu)\n", __LINE__, #expr, GetLastError()); std::exit(1); } } while (0)

void Click(bool secondOfDouble = false) {
    SetCursorPos(gCenter.x, gCenter.y);
    SendMessageW(gWindow, secondOfDouble ? WM_LBUTTONDBLCLK : WM_LBUTTONDOWN, MK_LBUTTON, 0);
    SendMessageW(gWindow, WM_LBUTTONUP, 0, 0);
}

int main() {
    gInstance = GetModuleHandleW(nullptr);
    Gdiplus::GdiplusStartupInput input;
    ULONG_PTR token = 0;
    CHECK(Gdiplus::GdiplusStartup(&token, &input, nullptr) == Gdiplus::Ok);
    gIcon = LoadIconW(gInstance, MAKEINTRESOURCEW(IDI_APP));
    CHECK(gIcon != nullptr);
    gTaskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
    WNDCLASSW wc{};
    wc.hInstance = gInstance;
    wc.lpfnWndProc = WindowProc;
    wc.lpszClassName = kClass;
    wc.style = CS_DBLCLKS;
    CHECK(RegisterClassW(&wc) != 0);
    gWindow = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW, kClass, kTitle,
                              WS_POPUP, 161, 161, 78, 78, nullptr, nullptr, gInstance, nullptr);
    CHECK(gWindow != nullptr);
    AddTray();
    Refresh(true);
    ShowWindow(gWindow, SW_SHOWNOACTIVATE);
    CHECK(IsWindowVisible(gWindow));
    RECT rect{};
    CHECK(GetWindowRect(gWindow, &rect) && rect.right - rect.left == 78);

    SendMessageW(gWindow, WM_COMMAND, IDC_PRESET5, 0);
    CHECK(gTimer.minutes == 5 && gTimer.status == Status::Idle);
    Click();
    CHECK(gTimer.status == Status::Idle);
    Click(true);
    CHECK(gTimer.status == Status::Running);
    gTimer.deadline = Now() + 123456;
    Click(); Click(true);
    CHECK(gTimer.status == Status::Paused && gTimer.pausedMs <= 123456 && gTimer.pausedMs > 122000);
    const auto saved = gTimer.pausedMs;
    Click(); Click(true);
    CHECK(gTimer.status == Status::Running && gTimer.remaining(Now()) <= saved && gTimer.remaining(Now()) > saved - 1000);
    SendMessageW(gWindow, WM_CLOSE, 0, 0);
    CHECK(!IsWindowVisible(gWindow) && gTimer.status == Status::Running);
    SendMessageW(gWindow, kShowMessage, 0, 0);
    CHECK(IsWindowVisible(gWindow));

    SendMessageW(gWindow, WM_COMMAND, IDM_SETTINGS, 0);
    CHECK(gSettings && IsWindowVisible(gSettings));
    SetDlgItemTextW(gSettings, IDC_CUSTOM, L"35");
    gDisplayedMinute = ~std::uint64_t{0};
    SendMessageW(gWindow, WM_TIMER, kTick, 0);
    wchar_t text[80];
    GetDlgItemTextW(gSettings, IDC_CUSTOM, text, 80);
    CHECK(wcscmp(text, L"35") == 0);
    SendMessageW(gSettings, WM_COMMAND, IDOK, 0);
    CHECK(gTimer.minutes == 35 && gTimer.status == Status::Idle);
    SetDlgItemTextW(gSettings, IDC_CUSTOM, L"3.5");
    SendMessageW(gSettings, WM_COMMAND, IDOK, 0);
    CHECK(gTimer.minutes == 35);
    GetDlgItemTextW(gSettings, IDC_ERROR, text, 80);
    CHECK(text[0] != 0);
    SendMessageW(gSettings, WM_COMMAND, IDC_PRESET45, 0);
    CHECK(gTimer.minutes == 45 && gTimer.status == Status::Idle);
    SendMessageW(gSettings, WM_COMMAND, IDC_TOGGLE, 0);
    CHECK(gTimer.status == Status::Running);
    SendMessageW(gSettings, WM_CLOSE, 0, 0);
    CHECK(!gSettings && IsWindow(gWindow) && gTimer.status == Status::Running);

    SetCursorPos(gCenter.x, gCenter.y);
    SendMessageW(gWindow, WM_LBUTTONDOWN, MK_LBUTTON, 0);
    SetCursorPos(gCenter.x + 30, gCenter.y + 15);
    SendMessageW(gWindow, WM_MOUSEMOVE, MK_LBUTTON, 0);
    SendMessageW(gWindow, WM_LBUTTONUP, 0, 0);
    CHECK(gTimer.status == Status::Running && gCenter.x == 230 && gCenter.y == 215);

    gTimer.deadline = Now();
    SendMessageW(gWindow, WM_POWERBROADCAST, PBT_APMRESUMEAUTOMATIC, 0);
    CHECK(gTimer.status == Status::Finished);
    CHECK(GetWindowRect(gWindow, &rect) && rect.right - rect.left == 234);
    Click();
    CHECK(gTimer.dismissClicks == 1);
    Click(true);
    CHECK(gTimer.dismissClicks == 2 && gTimer.status == Status::Finished);
    Click();
    CHECK(gTimer.status == Status::Idle && gTimer.dismissClicks == 0);
    CHECK(GetWindowRect(gWindow, &rect) && rect.right - rect.left == 78);
    SendMessageW(gWindow, gTaskbarCreated, 0, 0);
    CHECK(IsWindow(gWindow));
    SendMessageW(gWindow, WM_COMMAND, IDM_EXIT, 0);
    CHECK(!IsWindow(gWindow));
    Gdiplus::GdiplusShutdown(token);
    RegDeleteTreeW(HKEY_CURRENT_USER, kRegistry);
    std::puts("PASS: real Win32 window/settings messages, drag, pause/resume, hide, finish, triple-click, and quit");
}
