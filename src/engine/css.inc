// CSS metadata: one 256-byte record per node. id*, classes*, inline*, tag*;
// 14 computed values at +32; 14 cascade priorities at +144.
// Rule: selector*, length, declaration mask, important mask, 14 values (144 bytes).
.set CSS_META_SIZE, 256
.set CSS_RULE_SIZE, 144
.set CSS_PROPERTIES, 14
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
