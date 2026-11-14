// CSS metadata: one 1024-byte record per node. id*, classes*, inline*, tag*;
// 28 computed values at +32; priorities at +256; owned attributes at +512.
// Rule: selector*, length, declaration mask, important mask, 28 values (256 bytes).
.set CSS_META_SIZE, 1024
.set CSS_RULE_SIZE, 256
.set CSS_PROPERTIES, 28
.set CSS_MAX_SOURCE, 1048576
.set CSS_MAX_RULES, 4096
.set CSS_COLOR, 0
.set CSS_BACKGROUND, 1
.set CSS_SIZE, 2
.set CSS_WEIGHT, 3
.set CSS_ITALIC, 4
.set CSS_UNDERLINE, 5
.set CSS_ALIGN, 6
.set CSS_DISPLAY, 7               // 0 normal/block fallback, 1 none, 2 inline flow
.set CSS_TOP, 8
.set CSS_BOTTOM, 9
.set CSS_LINE, 10
.set CSS_FAMILY, 11
.set CSS_LEFT, 12
.set CSS_RIGHT, 13
// Scalar sentinels. Numeric length tokens have bit 63 set, unit in bits 32..35,
// and a positive fixed-point (1/1000) magnitude in bits 0..31.
.set CSS_INHERIT, -2
.set CSS_INITIAL, -3
.set CSS_UNSET, -4

.set CSS_WIDTH, 14
.set CSS_HEIGHT, 15
.set CSS_PAD_TOP, 16
.set CSS_PAD_RIGHT, 17
.set CSS_PAD_BOTTOM, 18
.set CSS_PAD_LEFT, 19
.set CSS_BORDER, 20
.set CSS_BORDER_COLOR, 21
// Owned decoded HTML attributes. These are independent of computed CSS.
.set ATTR_SRC, 512
.set ATTR_ACTION, 520
.set ATTR_NAME, 528
.set ATTR_VALUE, 536
.set ATTR_TYPE, 544
.set ATTR_ALT, 552
.set ATTR_WIDTH, 560
.set ATTR_HEIGHT, 568
.set ATTR_METHOD, 576
.set ATTR_REL, 584
.set ATTR_DISABLED, 592
.set ATTR_MEDIA, 600
.set ATTR_LABEL, 608

.set CSS_MAX_WIDTH, 22
.set CSS_BOX_SIZING, 23
.set ATTR_CHECKED, 616
.set ATTR_SELECTED, 624
.set ATTR_MULTIPLE, 632
.set ATTR_ROWS, 640
.set ATTR_COLS, 648
.set ATTR_READONLY, 656
.set ATTR_PLACEHOLDER, 664
.set ATTR_ENCTYPE, 672
// Scratch box metrics +768: content width,L/R/T/B margins,L/R/T/B padding,border.
.set ATTR_CSS_DATA, 680

// Metadata scratch: +696 HTML hidden flag, +856 root viewport, +864 visited link.

.set CSS_RADIUS, 24
.set CSS_MIN_HEIGHT, 25
.set CSS_VERTICAL_ALIGN, 26
.set CSS_MIN_WIDTH, 27
