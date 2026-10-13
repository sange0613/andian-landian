#import <AppKit/AppKit.h>
#include <cmath>
#include <ctime>
#include <string>
#include "../native-win/NativeLogic.h"

using dimblue::Status;
typedef std::uint64_t (*DBClock)(void);
static const CGFloat DBDotSize = 78;
static const CGFloat DBMenuWidth = 144;
static const CGFloat DBMenuPadding = 6;
static const CGFloat DBMenuRowHeight = 22;
static const CGFloat DBMenuSeparatorHeight = 6;

static std::uint64_t DBNow(void) {
    return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1000000ULL;
}

static NSString *DBStatus(Status status) {
    switch (status) {
        case Status::Running: return @"计时中";
        case Status::Paused: return @"已暂停";
        case Status::Finished: return @"已结束";
        default: return @"未开始";
    }
}

static NSImage *DBStatusImage(Status status) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(14, 14)];
    BOOL running = status == Status::Running;
    CGFloat size = running ? 8 : 10;
    [image lockFocus];
    [[NSColor colorWithSRGBRed:0 green:47.0 / 255 blue:167.0 / 255 alpha:running ? 0.6 : 1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect((14 - size) / 2, (14 - size) / 2, size, size)] fill];
    [image unlockFocus];
    [image setTemplate:NO];
    return image;
}

static NSRect DBClamp(NSRect frame) {
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    NSScreen *chosen = NSScreen.mainScreen;
    double nearest = HUGE_VAL;
    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(center, screen.visibleFrame)) { chosen = screen; break; }
        double distance = hypot(center.x - NSMidX(screen.visibleFrame), center.y - NSMidY(screen.visibleFrame));
        if (distance < nearest) { nearest = distance; chosen = screen; }
    }
    if (!chosen) return frame;
    NSRect visible = chosen.visibleFrame;
    frame.origin.x = fmax(NSMinX(visible), fmin(frame.origin.x, NSMaxX(visible) - frame.size.width));
    frame.origin.y = fmax(NSMinY(visible), fmin(frame.origin.y, NSMaxY(visible) - frame.size.height));
    return frame;
}

@class DBController;
@interface DBSettingsBackground : NSView
@end
@implementation DBSettingsBackground
- (void)drawRect:(NSRect)rect { [NSColor.windowBackgroundColor setFill]; NSRectFill(self.bounds); }
@end

@interface DBMenuButton : NSButton
@end
@implementation DBMenuButton
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
@end

@interface DBDotView : NSView {
    dimblue::Pointer pointer;
    NSPoint dragOrigin;
}
@property(nonatomic, weak) DBController *controller;
@end

@interface DBPanel : NSPanel
@end
@implementation DBPanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface DBController : NSObject <NSWindowDelegate, NSTextFieldDelegate, NSPopoverDelegate> {
@public
    dimblue::Timer timer;
    DBPanel *dotPanel;
    DBDotView *dotView;
    NSWindow *settingsWindow;
    NSStatusItem *statusItem;
    NSMenu *statusMenu;
    NSPopover *statusPopover;
    id localMenuMonitor, globalMenuMonitor;
    NSTextField *statusLabel, *customField, *errorLabel, *authorLabel;
    NSSegmentedControl *presets;
    NSButton *toggleButton;
    NSUserDefaults *preferences;
    DBClock clock;
    NSTimer *tickTimer, *alarmTimer;
    std::uint64_t alarmStart;
    unsigned lastMinute;
    Status lastStatus;
    int lastClicks;
    BOOL alarmRestoresHidden;
}
- (instancetype)initWithPreferences:(NSUserDefaults *)defaults clock:(DBClock)source startTimers:(BOOL)start;
- (void)refresh:(BOOL)force;
- (void)tick:(id)sender;
- (void)toggle:(id)sender;
- (void)selectMinutes:(int)minutes;
- (void)dismiss;
- (void)setDotVisible:(BOOL)visible;
- (void)showSettings:(id)sender;
- (void)applyCustom:(id)sender;
- (void)savePreferences;
- (void)shutdown;
- (NSMenu *)contextMenu;
- (NSMenu *)statusContextMenu;
- (void)handleStatusEvent:(NSEvent *)event;
- (void)openStatusMenu;
- (void)closeStatusMenu;
- (CGFloat)diameter;
@end

