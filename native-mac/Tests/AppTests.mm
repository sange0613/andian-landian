#define DB_MAC_SMOKE 1
#include "../App.mm"
#include <cstdio>
#include <cstdlib>

static std::uint64_t testNow = 1000000;
static std::uint64_t TestClock(void) { return testNow; }
#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)

@interface DBTestController : DBController
@property(nonatomic) unsigned openedMenus;
@end
@implementation DBTestController
- (void)openStatusMenu { ++self.openedMenus; self->statusMenu = [self statusContextMenu]; }
@end

static NSEvent *Mouse(DBController *owner, NSEventType type, NSInteger count, NSPoint location) {
    return [NSEvent mouseEventWithType:type location:location modifierFlags:0 timestamp:0 windowNumber:owner->dotPanel.windowNumber context:nil eventNumber:1 clickCount:count pressure:1];
}

static void Click(DBController *owner, NSInteger count) {
    NSPoint point = NSMakePoint(NSWidth(owner->dotView.bounds) / 2, NSHeight(owner->dotView.bounds) / 2);
    [owner->dotView mouseDown:Mouse(owner, NSEventTypeLeftMouseDown, count, point)];
    [owner->dotView mouseUp:Mouse(owner, NSEventTypeLeftMouseUp, count, point)];
}

static NSMenu *StatusMenu(DBController *owner) {
    NSMenu *menu = [owner statusContextMenu];
    CHECK(menu != nil);
    return menu;
}

static void MenuAction(DBController *owner, NSString *title) {
    NSMenuItem *item = [StatusMenu(owner) itemWithTitle:title];
    CHECK(item != nil && item.enabled);
    CHECK([NSApp sendAction:item.action to:item.target from:item]);
}

