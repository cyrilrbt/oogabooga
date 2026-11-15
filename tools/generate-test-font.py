#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate our tiny rectangular ASCII test font using only Python's stdlib.

This intentionally artificial font verifies loading, family selection and layout;
it is not an application font. Committed output means CI needs no font tooling.
"""
import math
import pathlib
import struct

pack = struct.pack
names = {1: 'Ooga Fixture', 2: 'Regular', 4: 'Ooga Fixture Regular',
         5: 'Version 1.0', 6: 'OogaFixture-Regular'}
strings = bytearray()
records = bytearray()
for name_id, value in names.items():
    encoded = value.encode('utf-16-be')
    records += pack('>6H', 3, 1, 0x409, name_id, len(encoded), len(strings))
    strings += encoded
name = pack('>3H', 0, len(names), 6 + len(records)) + records + strings

glyf = bytearray()
loca = []
for glyph in range(96):
    loca.append(len(glyf))
    if glyph == 1:  # ASCII space
        continue
    outline = pack('>5h', 1, 40, 0, 360, 700)
    outline += pack('>2H', 3, 0) + bytes([1] * 4)
    outline += pack('>4h', 40, 320, 0, -320) + pack('>4h', 0, 0, 700, 0)
    glyf += outline
    glyf += bytes((-len(glyf)) % 4)
loca.append(len(glyf))
head = pack('>4I2H2Q4h3H2h', 0x10000, 0x10000, 0, 0x5f0f3cf5, 3,
            1000, 0, 0, 0, -200, 420, 800, 0, 8, 2, 1, 0)
hhea = pack('>I15hH', 0x10000, 800, -200, 0, 420, 40, 60, 360,
            1, 0, 0, 0, 0, 0, 0, 0, 96)
maxp = pack('>I14H', 0x10000, 96, 4, 1, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0)
hmtx = b''.join(pack('>Hh', 240 if glyph == 1 else 420,
                     0 if glyph == 1 else 40) for glyph in range(96))
cmap4 = pack('>7H', 4, 32, 0, 4, 4, 1, 0)
cmap4 += pack('>2H', 126, 0xffff) + pack('>H', 0)
cmap4 += pack('>2H', 32, 0xffff) + pack('>2h', -31, 1) + pack('>2H', 0, 0)
cmap = pack('>2H2HI', 0, 1, 3, 1, 12) + cmap4
os2 = pack('>Hh3H11h', 0, 420, 400, 5, 0, 650, 600, 0, 75,
           650, 600, 0, 350, 50, 300, 0)
os2 += bytes(10) + pack('>4I', 1, 0, 0, 0) + b'OOGA'
os2 += pack('>3H3h2H', 0x40, 32, 126, 800, -200, 0, 800, 200)
post = pack('>Ii2h5I', 0x30000, 0, -100, 50, 0, 0, 0, 0, 0)
tables = {'OS/2': os2, 'cmap': cmap, 'glyf': bytes(glyf), 'head': head,
          'hhea': hhea, 'hmtx': hmtx, 'loca': pack('>97I', *loca),
          'maxp': maxp, 'name': bytes(name), 'post': post}
assert len(head) == 54 and len(hhea) == 36 and len(maxp) == 32 and len(os2) == 78

def checksum(data):
    data += bytes((-len(data)) % 4)
    return sum(struct.unpack('>' + 'I' * (len(data) // 4), data)) & 0xffffffff

count = len(tables)
power = int(math.log2(count))
header = pack('>I4H', 0x10000, count, 16 * 2**power, power,
              16 * count - 16 * 2**power)
directory = bytearray()
body = bytearray()
offsets = {}
for tag, data in sorted(tables.items()):
    offset = len(header) + 16 * count + len(body)
    offsets[tag] = offset
    directory += pack('>4s3I', tag.encode(), checksum(data), offset, len(data))
    body += data + bytes((-len(data)) % 4)
font = bytearray(header + directory + body)
struct.pack_into('>I', font, offsets['head'] + 8,
                 (0xb1b0afba - checksum(bytes(font))) & 0xffffffff)
assert checksum(bytes(font)) == 0xb1b0afba
pathlib.Path('tests/fixtures/ooga-test.ttf').write_bytes(font)
print(f'Generated {len(font)} bytes: tests/fixtures/ooga-test.ttf')
