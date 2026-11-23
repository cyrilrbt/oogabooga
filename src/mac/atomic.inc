// Each context contains only direct atomic children, sorted by local UTF-16
// start. A record owns a separate shaping context; its source text stays in the
// parent's storage for selection/copying. Copied metadata has no borrowed use.
.set AT_HEADER, 16
.set AT_STRIDE, 2304
.set AT_START, 0
.set AT_LENGTH, 8
.set AT_WIDTH, 16
.set AT_HEIGHT, 24
.set AT_BASELINE, 32
.set AT_MANAGER, 40
.set AT_CONTAINER, 48
.set AT_STORAGE, 56
.set AT_X, 64
.set AT_Y, 72
.set AT_NODE, 96
.set AT_SOURCE_BASE, 104
.set AT_META, 256

.set AT_REPLACED, 112
