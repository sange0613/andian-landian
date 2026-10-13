#include "../NativeLogic.h"
#include <cstdio>
#include <cstdlib>

#define CHECK(expr) do { if (!(expr)) { std::fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #expr); std::exit(1); } } while (0)

int main() {
    using namespace dimblue;
    Timer timer;
    CHECK(timer.minutes == 25 && timer.remaining(0) == 1500000);
    CHECK(timer.select(5) && timer.remaining(0) == 300000);
    CHECK(timer.select(45) && timer.remaining(0) == 2700000);
    CHECK(!timer.select(0) && !timer.select(181) && timer.minutes == 45);
    timer.select(25);
    timer.toggle(1000);
    CHECK(timer.status == Status::Running && timer.remaining(61000) == 1440000);
    timer.toggle(61000);
    CHECK(timer.status == Status::Paused && timer.remaining(9999999) == 1440000);
    timer.toggle(200000);
    CHECK(timer.remaining(260000) == 1380000);
    CHECK(!timer.tick(1639999));
    CHECK(timer.tick(1640000) && timer.status == Status::Finished);
    timer.toggle(1700000);
    CHECK(timer.status == Status::Finished);
    CHECK(!timer.dismiss() && timer.dismissClicks == 1);
    CHECK(!timer.dismiss() && timer.dismissClicks == 2);
    CHECK(timer.dismiss() && timer.status == Status::Idle && timer.remaining(0) == 1500000);
    CHECK(!timer.dismiss() && timer.dismissClicks == 0);
    timer.toggle(0);
    CHECK(timer.tick(9999999)); // Sleep or a delayed message still expires the deadline.
    CHECK(timer.select(5) && timer.status == Status::Idle);
    timer.toggle(100);
    timer.reset();
    CHECK(timer.status == Status::Idle && timer.remaining(0) == 300000);

    int minutes = 0;
    CHECK(parseMinutes(L"35", minutes) && minutes == 35);
    CHECK(parseMinutes(L" 180 ", minutes) && minutes == 180);
    CHECK(!parseMinutes(L"", minutes));
    CHECK(!parseMinutes(L"0", minutes) && !parseMinutes(L"181", minutes));
    CHECK(!parseMinutes(L"3.5", minutes) && !parseMinutes(L"35x", minutes));
    CHECK(!parseMinutes(L"-5", minutes) && !parseMinutes(L"999999999999", minutes));

    Pointer pointer;
    pointer.down(10, 20, false);
    CHECK(pointer.up(false) == ClickAction::None);
    pointer.down(10, 20, true);
    CHECK(pointer.up(false) == ClickAction::Toggle);
    pointer.down(10, 20, true);
    CHECK(pointer.move(30, 20));
    CHECK(pointer.up(false) == ClickAction::None);
    pointer.down(10, 20, false);
    CHECK(!pointer.move(12, 21));
    CHECK(pointer.up(true) == ClickAction::Dismiss);
    pointer.down(10, 20, true);
    CHECK(pointer.up(true) == ClickAction::Dismiss);
    pointer.down(10, 20, false);
    CHECK(pointer.up(true) == ClickAction::Dismiss);
    pointer.down(10, 20, false);
    pointer.move(20, 20);
    CHECK(pointer.up(true) == ClickAction::None);
    pointer.down(10, 20, true);
    pointer.cancel();
    CHECK(pointer.up(false) == ClickAction::None);

    std::puts("PASS: timer deadlines, pause/resume, duration validation, three-click dismissal, and pointer gestures");
}
