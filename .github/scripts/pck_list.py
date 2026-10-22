"""Lists what is inside the PCK that is embedded in an exported Godot exe, and checks it.

usage: python pck_list.py RoadRacer.exe

Fails (exit 1) when the exe contains script source (.gd instead of compiled .gdc), notes (.md) or
files from the raw art packs. Prints the biggest files and the total size.
"""
import struct
import sys
from collections import Counter

data = open(sys.argv[1], "rb").read()
if data[-4:] != b"GDPC":
    sys.exit("no embedded PCK found (is embed_pck on?)")
size = struct.unpack("<Q", data[-12:-4])[0]
pck = data[len(data) - 12 - size:len(data) - 12]
if pck[:4] != b"GDPC":
    sys.exit("unexpected PCK header")
fmt = struct.unpack("<I", pck[4:8])[0]
if fmt < 3:
    sys.exit("PCK format %d is not handled by this script" % fmt)
off = struct.unpack("<Q", pck[32:40])[0]   # directory offset (format 3 and later)
count = struct.unpack("<I", pck[off:off + 4])[0]
off += 4
files = []
for _ in range(count):
    length = struct.unpack("<I", pck[off:off + 4])[0]
    off += 4
    name = pck[off:off + length].rstrip(b"\0").decode("utf-8", "replace")
    off += length
    _, file_size = struct.unpack("<QQ", pck[off:off + 16])
    off += 16 + 16 + 4   # offset + size, md5, flags
    files.append((file_size, name))

files.sort(reverse=True)
total = sum(s for s, _ in files)
print("%d files, %.2f MB" % (count, total / 1e6))
for s, n in files[:12]:
    print("  %9.1f KB  %s" % (s / 1e3, n))
by_dir = Counter()
for s, n in files:
    by_dir[n.replace("res://", "").split("/")[0]] += s
print("by folder:", {k: round(v / 1e6, 2) for k, v in by_dir.most_common(8)})

bad = [n for _, n in files if n.endswith((".gd", ".md")) or n.startswith(("tools/", "music_pack/", "vehicle_pack/", "kenney_ui", "TEst/"))]
if bad:
    print("UNWANTED FILES IN THE EXE:")
    for n in bad[:20]:
        print("  ", n)
    sys.exit(1)
print("pck contents ok")
