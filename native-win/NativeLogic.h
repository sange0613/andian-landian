#pragma once
#include <cstdint>

namespace dimblue {
enum class Status { Idle, Running, Paused, Finished };

struct Timer {
    int minutes = 25;
    Status status = Status::Idle;
    int dismissClicks = 0;
    std::uint64_t pausedMs = 1500000;
    std::uint64_t deadline = 0;

    std::uint64_t remaining(std::uint64_t now) const {
        if (status == Status::Finished) return 0;
        if (status != Status::Running) return pausedMs;
        return now >= deadline ? 0 : deadline - now;
    }
    void reset() {
        status = Status::Idle;
        pausedMs = static_cast<std::uint64_t>(minutes) * 60000;
        deadline = 0;
        dismissClicks = 0;
    }
    bool select(int value) {
        if (value < 1 || value > 180) return false;
        minutes = value;
        reset();
        return true;
    }
    bool tick(std::uint64_t now) {
        if (status != Status::Running || remaining(now) != 0) return false;
        status = Status::Finished;
        pausedMs = 0;
        dismissClicks = 0;
        return true;
    }
    void toggle(std::uint64_t now) {
        if (tick(now) || status == Status::Finished) return;
        if (status == Status::Running) {
            pausedMs = remaining(now);
            status = Status::Paused;
        } else {
            deadline = now + pausedMs;
            status = Status::Running;
        }
    }
    bool dismiss() {
        if (status != Status::Finished) return false;
        if (++dismissClicks < 3) return false;
        reset();
        return true;
    }
};

inline bool parseMinutes(const wchar_t* text, int& value) {
    while (*text == L' ' || *text == L'\t') ++text;
    int number = 0;
    bool hasDigit = false;
    while (*text >= L'0' && *text <= L'9') {
        hasDigit = true;
        number = number * 10 + (*text++ - L'0');
        if (number > 180) return false;
    }
    while (*text == L' ' || *text == L'\t') ++text;
    if (!hasDigit || *text != L'\0' || number < 1) return false;
    value = number;
    return true;
}

enum class ClickAction { None, Toggle, Dismiss };

struct Pointer {
    bool pressed = false;
    bool dragged = false;
    bool doubleClick = false;
    int startX = 0, startY = 0;
    void down(int x, int y, bool isDouble) {
        pressed = true;
        dragged = false;
        doubleClick = isDouble;
        startX = x;
        startY = y;
    }
    bool move(int x, int y) {
        if (!pressed) return false;
        const int dx = x - startX, dy = y - startY;
        if (dx > 3 || dx < -3 || dy > 3 || dy < -3) dragged = true;
        return dragged;
    }
    ClickAction up(bool finished) {
        ClickAction action = ClickAction::None;
        if (pressed && !dragged) {
            if (finished) action = ClickAction::Dismiss;
            else if (doubleClick) action = ClickAction::Toggle;
        }
        cancel();
        return action;
    }
    void cancel() { pressed = false; dragged = false; doubleClick = false; }
};
} // namespace dimblue
