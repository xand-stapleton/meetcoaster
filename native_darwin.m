#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "native.h"
#import "_cgo_export.h"

static NSString *str(const char *s) { return [NSString stringWithUTF8String:s]; }
static NSStatusItem *statusItem;
static NSMenu *current;

@interface MenuDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end
@implementation MenuDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    statusItem.button.title = @"Meetcoaster";
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
- (void)performAction:(NSMenuItem *)sender {
    performMenuAction((int)sender.tag);
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
int confirm(const char *title, const char *detail, const char *button) {
    NSAlert *panel = alert(title, detail);
    [panel addButtonWithTitle:@"Cancel"];
    [panel addButtonWithTitle:str(button)];
    return [panel runModal] == NSAlertSecondButtonReturn;
}
static BOOL edit(NSAlert *panel, NSView *view, NSString *button) {
    panel.accessoryView = view;
    [panel addButtonWithTitle:button];
    [panel addButtonWithTitle:@"Cancel"];
    panel.window.initialFirstResponder = view;
    return [panel runModal] == NSAlertFirstButtonReturn;
}
char *askText(const char *title, const char *initial) {
    NSAlert *panel = alert(title, "");
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    field.stringValue = str(initial);
    return edit(panel, field, @"Continue") ? strdup(field.stringValue.UTF8String) : NULL;
}
char *askDate(const char *initial) {
    NSAlert *panel = alert("Meeting date", "");
    NSDateFormatter *format = [NSDateFormatter new];
    format.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    format.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    format.dateFormat = @"yyyy-MM-dd";
    NSDatePicker *picker = [NSDatePicker new];
    picker.datePickerStyle = NSDatePickerStyleClockAndCalendar;
    picker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
    picker.timeZone = format.timeZone;
    picker.dateValue = [format dateFromString:str(initial)];
    [picker sizeToFit];
    return edit(panel, picker, @"Set Date") ? strdup([format stringFromDate:picker.dateValue].UTF8String) : NULL;
}
int choose(const char *title, const char *detail, const char **options, int count) {
    NSAlert *panel = alert(title, detail);
    NSPopUpButton *list = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 360, 28) pullsDown:NO];
    for (int i = 0; i < count; i++) [list addItemWithTitle:str(options[i])];
    return edit(panel, list, @"Select") ? (int)list.indexOfSelectedItem : -1;
}
char *chooseFile(int saving, const char *initial) {
    [NSApp activateIgnoringOtherApps:YES];
    NSSavePanel *panel = saving ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"ics"]];
    if (saving) panel.nameFieldStringValue = str(initial);
    else panel.prompt = @"Choose";
    return [panel runModal] == NSModalResponseOK ? strdup(panel.URL.path.fileSystemRepresentation) : NULL;
}
void finishSearchOnMain(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ showResults(); });
}