@implementation DBDotView
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (NSView *)hitTest:(NSPoint)point {
    NSPoint local = [self convertPoint:point fromView:self.superview];
    CGFloat radius = [self.controller diameter] / 2;
    if (hypot(local.x - NSMidX(self.bounds), local.y - NSMidY(self.bounds)) > radius) return nil;
    return [super hitTest:point];
}
- (void)drawRect:(NSRect)dirtyRect {
    DBController *owner = self.controller;
    if (!owner) return;
    CGFloat diameter = [owner diameter] - 2;
    NSRect circle = NSMakeRect((NSWidth(self.bounds) - diameter) / 2, (NSHeight(self.bounds) - diameter) / 2, diameter, diameter);
    [[NSColor colorWithSRGBRed:0 green:47.0 / 255 blue:167.0 / 255 alpha:owner->timer.status == Status::Running ? 0.36 : 1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:circle] fill];
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.alignment = NSTextAlignmentCenter;
    NSString *minutes = [NSString stringWithFormat:@"%u", (unsigned)((owner->timer.remaining(owner->clock()) + 59999) / 60000)];
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold],
                                 NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.92],
                                 NSParagraphStyleAttributeName: paragraph};
    [minutes drawInRect:NSMakeRect(0, NSMidY(self.bounds) - 12, NSWidth(self.bounds), 24) withAttributes:attributes];
    if (owner->timer.status == Status::Finished) {
        NSString *clicks = [NSString stringWithFormat:@"%d/3", owner->timer.dismissClicks];
        [clicks drawInRect:NSMakeRect(0, NSMidY(self.bounds) - 29, NSWidth(self.bounds), 16)
           withAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:11], NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.82], NSParagraphStyleAttributeName: paragraph}];
    }
}
- (void)mouseDown:(NSEvent *)event {
    NSPoint screen = [self.window convertPointToScreen:event.locationInWindow];
    pointer.down((int)screen.x, (int)screen.y, event.clickCount == 2);
    dragOrigin = self.window.frame.origin;
}
- (void)mouseDragged:(NSEvent *)event {
    NSPoint screen = [self.window convertPointToScreen:event.locationInWindow];
    if (pointer.move((int)screen.x, (int)screen.y)) {
        [self.window setFrameOrigin:NSMakePoint(dragOrigin.x + screen.x - pointer.startX, dragOrigin.y + screen.y - pointer.startY)];
    }
}
- (void)mouseUp:(NSEvent *)event {
    BOOL dragged = pointer.dragged;
    dimblue::ClickAction action = pointer.up(self.controller->timer.status == Status::Finished);
    if (dragged) {
        [self.window setFrame:DBClamp(self.window.frame) display:YES];
        [self.controller savePreferences];
    } else if (action == dimblue::ClickAction::Toggle) [self.controller toggle:nil];
    else if (action == dimblue::ClickAction::Dismiss) [self.controller dismiss];
}
- (void)rightMouseDown:(NSEvent *)event {
    [NSMenu popUpContextMenu:[self.controller contextMenu] withEvent:event forView:self];
}
@end