static NSBitmapImageRep *StatusIcon(DBController *owner, NSString *path) {
    NSImage *image = owner->statusItem.button.image;
    CHECK(NSEqualSizes(image.size, NSMakeSize(14, 14)));
    NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
    CHECK(bitmap != nil);
    CHECK([[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES]);
    return bitmap;
}

static NSBitmapImageRep *Capture(NSView *view, NSString *path) {
    [view layoutSubtreeIfNeeded];
    [view display];
    NSBitmapImageRep *image = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    CHECK(image != nil);
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:image];
    NSData *data = [image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    CHECK([data writeToFile:path atomically:YES]);
    return image;
}

@interface DBTestDelegate : NSObject <NSApplicationDelegate>
@end
@implementation DBTestDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *output = NSProcessInfo.processInfo.arguments.lastObject;
    CHECK([NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:nil]);
    NSString *suite = [@"com.xuwu.dimblue.mac.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:suite];
    DBTestController *owner = [[DBTestController alloc] initWithPreferences:prefs clock:TestClock startTimers:NO];
    CHECK(owner->dotPanel.visible && NSWidth(owner->dotPanel.frame) == 78);
    CHECK([owner->statusItem.button.title isEqualToString:@"25"]);
    CHECK(owner->statusItem.button.target == owner && owner->statusItem.button.action != NULL && [NSStringFromSelector(owner->statusItem.button.action) isEqualToString:@"statusClicked:"]);
    CHECK([StatusMenu(owner) itemWithTitle:@"开始"] != nil);
    NSBitmapImageRep *idleIcon = StatusIcon(owner, [output stringByAppendingPathComponent:@"status-idle.png"]);
    CHECK([idleIcon colorAtX:idleIcon.pixelsWide / 2 y:idleIcon.pixelsHigh / 2].alphaComponent > 0.95);
    CHECK([idleIcon colorAtX:(NSInteger)(idleIcon.pixelsWide * 2.5 / 14) y:idleIcon.pixelsHigh / 2].alphaComponent > 0.1);
    NSBitmapImageRep *idle = Capture(owner->dotView, [output stringByAppendingPathComponent:@"dot-idle.png"]);
    NSColor *blue = [[idle colorAtX:idle.pixelsWide / 4 y:idle.pixelsHigh / 2] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    fprintf(stderr, "Idle pixel RGBA: %.4f %.4f %.4f %.4f\n", blue.redComponent, blue.greenComponent, blue.blueComponent, blue.alphaComponent);
    // View snapshots are color-managed by the current display profile.
    CHECK(blue.blueComponent > 0.6 && blue.redComponent < 0.15 && blue.alphaComponent > 0.95);

    CHECK(owner->statusItem.menu == nil);
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(owner.openedMenus == 1 && owner->timer.status == Status::Idle);
    [owner setDotVisible:NO];
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(owner->timer.status == Status::Running && !owner->dotPanel.visible);
    CHECK(owner.openedMenus == 2);
    CHECK([StatusMenu(owner) itemWithTitle:@"暂停"] == nil);
    CHECK([[owner contextMenu] itemWithTitle:@"暂停"] != nil);
    testNow += 1000;
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(owner->timer.status == Status::Paused && owner->timer.remaining(testNow) == 1499000);
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(owner->timer.status == Status::Running && !owner->dotPanel.visible && owner.openedMenus == 4);
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(owner->timer.status == Status::Running && !owner->dotPanel.visible && owner.openedMenus == 5);
    [owner selectMinutes:25];
    [owner setDotVisible:YES];

    Click(owner, 1);
    CHECK(owner->timer.status == Status::Idle);
    Click(owner, 2);
    CHECK(owner->timer.status == Status::Running);
    NSBitmapImageRep *runningIcon = StatusIcon(owner, [output stringByAppendingPathComponent:@"status-running.png"]);
    CGFloat runningAlpha = [runningIcon colorAtX:runningIcon.pixelsWide / 2 y:runningIcon.pixelsHigh / 2].alphaComponent;
    CHECK(runningAlpha > 0.5 && runningAlpha < 0.7);
    CHECK([runningIcon colorAtX:(NSInteger)(runningIcon.pixelsWide * 2.5 / 14) y:runningIcon.pixelsHigh / 2].alphaComponent < 0.1);
    CHECK(![idleIcon.TIFFRepresentation isEqual:runningIcon.TIFFRepresentation]);
    NSBitmapImageRep *running = Capture(owner->dotView, [output stringByAppendingPathComponent:@"dot-running.png"]);
    NSColor *faded = [running colorAtX:running.pixelsWide / 4 y:running.pixelsHigh / 2];
    CHECK(faded.alphaComponent > 0.3 && faded.alphaComponent < 0.42);
    testNow += 60000;
    Click(owner, 1); Click(owner, 2);
    CHECK(owner->timer.status == Status::Paused && owner->timer.remaining(testNow) == 1440000);
    NSBitmapImageRep *pausedIcon = StatusIcon(owner, [output stringByAppendingPathComponent:@"status-paused.png"]);
    CHECK([pausedIcon colorAtX:pausedIcon.pixelsWide / 2 y:pausedIcon.pixelsHigh / 2].alphaComponent > 0.95);
    testNow += 999999;
    CHECK(owner->timer.remaining(testNow) == 1440000);
    Click(owner, 1); Click(owner, 2);
    CHECK(owner->timer.status == Status::Running && owner->timer.remaining(testNow) == 1440000);

    NSPoint origin = owner->dotPanel.frame.origin;
    [owner->dotView mouseDown:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSMakePoint(39, 39))];
    [owner->dotView mouseDragged:Mouse(owner, NSEventTypeLeftMouseDragged, 1, NSMakePoint(69, 54))];
    [owner->dotView mouseUp:Mouse(owner, NSEventTypeLeftMouseUp, 1, NSMakePoint(39, 39))];
    CHECK(owner->timer.status == Status::Running);
    CHECK(fabs(owner->dotPanel.frame.origin.x - origin.x - 30) < 1);
    [owner setDotVisible:NO];
    CHECK(!owner->dotPanel.visible && owner->timer.status == Status::Running);
    CHECK([StatusMenu(owner) itemWithTitle:@"显示蓝点"] != nil);
    CHECK(!owner->dotPanel.visible && owner->timer.status == Status::Running);
    CHECK([StatusMenu(owner) itemWithTitle:@"暂停"] == nil);
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    [owner handleStatusEvent:Mouse(owner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(!owner->dotPanel.visible && owner->timer.status == Status::Paused);
    MenuAction(owner, @"继续");
    CHECK(!owner->dotPanel.visible && owner->timer.status == Status::Running);
    DBAppDelegate *reopened = [DBAppDelegate new];
    reopened.controller = owner;
    CHECK([reopened applicationShouldHandleReopen:NSApp hasVisibleWindows:NO]);
    CHECK(!owner->dotPanel.visible && owner->settingsWindow.visible);
    NSMenuItem *show = [[owner contextMenu] itemAtIndex:0];
    CHECK([show.title isEqualToString:@"显示蓝点"]);
    CHECK([NSApp sendAction:show.action to:show.target from:show]);
    CHECK(owner->dotPanel.visible);

    [owner showSettings:nil];
    CHECK(owner->settingsWindow.visible);
    CHECK([owner->authorLabel.stringValue isEqualToString:@"作者：戌無营造"]);
    owner->customField.stringValue = @"35";
    testNow += 60000;
    [owner tick:nil];
    CHECK([owner->customField.stringValue isEqualToString:@"35"]);
    [owner applyCustom:nil];
    CHECK(owner->timer.minutes == 35 && owner->timer.status == Status::Idle);
    owner->customField.stringValue = @"3.5";
    [owner applyCustom:nil];
    CHECK(owner->timer.minutes == 35 && !owner->errorLabel.hidden);
    owner->customField.stringValue = @"35";
    CHECK([owner control:owner->customField textView:[NSTextView new] doCommandBySelector:@selector(insertNewline:)]);
    CHECK(owner->errorLabel.hidden);
    [owner->settingsWindow.contentView layoutSubtreeIfNeeded];
    CHECK(owner->authorLabel.frame.origin.y >= 0);
    CHECK(NSMaxY(owner->authorLabel.frame) <= NSHeight(owner->authorLabel.superview.bounds));
    Capture(owner->settingsWindow.contentView, [output stringByAppendingPathComponent:@"settings.png"]);
    [owner toggle:nil];
    [owner->settingsWindow performClose:nil];
    CHECK(!owner->settingsWindow.visible && owner->timer.status == Status::Running);

    testNow += 2100000;
    [owner tick:nil];
    CHECK(owner->timer.status == Status::Finished && NSWidth(owner->dotPanel.frame) == 234);
    testNow += 1250;
    CHECK([owner diameter] == 234);
    Capture(owner->dotView, [output stringByAppendingPathComponent:@"dot-alert.png"]);
    Click(owner, 1); CHECK(owner->timer.dismissClicks == 1);
    Click(owner, 2); CHECK(owner->timer.dismissClicks == 2);
    Click(owner, 3); CHECK(owner->timer.status == Status::Idle);
    CHECK(NSWidth(owner->dotPanel.frame) == 78);
    [owner selectMinutes:45];
    CHECK([prefs integerForKey:@"minutes"] == 45);
    CHECK([[[owner contextMenu] itemAtIndex:0].title isEqualToString:@"隐藏蓝点"]);
    [owner setDotVisible:NO];
    CHECK([[[owner contextMenu] itemAtIndex:0].title isEqualToString:@"显示蓝点"]);
    [owner selectMinutes:1];
    [owner toggle:nil];
    testNow += 60000;
    [owner tick:nil];
    CHECK(owner->timer.status == Status::Finished && owner->dotPanel.visible);
    CHECK([owner diameter] == 78);
    testNow += 625;
    CHECK([owner diameter] > 78 && [owner diameter] < 234);
    testNow += 625;
    CHECK([owner diameter] == 234);
    CHECK([StatusMenu(owner) itemWithTitle:@"取消提醒"] != nil);
    CHECK(owner->timer.dismissClicks == 0 && owner->dotPanel.visible);
    Click(owner, 1); CHECK(owner->timer.dismissClicks == 1 && owner->dotPanel.visible);
    Click(owner, 2); CHECK(owner->timer.dismissClicks == 2 && owner->dotPanel.visible);
    Click(owner, 3); CHECK(owner->timer.status == Status::Idle && !owner->dotPanel.visible);
    [owner toggle:nil];
    testNow += 60000;
    [owner tick:nil];
    CHECK(owner->timer.status == Status::Finished && owner->dotPanel.visible);
    MenuAction(owner, @"取消提醒");
    CHECK(owner->timer.status == Status::Idle && !owner->dotPanel.visible);
    [owner shutdown];
    CHECK(owner->localMenuMonitor == nil && owner->globalMenuMonitor == nil);
    DBController *menuOwner = [[DBController alloc] initWithPreferences:prefs clock:TestClock startTimers:NO];
    [menuOwner setDotVisible:NO];
    [menuOwner toggle:nil];
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(menuOwner->statusPopover.shown && !menuOwner->statusPopover.animates);
    CHECK([menuOwner->statusMenu itemWithTitle:@"暂停"] == nil);
    NSView *menuView = menuOwner->statusPopover.contentViewController.view;
    CHECK(NSWidth(menuView.bounds) == 144 && NSHeight(menuView.bounds) <= 200);
    CHECK(menuView.subviews.count == (NSUInteger)menuOwner->statusMenu.numberOfItems);
    for (NSView *row in menuView.subviews) {
        CHECK(NSMinY(row.frame) >= 0 && NSMaxY(row.frame) <= NSHeight(menuView.bounds));
        CHECK(NSMinX(row.frame) >= 0 && NSMaxX(row.frame) <= NSWidth(menuView.bounds));
        if ([row isKindOfClass:NSButton.class]) {
            CHECK(((NSButton *)row).enabled);
            CHECK(![((NSButton *)row).title isEqualToString:@"暂停"]);
            CHECK([row acceptsFirstMouse:nil]);
        }
    }
    Capture(menuView, [output stringByAppendingPathComponent:@"status-menu.png"]);
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(menuOwner->timer.status == Status::Paused && !menuOwner->statusPopover.shown && !menuOwner->dotPanel.visible);
    CHECK(menuOwner->localMenuMonitor == nil && menuOwner->globalMenuMonitor == nil);
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(menuOwner->statusPopover.shown);
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 2, NSZeroPoint)];
    CHECK(menuOwner->timer.status == Status::Running && !menuOwner->statusPopover.shown);
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(menuOwner->statusPopover.shown);
    for (NSView *row in menuOwner->statusPopover.contentViewController.view.subviews) {
        if ([row isKindOfClass:NSButton.class] && [((NSButton *)row).title isEqualToString:@"5 分钟"]) {
            [(NSButton *)row performClick:nil];
            break;
        }
    }
    CHECK(menuOwner->timer.minutes == 5 && menuOwner->timer.status == Status::Idle);
    CHECK(!menuOwner->statusPopover.shown && menuOwner->localMenuMonitor == nil);
    [menuOwner toggle:nil];
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(menuOwner->statusPopover.shown && !menuOwner->dotPanel.visible);
    testNow += 300000;
    [menuOwner tick:nil];
    CHECK(menuOwner->timer.status == Status::Finished && menuOwner->dotPanel.visible);
    CHECK(!menuOwner->statusPopover.shown && menuOwner->localMenuMonitor == nil && menuOwner->globalMenuMonitor == nil);
    Click(menuOwner, 1); Click(menuOwner, 2); Click(menuOwner, 3);
    CHECK(menuOwner->timer.status == Status::Idle && !menuOwner->dotPanel.visible);
    NSMenuItem *staleShow = [[menuOwner contextMenu] itemAtIndex:0];
    [menuOwner setDotVisible:YES];
    CHECK([NSApp sendAction:staleShow.action to:staleShow.target from:staleShow]);
    CHECK(menuOwner->dotPanel.visible);
    NSMenuItem *staleHide = [[menuOwner contextMenu] itemAtIndex:0];
    [menuOwner setDotVisible:NO];
    CHECK([NSApp sendAction:staleHide.action to:staleHide.target from:staleHide]);
    CHECK(!menuOwner->dotPanel.visible);
    [menuOwner handleStatusEvent:Mouse(menuOwner, NSEventTypeLeftMouseDown, 1, NSZeroPoint)];
    CHECK(menuOwner->statusPopover.shown);
    [menuOwner shutdown];
    CHECK(!menuOwner->statusPopover.shown && menuOwner->localMenuMonitor == nil && menuOwner->globalMenuMonitor == nil);
    [prefs removePersistentDomainForName:suite];
    NSDictionary *report = @{@"result": @"PASS", @"author": @"戌無营造", @"language": @"zh-CN", @"checks": @[@"native rendering and alpha", @"double click and drag", @"pause/resume", @"hide and close", @"immediate complete status popup without pause", @"real popup double-click toggle and monitor cleanup", @"running status icon alpha and paused restoration", @"automatic animated reminder and restore hidden", @"custom input and Enter", @"three-click alert", @"Chinese settings and author"]};
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    CHECK([data writeToFile:[output stringByAppendingPathComponent:@"ui-test-report.json"] atomically:YES]);
    puts("PASS: native AppKit interaction, rendering, Chinese settings, author, and reminder tests");
    [NSApp terminate:nil];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) DBTestDelegate *delegate = [DBTestDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
