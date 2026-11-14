// Test-only Objective-C harness: exercise actual assembly IMPs and incoming block ABI.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#include <assert.h>
extern void mac_init_selectors(void);
extern void mac_policy(id, SEL, id, id, void (^)(WKNavigationActionPolicy));
extern void mac_authenticate(id, SEL, id, NSURLAuthenticationChallenge *, void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *));
extern void mac_js_alert(id, SEL, id, NSString *, id, void (^)(void));
extern void mac_js_confirm(id, SEL, id, NSString *, id, void (^)(BOOL));
extern void mac_js_prompt(id, SEL, id, NSString *, NSString *, id, void (^)(NSString *));
static NSModalResponse response;
static int modalCalls;
static BOOL enterCredentials;
static NSModalResponse testModal(NSAlert *alert, SEL command) {
    (void)command;
    modalCalls++;
    assert(alert.messageText.length);
    if (enterCredentials) {
        NSArray *fields = alert.accessoryView.subviews;
        assert(fields.count == 2 && [fields[1] isKindOfClass:NSSecureTextField.class]);
        [fields[0] setStringValue:@"test"];
        [fields[1] setStringValue:@"browser"];
    } else if ([alert.accessoryView isKindOfClass:NSTextField.class]) {
        assert([[(NSTextField *)alert.accessoryView stringValue] isEqual:@"default"]);
        [(NSTextField *)alert.accessoryView setStringValue:@"typed café"];
    }
    return response;
}
@interface TestAction : NSObject
@property NSURLRequest *request;
@end
@implementation TestAction
@end
@interface TestSender : NSObject <NSURLAuthenticationChallengeSender>
@end
@implementation TestSender
- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge { (void)credential; (void)challenge; }
- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge { (void)challenge; }
- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge { (void)challenge; }
@end
static NSURLAuthenticationChallenge *challenge(NSString *method, NSInteger failures) {
    NSURLProtectionSpace *space = [[NSURLProtectionSpace alloc] initWithHost:@"example.com" port:443 protocol:@"https" realm:@"test" authenticationMethod:method];
    return [[NSURLAuthenticationChallenge alloc] initWithProtectionSpace:space proposedCredential:nil previousFailureCount:failures failureResponse:nil error:nil sender:[TestSender new]];
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        mac_init_selectors();
        Method modal = class_getInstanceMethod(NSAlert.class, @selector(runModal));
        IMP original = method_setImplementation(modal, (IMP)testModal);
        __block int calls = 0;
        for (NSString *address in @[@"https://example.com", @"http://localhost", @"about:blank", @"file:///etc/passwd", @"javascript:alert(1)"]) {
            TestAction *action = [TestAction new]; action.request = [NSURLRequest requestWithURL:[NSURL URLWithString:address]];
            BOOL allowed = ![address hasPrefix:@"file:"] && ![address hasPrefix:@"javascript:"];
            mac_policy(nil, NULL, nil, action, ^(WKNavigationActionPolicy value) { assert(value == (allowed ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel)); calls++; });
        }
        assert(calls == 5);
        response = NSAlertFirstButtonReturn;
        mac_js_alert(nil,NULL,nil,@"Alert",nil,^{ calls++; });
        mac_js_confirm(nil,NULL,nil,@"Confirm",nil,^(BOOL value) { assert(value); calls++; });
        mac_js_prompt(nil,NULL,nil,@"Prompt",@"default",nil,^(NSString *value) { assert([value isEqual:@"typed café"]); calls++; });
        response = NSAlertSecondButtonReturn;
        mac_js_confirm(nil,NULL,nil,@"Confirm",nil,^(BOOL value) { assert(!value); calls++; });
        mac_js_prompt(nil,NULL,nil,@"Prompt",@"default",nil,^(NSString *value) { assert(!value); calls++; });
        assert(calls == 10 && modalCalls == 5);
        enterCredentials = YES;
        for (NSString *method in @[NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM]) {
            response = NSAlertFirstButtonReturn;
            mac_authenticate(nil,NULL,nil,challenge(method,0),^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential) {
                assert(disposition == NSURLSessionAuthChallengeUseCredential);
                assert([credential.user isEqual:@"test"] && [credential.password isEqual:@"browser"]);
                assert(credential.persistence == NSURLCredentialPersistenceForSession); calls++;
            });
        }
        response = NSAlertSecondButtonReturn;
        mac_authenticate(nil,NULL,nil,challenge(NSURLAuthenticationMethodHTTPBasic,1),^(NSURLSessionAuthChallengeDisposition d, NSURLCredential *c) { assert(d == NSURLSessionAuthChallengeCancelAuthenticationChallenge && !c); calls++; });
        int before = modalCalls;
        mac_authenticate(nil,NULL,nil,challenge(NSURLAuthenticationMethodHTTPBasic,3),^(NSURLSessionAuthChallengeDisposition d, NSURLCredential *c) { assert(d == NSURLSessionAuthChallengeCancelAuthenticationChallenge && !c); calls++; });
        mac_authenticate(nil,NULL,nil,challenge(NSURLAuthenticationMethodServerTrust,0),^(NSURLSessionAuthChallengeDisposition d, NSURLCredential *c) { assert(d == NSURLSessionAuthChallengePerformDefaultHandling && !c); calls++; });
        assert(calls == 16 && modalCalls == before);
        method_setImplementation(modal, original);
        puts("PASS: ARM64 navigation policy, alert/confirm/prompt blocks, HTTP credentials, cancellation, retry limit, and default TLS handling");
    }
    return 0;
}