@implementation DBController
- (instancetype)initWithPreferences:(NSUserDefaults *)defaults clock:(DBClock)source startTimers:(BOOL)start {
    if (!(self = [super init])) return nil;
    preferences = defaults;
    clock = source ?: DBNow;
    if ([defaults objectForKey:@"minutes"]) timer.select((int)[defaults integerForKey:@"minutes"]);
    NSRect visible = NSScreen.mainScreen.visibleFrame;
    NSPoint center = NSMakePoint(NSMaxX(visible) - 90, NSMaxY(visible) - 120);
    if ([defaults objectForKey:@"centerX"] && [defaults objectForKey:@"centerY"]) {
        CGFloat x = [defaults doubleForKey:@"centerX"], y = [defaults doubleForKey:@"centerY"];
        if (isfinite(x) && isfinite(y)) center = NSMakePoint(x, y);
    }
    NSRect frame = DBClamp(NSMakeRect(center.x - DBDotSize / 2, center.y - DBDotSize / 2, DBDotSize, DBDotSize));
    dotPanel = [[DBPanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    dotPanel.title = @"暗淡蓝点";
    dotPanel.backgroundColor = NSColor.clearColor;
    dotPanel.opaque = NO;
    dotPanel.hasShadow = NO;
    dotPanel.level = NSFloatingWindowLevel;
    dotPanel.hidesOnDeactivate = NO;
    dotPanel.releasedWhenClosed = NO;
    dotPanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    dotPanel.delegate = self;
    dotView = [[DBDotView alloc] initWithFrame:NSMakeRect(0, 0, DBDotSize, DBDotSize)];
    dotView.controller = self;
    dotView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    dotPanel.contentView = dotView;
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    statusItem.button.imagePosition = NSImageLeft;
    statusItem.button.font = [NSFont systemFontOfSize:12];
    statusMenu = [self statusContextMenu];
    statusItem.button.target = self;
    statusItem.button.action = @selector(statusClicked:);
    [statusItem.button sendActionOn:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown];
    lastMinute = UINT_MAX;
    lastStatus = Status::Finished;
    lastClicks = -1;
    [self installMainMenu];
    [self refresh:YES];
    [dotPanel orderFrontRegardless];
    if (start) {
        tickTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:tickTimer forMode:NSRunLoopCommonModes];
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screenChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(tick:) name:NSWorkspaceDidWakeNotification object:nil];
    return self;
}
- (NSMenuItem *)item:(NSString *)title action:(SEL)action {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    return item;
}
- (void)installMainMenu {
    NSMenu *main = [NSMenu new];
    NSMenuItem *app = [NSMenuItem new];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"暗淡蓝点"];
    NSMenuItem *settings = [self item:@"设置" action:@selector(showSettings:)];
    settings.keyEquivalent = @",";
    [appMenu addItem:settings];
    [appMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [self item:@"退出暗淡蓝点" action:@selector(quit:)];
    quit.keyEquivalent = @"q";
    [appMenu addItem:quit];
    app.submenu = appMenu;
    [main addItem:app];
    NSMenuItem *edit = [NSMenuItem new];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"编辑"];
    NSArray *labels = @[@"撤销", @"剪切", @"复制", @"粘贴", @"全选"];
    NSArray *keys = @[@"z", @"x", @"c", @"v", @"a"];
    SEL selectors[] = {@selector(undo:), @selector(cut:), @selector(copy:), @selector(paste:), @selector(selectAll:)};
    for (NSUInteger i = 0; i < labels.count; ++i) [editMenu addItem:[[NSMenuItem alloc] initWithTitle:labels[i] action:selectors[i] keyEquivalent:keys[i]]];
    edit.submenu = editMenu;
    [main addItem:edit];
    NSApp.mainMenu = main;
}
- (NSMenu *)contextMenu {
    NSMenu *menu = [NSMenu new];
    menu.autoenablesItems = NO;
    NSMenuItem *visibility = [self item:dotPanel.visible ? @"隐藏蓝点" : @"显示蓝点" action:@selector(toggleVisibility:)];
    visibility.representedObject = @(!dotPanel.visible);
    [menu addItem:visibility];
    [menu addItem:[self item:@"设置" action:@selector(showSettings:)]];
    [menu addItem:NSMenuItem.separatorItem];
    for (NSNumber *value in @[@5, @25, @45]) {
        NSMenuItem *item = [self item:[NSString stringWithFormat:@"%@ 分钟", value] action:@selector(preset:)];
        item.representedObject = value;
        item.state = timer.minutes == value.intValue ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem:item];
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *toggle = [self item:timer.status == Status::Running ? @"暂停" : timer.status == Status::Paused ? @"继续" : @"开始" action:@selector(toggle:)];
    toggle.enabled = timer.status != Status::Finished;
    [menu addItem:toggle];
    [menu addItem:[self item:timer.status == Status::Finished ? @"取消提醒" : @"重置" action:@selector(reset:)]];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:[self item:@"退出" action:@selector(quit:)]];
    return menu;
}
- (NSMenu *)statusContextMenu {
    NSMenu *menu = [self contextMenu];
    NSMenuItem *pause = [menu itemWithTitle:@"暂停"];
    if (pause) [menu removeItem:pause];
    return menu;
}
- (void)statusClicked:(id)sender { [self handleStatusEvent:NSApp.currentEvent]; }
- (void)handleStatusEvent:(NSEvent *)event {
    if (event.type != NSEventTypeLeftMouseDown && event.type != NSEventTypeRightMouseDown) return;
    if (event.type == NSEventTypeLeftMouseDown && event.clickCount > 0 && event.clickCount % 2 == 0) {
        [self closeStatusMenu];
        [self toggle:nil];
    } else if (statusPopover.shown) [self closeStatusMenu];
    else [self openStatusMenu];
}
- (void)openStatusMenu {
    [self closeStatusMenu];
    statusMenu = [self statusContextMenu];
    CGFloat height = DBMenuPadding * 2;
    for (NSMenuItem *item in statusMenu.itemArray) height += item.separatorItem ? DBMenuSeparatorHeight : DBMenuRowHeight;
    CGFloat innerWidth = DBMenuWidth - DBMenuPadding * 2;
    NSViewController *content = [NSViewController new];
    content.view = [[DBSettingsBackground alloc] initWithFrame:NSMakeRect(0, 0, DBMenuWidth, height)];
    CGFloat y = height - DBMenuPadding;
    for (NSInteger i = 0; i < statusMenu.numberOfItems; ++i) {
        NSMenuItem *item = [statusMenu itemAtIndex:i];
        if (item.separatorItem) {
            y -= DBMenuSeparatorHeight;
            NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(DBMenuPadding, y + DBMenuSeparatorHeight / 2, innerWidth, 1)];
            line.boxType = NSBoxSeparator;
            [content.view addSubview:line];
            continue;
        }
        y -= DBMenuRowHeight;
        NSButton *button = [DBMenuButton buttonWithTitle:item.title target:self action:@selector(statusMenuChosen:)];
        button.frame = NSMakeRect(DBMenuPadding, y, innerWidth, DBMenuRowHeight);
        button.bordered = NO;
        button.alignment = NSTextAlignmentLeft;
        button.font = [NSFont menuFontOfSize:13];
        button.enabled = item.enabled;
        button.attributedTitle = [[NSAttributedString alloc] initWithString:item.title attributes:@{NSFontAttributeName: button.font, NSForegroundColorAttributeName: item.enabled ? NSColor.labelColor : NSColor.disabledControlTextColor}];
        button.tag = i;
        NSImage *mark = item.state == NSControlStateValueOn ? [NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:nil] : [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
        mark.size = NSMakeSize(12, 12);
        button.image = mark;
        button.imagePosition = NSImageLeft;
        [content.view addSubview:button];
    }
    [content.view layoutSubtreeIfNeeded];
    statusPopover = [NSPopover new];
    statusPopover.animates = NO;
    statusPopover.behavior = NSPopoverBehaviorApplicationDefined;
    statusPopover.delegate = self;
    statusPopover.contentViewController = content;
    statusPopover.contentSize = NSMakeSize(DBMenuWidth, height);
    [statusPopover showRelativeToRect:statusItem.button.bounds ofView:statusItem.button preferredEdge:NSRectEdgeMinY];
    __weak DBController *owner = self;
    localMenuMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        DBController *controller = owner;
        if (!controller) return event;
        if (event.type == NSEventTypeKeyDown && event.keyCode == 53) { [controller closeStatusMenu]; return nil; }
        if (event.type != NSEventTypeKeyDown && event.window != controller->statusItem.button.window && event.window != controller->statusPopover.contentViewController.view.window) [controller closeStatusMenu];
        return event;
    }];
    globalMenuMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^(NSEvent *event) { [owner closeStatusMenu]; }];
}
- (void)statusMenuChosen:(NSButton *)sender {
    NSMenuItem *item = [statusMenu itemAtIndex:sender.tag];
    [self closeStatusMenu];
    if (item.enabled) [NSApp sendAction:item.action to:item.target from:item];
}
- (void)stopMenuMonitors {
    if (localMenuMonitor) { [NSEvent removeMonitor:localMenuMonitor]; localMenuMonitor = nil; }
    if (globalMenuMonitor) { [NSEvent removeMonitor:globalMenuMonitor]; globalMenuMonitor = nil; }
}
- (void)closeStatusMenu {
    [self stopMenuMonitors];
    [statusPopover close];
}
- (void)popoverDidClose:(NSNotification *)notification {
    if (notification.object == statusPopover) [self stopMenuMonitors];
}
- (CGFloat)diameter {
    if (timer.status != Status::Finished) return DBDotSize;
    std::uint64_t elapsed = (clock() - alarmStart) % 2500;
    double phase = (elapsed <= 1250 ? elapsed : 2500 - elapsed) / 1250.0;
    return DBDotSize * (1 + 2 * phase * phase * (3 - 2 * phase));
}
- (void)refresh:(BOOL)force {
    unsigned minute = (unsigned)((timer.remaining(clock()) + 59999) / 60000);
    if (!force && minute == lastMinute && timer.status == lastStatus && timer.dismissClicks == lastClicks) return;
    if (force || timer.status != lastStatus) statusItem.button.image = DBStatusImage(timer.status);
    lastMinute = minute;
    lastStatus = timer.status;
    lastClicks = timer.dismissClicks;
    CGFloat size = timer.status == Status::Finished ? DBDotSize * 3 : DBDotSize;
    NSRect old = dotPanel.frame;
    if (NSWidth(old) != size) [dotPanel setFrame:DBClamp(NSMakeRect(NSMidX(old) - size / 2, NSMidY(old) - size / 2, size, size)) display:YES];
    dotView.needsDisplay = YES;
    statusItem.button.title = [NSString stringWithFormat:@"%u", minute];
    statusItem.button.toolTip = [NSString stringWithFormat:@"暗淡蓝点 · %u 分钟 · %@", minute, DBStatus(timer.status)];
    if (settingsWindow) {
        statusLabel.stringValue = [NSString stringWithFormat:@"%u 分钟 · %@", minute, DBStatus(timer.status)];
        toggleButton.title = timer.status == Status::Running ? @"暂停" : timer.status == Status::Paused ? @"继续" : @"开始";
        toggleButton.enabled = timer.status != Status::Finished;
        presets.selectedSegment = timer.minutes == 5 ? 0 : timer.minutes == 25 ? 1 : timer.minutes == 45 ? 2 : -1;
    }
}
- (void)startAlarm {
    [self closeStatusMenu];
    alarmStart = clock();
    alarmRestoresHidden = !dotPanel.visible;
#ifndef DB_MAC_SMOKE
    NSBeep();
#endif
    [self setDotVisible:YES];
}
- (void)configureAlarmTimer {
    [alarmTimer invalidate];
    alarmTimer = nil;
    if (timer.status != Status::Finished || !tickTimer) return;
    alarmTimer = [NSTimer timerWithTimeInterval:dotPanel.visible ? 1.0 / 30 : 0.6 target:self selector:@selector(animate:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:alarmTimer forMode:NSRunLoopCommonModes];
}
- (void)animate:(id)sender {
    if (timer.status != Status::Finished) return;
    if (dotPanel.visible) dotView.needsDisplay = YES;
    statusItem.button.title = ((clock() - alarmStart) / 600) % 2 ? @"" : @"0";
}
- (void)tick:(id)sender {
    if (timer.tick(clock())) [self startAlarm];
    [self refresh:NO];
}
- (void)toggle:(id)sender {
    std::uint64_t now = clock();
    if (timer.tick(now)) [self startAlarm];
    timer.toggle(now);
    [self refresh:YES];
}
- (void)selectMinutes:(int)minutes {
    if (!timer.select(minutes)) return;
    [alarmTimer invalidate];
    alarmTimer = nil;
    if (alarmRestoresHidden) {
        alarmRestoresHidden = NO;
        [self setDotVisible:NO];
    }
    if (customField) customField.stringValue = [NSString stringWithFormat:@"%d", minutes];
    errorLabel.hidden = YES;
    [self refresh:YES];
    [self savePreferences];
}
- (void)preset:(id)sender {
    int values[] = {5, 25, 45};
    [self selectMinutes:[sender isKindOfClass:NSSegmentedControl.class] ? values[presets.selectedSegment] : [[sender representedObject] intValue]];
}
- (void)reset:(id)sender { [self selectMinutes:timer.minutes]; }
- (void)dismiss {
    if (timer.dismiss()) {
        [alarmTimer invalidate]; alarmTimer = nil;
        if (alarmRestoresHidden) {
            alarmRestoresHidden = NO;
            [self setDotVisible:NO];
        }
    }
    [self refresh:YES];
}
- (void)setDotVisible:(BOOL)visible {
    if (visible) {
        [dotPanel setFrame:DBClamp(dotPanel.frame) display:YES];
        [dotPanel orderFrontRegardless];
    } else [dotPanel orderOut:nil];
    [self configureAlarmTimer];
}
- (void)toggleVisibility:(id)sender {
    alarmRestoresHidden = NO;
    [self setDotVisible:[[sender representedObject] boolValue]];
}
- (void)screenChanged:(id)sender { [dotPanel setFrame:DBClamp(dotPanel.frame) display:YES]; }
- (BOOL)windowShouldClose:(NSWindow *)window {
    if (window == dotPanel) { [self setDotVisible:NO]; return NO; }
    return YES;
}
- (void)showSettings:(id)sender {
    if (!settingsWindow) [self createSettings];
    [NSApp activateIgnoringOtherApps:YES];
    [settingsWindow makeKeyAndOrderFront:nil];
}
- (NSButton *)button:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}
- (NSStackView *)row:(NSArray<NSView *> *)views {
    NSStackView *row = [NSStackView stackViewWithViews:views];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;
    row.distribution = NSStackViewDistributionFillEqually;
    return row;
}
- (void)createSettings {
    settingsWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 300, 280) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    settingsWindow.title = @"暗淡蓝点设置";
    settingsWindow.contentView = [[DBSettingsBackground alloc] initWithFrame:NSMakeRect(0, 0, 300, 280)];
    settingsWindow.releasedWhenClosed = NO;
    settingsWindow.delegate = self;
    statusLabel = [NSTextField labelWithString:@""];
    statusLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    presets = [NSSegmentedControl segmentedControlWithLabels:@[@"5 分钟", @"25 分钟", @"45 分钟"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(preset:)];
    customField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    customField.stringValue = [NSString stringWithFormat:@"%d", timer.minutes];
    customField.alignment = NSTextAlignmentCenter;
    customField.usesSingleLineMode = YES;
    customField.delegate = self;
    NSStackView *customRow = [self row:@[[NSTextField labelWithString:@"自定义分钟"], customField, [self button:@"设置" action:@selector(applyCustom:)]]];
    errorLabel = [NSTextField wrappingLabelWithString:@"请输入 1～180 之间的整数分钟。"];
    errorLabel.font = [NSFont systemFontOfSize:11];
    errorLabel.textColor = NSColor.systemRedColor;
    errorLabel.hidden = YES;
    toggleButton = [self button:@"开始" action:@selector(toggle:)];
    NSStackView *actions = [self row:@[toggleButton, [self button:@"重置" action:@selector(reset:)], [self button:@"退出" action:@selector(quit:)]]];
    authorLabel = [NSTextField labelWithString:@"作者：戌無营造"];
    authorLabel.font = [NSFont systemFontOfSize:12];
    authorLabel.textColor = NSColor.secondaryLabelColor;
    authorLabel.alignment = NSTextAlignmentCenter;
    NSStackView *stack = [NSStackView stackViewWithViews:@[statusLabel, presets, customRow, errorLabel, actions, authorLabel]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [settingsWindow.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:settingsWindow.contentView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:settingsWindow.contentView.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:settingsWindow.contentView.topAnchor constant:20],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:settingsWindow.contentView.bottomAnchor constant:-20],
        [presets.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [customRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [actions.widthAnchor constraintEqualToAnchor:stack.widthAnchor], [authorLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor]]];
    [settingsWindow center];
    [self refresh:YES];
}
- (void)applyCustom:(id)sender {
    NSString *input = [customField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    std::wstring text;
    for (NSUInteger i = 0; i < input.length; ++i) text.push_back([input characterAtIndex:i]);
    int minutes = 0;
    if (!dimblue::parseMinutes(text.c_str(), minutes)) { errorLabel.hidden = NO; return; }
    [self selectMinutes:minutes];
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (control == customField && command == @selector(insertNewline:)) { [self applyCustom:nil]; return YES; }
    return NO;
}
- (void)savePreferences {
    [preferences setInteger:timer.minutes forKey:@"minutes"];
    [preferences setDouble:NSMidX(dotPanel.frame) forKey:@"centerX"];
    [preferences setDouble:NSMidY(dotPanel.frame) forKey:@"centerY"];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (void)shutdown {
    [self closeStatusMenu];
    [self savePreferences];
    [tickTimer invalidate]; tickTimer = nil;
    [alarmTimer invalidate]; alarmTimer = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSStatusBar.systemStatusBar removeStatusItem:statusItem];
    [dotPanel orderOut:nil];
    [settingsWindow orderOut:nil];
}
@end

@interface DBAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) DBController *controller;
@end
@implementation DBAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.controller = [[DBController alloc] initWithPreferences:NSUserDefaults.standardUserDefaults clock:DBNow startTimers:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible {
    [self.controller showSettings:nil];
    return YES;
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self.controller shutdown]; }
@end

#ifndef DB_MAC_SMOKE
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) DBAppDelegate *delegate = [DBAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
#endif
