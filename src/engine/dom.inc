// Persistent document tree, independent of flow/text/style/paint snapshots.
// Handles are document-scoped, monotonically allocated (1..4096), never reused.
// Removed handles resolve to nil. Callers must not retain raw node pointers.
// Document 64 bytes: nodes*, allocated, live, version, string bytes, root,
// reserved, reference count. Node 96 bytes: type,parent,first,last,prev,next,
// name*,value*,attributes*,height,source offset,snapshot version.
// Source offsets are scratch for matching flow snapshots, not persistent IDs.
// Attribute 32 bytes: name*,value*,next*,len. APIs are main-thread confined.
.set DOM_NODE_SIZE, 96
.set DOM_MAX_NODES, 4096
.set DOM_MAX_BYTES, 4194304
.set DOM_MAX_DEPTH, 64
.set DOM_ELEMENT, 1
.set DOM_TEXT, 2
.set DOM_COMMENT, 3
.set DOM_DOCUMENT, 4
