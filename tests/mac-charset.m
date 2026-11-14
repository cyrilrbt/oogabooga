#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
extern void mac_init_selectors(void);
extern NSData *mac_engine_decode(NSData *,NSString *) __attribute__((ns_returns_retained));
typedef struct { char *text; uint64_t length; void *nodes; uint64_t count; char *title; } Document;
extern Document *engine_parse(const char *,size_t);
extern void engine_document_free(Document *);
extern void *engine_layout(Document *,size_t);
extern void engine_layout_free(void *);
int main(int argc,const char **argv) {
    @autoreleasepool {
        mac_init_selectors();
        unsigned char bytes[]={0x63,0x61,0x66,0xe9,0x20,0x93,0x78,0x94,0x20,0x80};
        NSData *latin=[NSData dataWithBytes:bytes length:sizeof(bytes)];
        for(NSString *name in @[@"ISO-8859-1",@"windows-1252",@"US-ASCII"]) {
            NSData *decoded=mac_engine_decode(latin,name);
            NSString *text=[[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
            assert([text isEqual:@"café “x” €"]);
        }
        NSData *utf8=[@"café 🌐" dataUsingEncoding:NSUTF8StringEncoding];
        assert([mac_engine_decode(utf8,nil) isEqual:utf8]);
        assert([mac_engine_decode(utf8,@"utf-8") isEqual:utf8]);
        assert(!mac_engine_decode(latin,@"utf-8"));
        assert(!mac_engine_decode(latin,@"not-an-encoding"));
        NSData *utf16=[@"日本語" dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        NSString *japanese=[[NSString alloc] initWithData:mac_engine_decode(utf16,@"utf-16le") encoding:NSUTF8StringEncoding];
        assert([japanese isEqual:@"日本語"]);
        if(argc==3) {
            NSData *captured=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]]; assert(captured);
            NSData *normalized=mac_engine_decode(captured,[NSString stringWithUTF8String:argv[2]]); assert(normalized);
            Document *doc=engine_parse(normalized.bytes,normalized.length); assert(doc);
            void *layout=engine_layout(doc,90); assert(layout);
            printf("PASS: captured HTML decodes, parses and lays out (%s, %llu nodes)\n",doc->title,(unsigned long long)doc->count);
            engine_layout_free(layout); engine_document_free(doc);
        }
        puts("PASS: HTTP charset decoding, HTML Latin-1/ASCII aliases, UTF-8 normalization, UTF-16, and invalid encodings");
    }
    return 0;
}
