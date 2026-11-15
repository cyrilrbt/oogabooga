#!/usr/bin/env python3
"""Build a self-contained local report from the native offline harness results."""
import html
import json
import pathlib
import sys

directory = pathlib.Path(sys.argv[1])
report = json.loads((directory / "results.json").read_text())
escape = html.escape
cards = []
stages = ["HTML", "CSS", "Geometry", "Measurement", "Native text", "Display list", "Paint", "Display total (inclusive)"]
for case in report["results"]:
    checks = "".join(f'<li>{"PASS" if c["pass"] else "FAIL"}: {escape(c["name"])}'
                     + (f' ({c["mismatched_pixels"]} / {c["compared_pixels"]} pixels)' if "mismatched_pixels" in c else "") + '</li>'
                     for c in case["checks"])
    timing = "".join(f'<tr><td>{label}</td><td>{value:.3f} ms</td></tr>' for label, value in zip(stages, case["stage_ms"]))
    images = f'<figure><img src="{escape(case["screenshot"], quote=True)}"><figcaption>Assembly render</figcaption></figure>'
    if case["reference"]:
        images += f'<figure><img src="{escape(case["reference"], quote=True)}"><figcaption>Independent geometry reference</figcaption></figure>'
    cards.append(f'''<article class="{"pass" if case["pass"] else "fail"}"><h2>{escape(case["name"])} — {"PASS" if case["pass"] else "FAIL"}</h2>
<p>{escape(case["file"])} · {case["width"]} × {case["height"]} capture · {case["viewport_width"]}pt layout width</p>
<p>Median {case["median_ms"]:.2f} ms/page · budget {case["budget_ms"]:.0f} ms · 2 warmups / 5 measured renders</p>
<ul>{checks}</ul><div class="images">{images}</div><details><summary>Stage timings</summary><table>{timing}</table></details></article>''')
page = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Assembly engine compatibility</title><style>
body{{font:16px/1.5 system-ui;margin:2rem;background:#f4f6f8;color:#17212b}}main{{max-width:1100px;margin:auto}}
article{{background:white;padding:1.5rem;margin:1rem 0;border-left:5px solid #15803d;border-radius:8px}}article.fail{{border-color:#b91c1c}}
.images{{display:flex;gap:1rem;flex-wrap:wrap}}figure{{margin:0}}img{{max-width:100%;border:1px solid #aaa}}figcaption{{color:#475569}}td{{padding:.2rem 1rem .2rem 0}}
</style><main><h1>Assembly engine compatibility — {"PASS" if report["pass"] else "FAIL"}</h1>
<p>Version {escape(report["version"])} · {escape(report["os"])}</p>
<p>Offline fixtures include representative static pages with text/position checks and screenshots. Geometry references use separate text-free cases to exclude font rasterization. Timings include native layout and capture, exclude network IO, and vary by hardware. Display total includes nested stages.</p>
{''.join(cards)}</main></html>'''
(directory / "index.html").write_text(page)
print(f'Report: {directory / "index.html"}')
