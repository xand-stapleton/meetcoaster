#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ServiceManagement/ServiceManagement.h>
#import "native.h"
#import "_cgo_export.h"

static NSString *str(const char *s) { return [NSString stringWithUTF8String:s]; }
static NSStatusItem *statusItem;
static NSMenu *current;

static void reopenMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [statusItem.button performClick:nil];
    });
}

@interface MenuDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end
@implementation MenuDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSURL *iconURL = [NSBundle.mainBundle URLForResource:@"menu-bar" withExtension:@"png"];
    NSImage *icon = iconURL ? [[NSImage alloc] initWithContentsOfURL:iconURL] : nil;
    if (icon) {
        icon.size = NSMakeSize(18 * icon.size.width / icon.size.height, 18);
        icon.template = YES;
        statusItem.button.image = icon;
    } else {
        statusItem.button.title = @"Meetcoaster";
    }
    [statusItem.button setAccessibilityLabel:@"Meetcoaster"];
    statusItem.button.toolTip = @"Meeting planner";
    statusItem.menu = [NSMenu new];
    statusItem.menu.autoenablesItems = NO;
    statusItem.menu.delegate = self;
}
- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    current = menu;
    buildMenu();
    current = nil;
}
- (void)toggleLogin:(NSMenuItem *)sender {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = SMAppService.mainAppService;
        if (service.status == SMAppServiceStatusRequiresApproval) {
            [SMAppService openSystemSettingsLoginItems];
            return;
        }
        NSError *error = nil;
        BOOL ok = service.status == SMAppServiceStatusEnabled
            ? [service unregisterAndReturnError:&error] : [service registerAndReturnError:&error];
        if (service.status == SMAppServiceStatusRequiresApproval) {
            [SMAppService openSystemSettingsLoginItems];
        } else if (!ok) {
            notice("Launch at Login", error.localizedDescription.UTF8String);
        }
    }
}
- (void)finishDateTime:(NSButton *)sender {
    [NSApp stopModalWithCode:sender.tag];
}
- (void)performAction:(NSMenuItem *)sender {
    int action = (int)sender.tag;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (performMenuAction(action)) reopenMenu();
    });
}
@end

void runApp(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) MenuDelegate *delegate = [MenuDelegate new];
        app.delegate = delegate;
        [app run];
        (void)delegate;
    }
}
void item(const char *title, int action) {
    NSMenuItem *entry = [current addItemWithTitle:str(title) action:NULL keyEquivalent:@""];
    entry.enabled = action >= 0;
    if (action >= 0) {
        entry.target = NSApp.delegate;
        entry.action = @selector(performAction:);
        entry.tag = action;
    }
}
void separator(void) { [current addItem:NSMenuItem.separatorItem]; }
void beginSubmenu(const char *title) {
    NSMenuItem *entry = [current addItemWithTitle:str(title) action:NULL keyEquivalent:@""];
    entry.submenu = [[NSMenu alloc] initWithTitle:str(title)];
    entry.submenu.autoenablesItems = NO;
    current = entry.submenu;
}
void endSubmenu(void) { current = current.supermenu; }

