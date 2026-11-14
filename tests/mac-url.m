// Foundation assertions exercise handwritten ARM64 address logic, not a compiler-generated replacement.
#import <Foundation/Foundation.h>
#include <assert.h>
extern void mac_init_selectors(void);
extern NSURL *mac_destination(NSString *);
extern BOOL mac_allowed_scheme(NSString *);
int main(void) {
    @autoreleasepool {
        mac_init_selectors();
        NSDictionary *cases = @{
            @"example.com": @"https://example.com",
            @"localhost:8765": @"http://localhost:8765",
            @"127.0.0.1:8765/a": @"http://127.0.0.1:8765/a",
            @"[::1]:8765/a": @"http://[::1]:8765/a",
            @"  https://example.com/a\n": @"https://example.com/a",
            @"hello world": @"https://duckduckgo.com/?q=hello%20world",
            @"a&b": @"https://duckduckgo.com/?q=a%26b",
            @"café 🌐": @"https://duckduckgo.com/?q=caf%C3%A9%20%F0%9F%8C%90",
            @"HTTPS://example.com": @"HTTPS://example.com"
        };
        for (NSString *input in cases) {
            NSString *actual = mac_destination(input).absoluteString;
            if (![actual isEqual:cases[input]]) {
                NSLog(@"Address %@ returned %@, expected %@", input, actual, cases[input]);
                abort();
            }
        }
        for (NSString *input in @[@"", @" \n\t", @"file:///etc/passwd", @"javascript://alert(1)", @"https://", @"https:///path"]) assert(mac_destination(input) == nil);
        assert(mac_allowed_scheme(@"HTTP") && mac_allowed_scheme(@"https"));
        assert(!mac_allowed_scheme(@"file") && !mac_allowed_scheme(@"about") && !mac_allowed_scheme(nil));
        puts("PASS: ARM64 URL normalization, Unicode search encoding, local addresses, invalid hosts, and scheme policy");
    }
    return 0;
}
