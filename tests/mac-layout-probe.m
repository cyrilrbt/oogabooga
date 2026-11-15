// Standalone TextKit compatibility probe; intentionally links no engine objects.
// Report native behavior before changing the renderer in response to CI failures.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <assert.h>

@interface ProbeCell : NSTextTableBlock @end
@implementation ProbeCell @end
@interface ProbeManager : NSLayoutManager @end
@implementation ProbeManager @end
@interface ProbeContainer : NSTextContainer @end
@implementation ProbeContainer @end

static BOOL probe(int nested,int cellMode,int containerMode,int managerMode) {
    NSTextView *text=[[NSTextView alloc] initWithFrame:NSMakeRect(0,0,650,500)];
    text.richText=YES;
    if(containerMode==1) {
        NSTextContainer *container=[[ProbeContainer alloc] initWithContainerSize:NSMakeSize(595,1048576)];
        [text replaceTextContainer:container];
    } else if(containerMode==2) object_setClass(text.textContainer,NSTextContainer.class);
    if(managerMode==1) [text.textContainer replaceLayoutManager:[ProbeManager new]];
    else if(managerMode==2) object_setClass(text.layoutManager,ProbeManager.class);
    text.textContainer.widthTracksTextView=NO;
    text.textContainer.containerSize=NSMakeSize(595,1048576);
    text.textContainer.lineFragmentPadding=0;
    text.layoutManager.typesetterBehavior=NSTypesetterBehavior_10_4;
    NSTextTable *table=[NSTextTable new];
    table.numberOfColumns=3;
    table.layoutAlgorithm=NSTextTableFixedLayoutAlgorithm;
    [table setContentWidth:600 type:NSTextBlockAbsoluteValueType];
    NSTextTable *outer=[NSTextTable new];
    outer.numberOfColumns=1;
    [outer setContentWidth:600 type:NSTextBlockAbsoluteValueType];
    NSTextBlock *parent=nested==2?[NSTextBlock new]:[[NSTextTableBlock alloc] initWithTable:outer startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
    [parent setContentWidth:600 type:NSTextBlockAbsoluteValueType];
    NSMutableAttributedString *string=[[NSMutableAttributedString alloc] initWithString:@"Flex left\nFlex middle\nFlex right\n"];
    NSMutableArray<NSTextTableBlock *> *cells=[NSMutableArray new];
    NSUInteger start=0;
    for(NSUInteger column=0;column<3;column++) {
        Class cellClass=cellMode==1?ProbeCell.class:NSTextTableBlock.class;
        NSTextTableBlock *cell=[[cellClass alloc] initWithTable:table startingRow:0 rowSpan:1 startingColumn:column columnSpan:1];
        if(cellMode==2) object_setClass(cell,ProbeCell.class);
        [cell setContentWidth:column==1?360:100 type:NSTextBlockAbsoluteValueType];
        [cell setValue:50 type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockMinimumHeight];
        [cell setWidth:column<2?20:0 type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockMargin edge:NSMaxXEdge];
        NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];
        style.textBlocks=nested?@[parent,cell]:@[cell];
        NSRange paragraph=[string.string paragraphRangeForRange:NSMakeRange(start,1)];
        [string addAttribute:NSParagraphStyleAttributeName value:style range:paragraph];
        start=NSMaxRange(paragraph);
        [cells addObject:cell];
    }
    [text.textStorage setAttributedString:string];
    [text.layoutManager ensureLayoutForTextContainer:text.textContainer];
    NSMutableArray *rectangles=[NSMutableArray new];
    NSRect boxes[3];
    NSUInteger index=0;
    start=0;
    for(NSTextTableBlock *cell in cells) {
        NSUInteger glyph=[text.layoutManager glyphIndexForCharacterAtIndex:start];
        NSRect rect=[text.layoutManager layoutRectForTextBlock:cell atIndex:glyph effectiveRange:NULL];
        boxes[index++]=rect;
        [rectangles addObject:NSStringFromRect(rect)];
        start=NSMaxRange([string.string paragraphRangeForRange:NSMakeRange(start,1)]);
    }
    printf("nested=%d cell=%d container=%d manager=%d: %s\n",nested,cellMode,containerMode,managerMode,[[rectangles componentsJoinedByString:@" / "] UTF8String]);
    return boxes[0].size.width>0 && boxes[0].size.width<200 &&
        fabs(boxes[0].origin.y-boxes[1].origin.y)<1 &&
        fabs(boxes[0].origin.y-boxes[2].origin.y)<1 &&
        boxes[1].origin.x>=NSMaxX(boxes[0])+19 &&
        boxes[2].origin.x>=NSMaxX(boxes[1])+19;
}

int main(int argc,const char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSTextView *native=[[NSTextView alloc] initWithFrame:NSMakeRect(0,0,600,500)];
        printf("OS: %s; AppKit %.1f; native container %s; manager %s; typesetter %s; behavior %ld\n",NSProcessInfo.processInfo.operatingSystemVersionString.UTF8String,NSAppKitVersionNumber,class_getName(object_getClass(native.textContainer)),class_getName(object_getClass(native.layoutManager)),class_getName(object_getClass(native.layoutManager.typesetter)),(long)native.layoutManager.typesetterBehavior);
        puts("Modes: 0=native, 1=initialized subclass, 2=class changed after initialization");
        puts("Nesting: 0=none, 1=artificial one-cell table, 2=ordinary CSS block");
        if(argc>1 && !strcmp(argv[1],"--matrix")) {
            for(int nested=0;nested<3;nested++)
                for(int cell=0;cell<3;cell++)
                    for(int container=0;container<3;container++)
                        for(int manager=0;manager<3;manager++)
                            @autoreleasepool { probe(nested,cell,container,manager); }
        } else {
            for(int nested=0;nested<3;nested++) {
                BOOL native=probe(nested,0,0,0);
                BOOL adapted=probe(nested,2,2,1);
                // The artificial nesting is a diagnostic control, not a
                // supported renderer representation. Ordinary CSS blocks must
                // preserve row geometry for native and renderer-style objects.
                if(nested!=1) assert(native && adapted);
            }
            puts("PASS: native table rows retain cell geometry inside ordinary CSS blocks");
        }
    }
    return 0;
}