static NSAlert *alert(const char *title, const char *detail) {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *panel = [NSAlert new];
    panel.messageText = str(title);
    panel.informativeText = str(detail);
    return panel;
}
void notice(const char *title, const char *detail) { [alert(title, detail) runModal]; }
void loginItem(void) {
    if (@available(macOS 13.0, *)) {
        SMAppServiceStatus status = SMAppService.mainAppService.status;
        NSString *title = status == SMAppServiceStatusRequiresApproval
            ? @"Approve Launch at Login…" : @"Launch at Login";
        NSMenuItem *entry = [current addItemWithTitle:title action:@selector(toggleLogin:) keyEquivalent:@""];
        entry.target = NSApp.delegate;
        entry.state = status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    }
}
static BOOL edit(NSAlert *panel, NSView *view, NSView *focus, NSString *button) {
    panel.accessoryView = view;
    [panel addButtonWithTitle:button];
    [panel addButtonWithTitle:@"Cancel"];
    panel.window.initialFirstResponder = focus;
    return [panel runModal] == NSAlertFirstButtonReturn;
}
char *askText(const char *title, const char *initial) {
    NSAlert *panel = alert(title, "");
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    field.stringValue = str(initial);
    return edit(panel, field, field, @"Continue") ? strdup(field.stringValue.UTF8String) : NULL;
}
char *askDateTime(const char *initial, const char *source) {
    NSDateFormatter *format = [NSDateFormatter new];
    format.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    format.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    // Edit wall-clock components in a neutral zone. Go resolves DST in the source zone.
    format.dateFormat = @"yyyy-MM-dd HH:mm";
    NSDate *initialValue = [format dateFromString:str(initial)];
    NSDatePicker *calendar = [NSDatePicker new];
    calendar.datePickerStyle = NSDatePickerStyleClockAndCalendar;
    calendar.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    calendar.timeZone = format.timeZone;
    calendar.dateValue = initialValue;
    [calendar sizeToFit];

    // The graphical picker draws a fixed-size grid. Scale its coordinate system
    // so the day cells and their click targets grow together.
    NSSize grid = calendar.frame.size;
    CGFloat scale = 1.44;
    NSSize enlarged = NSMakeSize(grid.width * scale, grid.height * scale);
    NSView *calendarContainer = [[NSView alloc] initWithFrame:(NSRect){NSZeroPoint, enlarged}];
    [calendarContainer setBoundsSize:grid];
    [calendarContainer addSubview:calendar];
    [calendar setFrameOrigin:NSZeroPoint];

    NSDatePicker *timeField = [NSDatePicker new];
    timeField.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    timeField.datePickerElements = NSDatePickerElementFlagHourMinute;
    timeField.timeZone = format.timeZone;
    timeField.dateValue = initialValue;
    [timeField setAccessibilityLabel:@"Meeting time"];
    timeField.controlSize = NSControlSizeLarge;
    timeField.font = [NSFont systemFontOfSize:16];
    [timeField sizeToFit];

    NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:NSApp.delegate action:@selector(finishDateTime:)];
    cancel.keyEquivalent = @"\e";
    cancel.tag = NSModalResponseCancel;
    NSButton *apply = [NSButton buttonWithTitle:@"Set" target:NSApp.delegate action:@selector(finishDateTime:)];
    apply.keyEquivalent = @"\r";
    apply.tag = NSModalResponseOK;
    NSStackView *buttons = [NSStackView stackViewWithViews:@[cancel, apply]];
    buttons.spacing = 8;
    [buttons setFrameSize:buttons.fittingSize];

    // Size the panel from its controls, centering each row on the same axis.
    NSArray<NSView *> *rows = @[buttons, timeField, calendarContainer];
    CGFloat width = ceil(MAX(enlarged.width, MAX(timeField.frame.size.width, buttons.frame.size.width))) + 24;
    CGFloat y = 10;
    for (NSView *row in rows) {
        [row setFrameOrigin:NSMakePoint((width - row.frame.size.width) / 2, y)];
        y = NSMaxY(row.frame) + 8;
    }
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, y)
                                               styleMask:NSWindowStyleMaskTitled
                                                 backing:NSBackingStoreBuffered defer:NO];
    panel.title = [@"Set date and time · " stringByAppendingString:str(source)];
    for (NSView *row in rows) [panel.contentView addSubview:row];
    panel.defaultButtonCell = apply.cell;
    panel.initialFirstResponder = timeField;
    [panel center];
    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response = [NSApp runModalForWindow:panel];
    [panel orderOut:nil];
    if (response != NSModalResponseOK) return NULL;

    format.dateFormat = @"yyyy-MM-dd";
    NSString *date = [format stringFromDate:calendar.dateValue];
    format.dateFormat = @"HH:mm";
    NSString *value = [NSString stringWithFormat:@"%@ %@", date, [format stringFromDate:timeField.dateValue]];
    return strdup(value.UTF8String);
}
int choose(const char *title, const char *detail, const char **options, int count) {
    NSAlert *panel = alert(title, detail);
    NSPopUpButton *list = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 360, 28) pullsDown:NO];
    for (int i = 0; i < count; i++) [list addItemWithTitle:str(options[i])];
    return edit(panel, list, list, @"Select") ? (int)list.indexOfSelectedItem : -1;
}
char *saveFile(const char *initial) {
    [NSApp activateIgnoringOtherApps:YES];
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"ics"]];
    panel.nameFieldStringValue = str(initial);
    return [panel runModal] == NSModalResponseOK ? strdup(panel.URL.path.fileSystemRepresentation) : NULL;
}
void finishSearchOnMain(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [statusItem.menu cancelTracking];
        showResults();
        reopenMenu();
    });
}
