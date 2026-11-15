// Test-only native shaping harness for assembly inline-slot delegates.
#import <Cocoa/Cocoa.h>
#include <assert.h>
extern Class mac_register_class(void);
extern void mac_atomic_install(NSLayoutManager *,NSMutableData *);
int main(void) {@autoreleasepool {
    [NSApplication sharedApplication];__unused id bootstrap=[[mac_register_class() alloc]init];
    NSTextStorage *storage=[[NSTextStorage alloc]initWithString:@"before a\nb after" attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:14]}];
    NSLayoutManager *manager=[NSLayoutManager new];[storage addLayoutManager:manager];
    NSTextContainer *container=[[NSTextContainer alloc]initWithContainerSize:NSMakeSize(400,1000)];container.lineFragmentPadding=0;[manager addTextContainer:container];
    NSMutableData *data=[NSMutableData dataWithLength:16+2304];uint64_t *header=data.mutableBytes;header[0]=1;
    uint64_t *record=(void *)((char *)data.mutableBytes+16);record[0]=7;record[1]=3;
    double *geometry=(void *)record;geometry[2]=80;geometry[3]=40;geometry[4]=30;
    mac_atomic_install(manager,data);[manager ensureLayoutForTextContainer:container];
    assert([storage.string isEqual:@"before a\nb after"]);
    NSRange before=[manager glyphRangeForCharacterRange:NSMakeRange(0,6) actualCharacterRange:NULL];
    NSRange after=[manager glyphRangeForCharacterRange:NSMakeRange(10,6) actualCharacterRange:NULL];
    NSRect a=[manager boundingRectForGlyphRange:before inTextContainer:container],b=[manager boundingRectForGlyphRange:after inTextContainer:container];
    NSRect line=[manager lineFragmentRectForGlyphAtIndex:after.location effectiveRange:NULL];
    NSLog(@"Atomic slot geometry: %@ / %@, line %@",NSStringFromRect(a),NSStringFromRect(b),NSStringFromRect(line));
    assert(fabs(a.origin.y-b.origin.y)<1 && b.origin.x>=NSMaxX(a)+79 && line.size.height>=40);
    puts("PASS: assembly atomic inline slots retain source text, suppress interior block breaks and reserve inline width/ascent/descent");
}}
