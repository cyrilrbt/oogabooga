// Verify the native menu really routes Command shortcuts and leaves Control free.
#import <Cocoa/Cocoa.h>
#include <assert.h>
extern void mac_init_selectors(void);
extern void mac_menus(void);
extern void mac_address_configure(NSTextField *);
extern __unsafe_unretained id mac_app,mac_delegate;
@interface ShortcutTarget : NSObject
@property SEL lastAction;
@end
@implementation ShortcutTarget
- (void)focusAddress:(id)sender { (void)sender; self.lastAction=_cmd; }
- (void)reload:(id)sender { (void)sender; self.lastAction=_cmd; }
- (void)goBack:(id)sender { (void)sender; self.lastAction=_cmd; }
- (void)goForward:(id)sender { (void)sender; self.lastAction=_cmd; }
- (void)showHistory:(id)sender { (void)sender; self.lastAction=_cmd; }
- (void)toggleAssemblyEngine:(id)sender { (void)sender; self.lastAction=_cmd; }
@end
static NSEvent *key(NSString *text,NSEventModifierFlags flags) {
    if(flags & NSEventModifierFlagShift) text=text.uppercaseString;
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:0 context:nil characters:text charactersIgnoringModifiers:text isARepeat:NO keyCode:0];
}
int main(void) {
    @autoreleasepool {
        NSApplication *app=NSApplication.sharedApplication;
        ShortcutTarget *target=[ShortcutTarget new];
        mac_app=app; mac_delegate=target;
        mac_init_selectors(); mac_menus();
        NSTextField *address=[[NSTextField alloc] initWithFrame:NSMakeRect(132,738,916,30)];
        CGFloat center=NSMidY(address.frame);
        mac_address_configure(address);
        assert(address.maximumNumberOfLines==1 && address.cell.usesSingleLineMode);
        assert(address.cell.scrollable && !address.cell.wraps && address.cell.lineBreakMode==NSLineBreakByClipping);
        assert(fabs(NSMidY(address.frame)-center)<.01 && address.frame.origin.x==132 && address.frame.size.width==916);
        assert(fabs(address.frame.size.height-address.intrinsicContentSize.height)<.01);
        CGFloat height=address.frame.size.height;
        address.stringValue=[@"https://example.com/a/" stringByPaddingToLength:4096 withString:@"long-path/" startingAtIndex:0];
        assert(address.stringValue.length==4096 && address.intrinsicContentSize.height==height);
        assert([address.cell cellSizeForBounds:address.bounds].height<=height);
        NSMenu *main=app.mainMenu;
        NSDictionary *commands=@{@"l":@"focusAddress:",@"r":@"reload:",@"[":@"goBack:",@"]":@"goForward:",@"y":@"showHistory:",@"e":@"toggleAssemblyEngine:"};
        for(NSString *letter in commands) {
            target.lastAction=NULL;
            assert([main performKeyEquivalent:key(letter,NSEventModifierFlagCommand)]);
            assert(target.lastAction==NSSelectorFromString(commands[letter]));
            target.lastAction=NULL;
            assert(![main performKeyEquivalent:key(letter,NSEventModifierFlagControl)]);
            assert(!target.lastAction);
        }
        assert(![main performKeyEquivalent:key(@"l",NSEventModifierFlagCommand|NSEventModifierFlagOption)]);
        assert(![main performKeyEquivalent:key(@"l",NSEventModifierFlagCommand|NSEventModifierFlagShift)]);
        NSMenu *edit=[main itemAtIndex:1].submenu;
        NSDictionary *editKeys=@{@"Undo":@"z",@"Redo":@"z",@"Cut":@"x",@"Copy":@"c",@"Paste":@"v",@"Select All":@"a"};
        for(NSString *title in editKeys) {
            NSMenuItem *item=[edit itemWithTitle:title];
            assert(item && [item.keyEquivalent isEqual:editKeys[title]] && !item.target);
            NSEventModifierFlags expected=NSEventModifierFlagCommand;
            if([title isEqual:@"Redo"]) expected|=NSEventModifierFlagShift;
            assert(item.keyEquivalentModifierMask==expected);
        }
        NSMenuItem *quit=[[main itemAtIndex:0].submenu itemWithTitle:@"Quit Oogabooga"];
        assert([quit.keyEquivalent isEqual:@"q"] && quit.keyEquivalentModifierMask==NSEventModifierFlagCommand);
        puts("PASS: centered single-line address field, long URL clipping/scrolling, native Command menu routing, Control/extra-modifier rejection, responder-chain editing, and Shift-Command-Z redo binding");
    }
    return 0;
}
