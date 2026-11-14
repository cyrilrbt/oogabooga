// CSS metadata: one 512-byte record per node. id*, classes*, inline*, tag*;
// 22 computed values at +32; 22 cascade priorities at +208; 13 owned attributes at +400.
// Rule: selector*, length, declaration mask, important mask, 22 values (208 bytes).
.set CSS_META_SIZE, 512
.set CSS_RULE_SIZE, 208
.set CSS_PROPERTIES, 22
.set CSS_MAX_SOURCE, 65536
.set CSS_MAX_RULES, 256
.set CSS_COLOR, 0
.set CSS_BACKGROUND, 1
.set CSS_SIZE, 2
.set CSS_WEIGHT, 3
.set CSS_ITALIC, 4
.set CSS_UNDERLINE, 5
.set CSS_ALIGN, 6
.set CSS_DISPLAY, 7
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
.set ATTR_SRC, 400
.set ATTR_ACTION, 408
.set ATTR_NAME, 416
.set ATTR_VALUE, 424
.set ATTR_TYPE, 432
.set ATTR_ALT, 440
.set ATTR_WIDTH, 448
.set ATTR_HEIGHT, 456
.set ATTR_METHOD, 464
.set ATTR_REL, 472
.set ATTR_DISABLED, 480
.set ATTR_MEDIA, 488
.set ATTR_LABEL, 496
