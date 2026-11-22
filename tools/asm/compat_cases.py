#!/usr/bin/env python3
"""Emit test-only C tables from the shared compatibility manifest."""
import json
from pathlib import Path

rows = []
checks = []
texts = []
quote = lambda value: json.dumps(value, ensure_ascii=False)
for i, case in enumerate(json.loads(Path('tests/fixtures/compatibility.json').read_text())):
    reference = case.get('reference', [])
    rects = ','.join('{' + ','.join(map(str, r['rect'] + r['rgb'])) + '}' for r in reference)
    forbidden = case.get('forbidden_colors', [])
    colors = ','.join('{' + ','.join(map(str, color)) + '}' for color in forbidden)
    rows.append('{' + ','.join([
        quote(case['name']), quote(case['file']), str(case['width']), str(case['height']),
        str(len(reference) if 'reference' in case else -1), '{' + rects + '}',
        str(len(forbidden)), '{' + colors + '}',
    ]) + '}')
    for text in case.get('text', []):
        texts.append('{' + str(i) + ',' + quote(text) + '}')
    for check in case.get('text_geometry', []):
        other = check.get('same_y_as', check.get('same_baseline_as', ''))
        checks.append('{' + ','.join([
            str(i), quote(check['text']), quote(other), str(check.get('x', -99999)),
            str(check.get('center_x', -99999)), str(check.get('right_max', -99999)),
            str(int('same_baseline_as' in check)),
        ]) + '}')
Path('build/linux/engine/compat-cases.inc').write_text(
    'static Case cases[]={' + ','.join(rows) + '};\n'
    'static Check checks[]={' + ','.join(checks) + '};\n'
    'static Text texts[]={' + ','.join(texts) + '};\n'
)
