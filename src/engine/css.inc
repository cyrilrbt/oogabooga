// CSS metadata: one 2048-byte record per node. id*, classes*, inline*, tag*;
// 48 computed values at +32; priorities at +1024; owned attributes at +512.
// Rule: selector*, length, declaration mask, important mask, 48 values, raw declarations and flags (448 bytes).
.set CSS_META_SIZE, 2048
.set CSS_RULE_SIZE, 448
.set CSS_PROPERTIES, 48
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

.set CSS_DIRECTION, 28
.set CSS_JUSTIFY, 29
.set CSS_ALIGN_ITEMS, 30
.set CSS_GAP, 31
.set CSS_WRAP, 32
.set CSS_GROW, 33
.set CSS_SHRINK, 34
.set CSS_BASIS, 35
.set CSS_ROW_GAP, 36
.set CSS_COLUMN_GAP, 37
.set CSS_ALIGN_SELF, 38
.set CSS_FILL, 39
.set CSS_STROKE, 40
.set CSS_STROKE_WIDTH, 41
.set CSS_OPACITY, 42
.set CSS_FLOAT, 43
.set CSS_CLEAR, 44
.set CSS_BORDER_RIGHT, 45
.set CSS_BORDER_BOTTOM, 46
.set CSS_BORDER_LEFT, 47
// +928 variable chain, +944 inherited stop, +952 own count. Root +960/968 budgets.
// Flow scratch starts at +1424, after computed-property priorities.
.set FLOW_OWNER, 1424
.set FLOW_ROW, 1432
.set FLOW_COLUMN, 1440
.set FLOW_COLSPAN, 1448
.set FLOW_ROWSPAN, 1456
.set FLOW_WIDTH, 1464
.set FLOW_HEIGHT, 1472
.set FLOW_LEAD, 1480
.set FLOW_TRAIL, 1488
.set FLOW_COLUMNS, 1496
.set FLOW_INTRINSIC_W, 1504
.set FLOW_INTRINSIC_H, 1512
.set FLOW_BASE, 1520
.set FLOW_CROSS, 1528
.set HTML_COLSPAN, 912
.set HTML_ROWSPAN, 920

.set FLOW_BEFORE, 1576
.set FLOW_AFTER, 1584

// Per-side resolved borders and float formatting-context geometry.
.set BOX_BORDER_LEFT, 1640
.set BOX_BORDER_TOP, 1648
.set BOX_BORDER_RIGHT, 1656
.set BOX_BORDER_BOTTOM, 1664
.set FLOAT_CONTEXT, 1672
.set FLOAT_GROUP, 1680
.set FLOAT_X, 1688
.set FLOAT_Y, 1696
.set FLOAT_W, 1704
.set FLOAT_H, 1712
.set FLOAT_ACTIVE, 1720

.set FLOAT_NEXT, 1728
.set FLOAT_FIRST, 1736
.set FLOAT_LAST, 1744

.set FLOAT_NATIVE_RECORD, 1752
.set FLOAT_CONTAINER_ONLY, 1760
.set NATIVE_CONTENT_X, 1792
.set NATIVE_CONTENT_Y, 1800

.set NATIVE_DISPLAY_COMMAND, 1816

.set NATIVE_HAS_REPLACED, 1824
.set NATIVE_HAS_FLOATS, 1832
