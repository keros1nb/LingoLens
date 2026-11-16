#!/usr/bin/env python3
"""Freeze 29 Open Images validation crops plus an independently sourced rug photo."""

import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
targets = {
    "Headphones": ("headphones", ["headphones", "headset", "earphones", "earbuds"]),
    "Door": ("door", ["door", "sliding door", "wooden door"]),
    "Sock": ("sock", ["sock", "socks"]),
    "Computer monitor": ("monitor", ["monitor", "computer monitor", "computer screen"]),
    "Pen": ("pen", ["pen", "ballpoint pen", "fountain pen"]),
    "Belt": ("belt", ["belt", "leather belt"]),
    "Pencil case": ("pencil case", ["pencil case", "pencil box"]),
    "Scarf": ("scarf", ["scarf", "shawl"]),
    "Microphone": ("microphone", ["microphone"]),
    "Lamp": ("lamp", ["lamp", "desk lamp", "table lamp", "floor lamp"]),
    "Flashlight": ("flashlight", ["flashlight", "torch"]),
    "Telephone": ("telephone", ["telephone", "phone", "landline phone"]),
    "Watch": ("watch", ["watch", "wristwatch", "smartwatch"]),
    "Calculator": ("calculator", ["calculator"]),
    "Screwdriver": ("screwdriver", ["screwdriver"]),
    "Hammer": ("hammer", ["hammer", "mallet"]),
    "Wrench": ("wrench", ["wrench", "spanner", "adjustable wrench"]),
    "Power plugs and sockets": ("power socket", ["power socket", "wall socket", "power plug", "plug", "power adapter"]),
    "Window": ("window", ["window", "window frame"]),
    "Light switch": ("light switch", ["light switch", "switch"]),
    "Jacket": ("jacket", ["jacket", "coat", "blazer"]),
    "Jeans": ("jeans", ["jeans", "blue jeans", "denim trousers"]),
    "Trousers": ("trousers", ["trousers", "pants", "jeans"]),
    "Dress": ("dress", ["dress", "gown"]),
    "Hat": ("hat", ["hat", "sun hat", "cowboy hat", "cap"]),
    "Helmet": ("helmet", ["helmet", "bicycle helmet", "football helmet", "motorcycle helmet"]),
    "Towel": ("towel", ["towel", "bath towel", "hand towel"]),
    "Pillow": ("pillow", ["pillow", "cushion"]),
    "Door handle": ("door handle", ["door handle", "doorknob"]),
}
labels = dict(csv.reader((root / ".validation/openimages-labels.csv").open()))
ids = {mid: targets[name] for mid, name in labels.items() if name in targets}
choices = {mid: [] for mid in ids}
with (root / ".validation/openimages-validation-boxes.csv").open() as source:
    for row in csv.DictReader(source):
        mid = row["LabelName"]
        if mid not in ids or row["IsGroupOf"] != "0" or row["IsDepiction"] != "0":
            continue
        left, right, top, bottom = (float(row[key]) for key in ["XMin", "XMax", "YMin", "YMax"])
        width, height = right - left, bottom - top
        x, y = (left + right) / 2, (top + bottom) / 2
        if width * height >= 0.06 and 0.15 <= x <= 0.85 and 0.15 <= y <= 0.85:
            choices[mid].append((row["ImageID"], left, right, top, bottom))

used = set()
samples = []
# Visual review before inference: these source annotations show hearing protection,
# a television, and a denim shirt rather than the requested everyday objects.
excluded_images = {"0908dd33cf950266", "007f71665b0812a7", "004dd2ac922baf98"}
for mid in sorted(ids, key=lambda item: (len(choices[item]), item)):
    available = sorted(item for item in choices[mid] if item[0] not in used and item[0] not in excluded_images)
    if not available:
        raise RuntimeError(f"No image for {ids[mid][0]} (label {mid})")
    image_id, left, right, top, bottom = available[0]
    used.add(image_id)
    width, height = right - left, bottom - top
    left, right = max(0, left - 0.12 * width), min(1, right + 0.12 * width)
    top, bottom = max(0, top - 0.12 * height), min(1, bottom + 0.12 * height)
    expected, accepted = ids[mid]
    samples.append({"id": f"openimages-{image_id}", "image": f"openimages/{image_id}.jpg",
                    "expected": expected, "acceptedNames": accepted,
                    "crop": [left, top, right - left, bottom - top],
                    "sourceURL": f"https://s3.amazonaws.com/open-images-dataset/validation/{image_id}.jpg"})

samples.append({"id": "rug-gohar", "image": "rug-gohar.jpg", "expected": "rug",
                "acceptedNames": ["rug", "carpet", "runner rug", "persian rug"], "crop": [0, 0, 1, 1],
                "sourceURL": "https://upload.wikimedia.org/wikipedia/commons/9/97/Armenian_rug_Gohar-2.jpg",
                "sourcePage": "https://commons.wikimedia.org/wiki/File:Armenian_rug_Gohar-2.jpg"})
assert len(samples) == 30
destination = root / "docs/validation/extended-manifest.json"
destination.write_text(json.dumps(samples, indent=2) + "\n")
print(f"Frozen {len(samples)} samples, including all five user-reported objects.")
