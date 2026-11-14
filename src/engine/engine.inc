// Experimental static HTML engine, ARM64 C ABI; no AppKit/WebKit dependencies.
// Document (80 bytes): text*, length, nodes*, node_count, title*, capacity,
// title_length, reserved[3]. A node is 40 bytes: type,parent,start,end,href*.
// Byte offsets refer to the decoded visible UTF-8 text. Parent indices form a
// bounded flow tree (root=0); nodes and href strings are owned by the document.
// Layout (32 bytes): wrapped UTF-8 text*, byte_length, UTF-16 offset map*, lines.
// map[input byte offset] translates node ranges to native attributed-text ranges.
.set ENGINE_MAX_INPUT, 1048576
.set ENGINE_MAX_NODES, 4096
.set ENGINE_MAX_DEPTH, 64
.set NODE_ROOT, 0
.set NODE_TEXT, 1
.set NODE_P, 2
.set NODE_H1, 3
.set NODE_H2, 4
.set NODE_H3, 5
.set NODE_A, 6
.set NODE_PRE, 7
.set NODE_LI, 8
.set NODE_DIV, 9
.set NODE_UL, 10
.set NODE_OL, 11
.set NODE_QUOTE, 12
.set TAG_BR, 13
.set TAG_HR, 14
.set TAG_TITLE, 15
.set TAG_SCRIPT, 16
.set TAG_STYLE, 17
