#!/usr/bin/env python3
"""Freeze one independent COCO val2017 image per original object category."""

import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
original = json.loads((root / "docs/validation/recognition-manifest.json").read_text())
objects = {int(item["id"].split("-")[1]): item for item in original}
choices = {category: [] for category in objects}
for label in sorted(Path(sys.argv[1]).glob("*.txt")):
    for line in label.read_text().splitlines():
        category, x, y, width, height = map(float, line.split())
        category = int(category)
        if category in choices and width * height >= 0.15 and 0.15 <= x <= 0.85 and 0.15 <= y <= 0.85:
            choices[category].append((label.stem, x, y, width, height))

used = set()
samples = []
for category in sorted(objects, key=lambda key: (len(choices[key]), key)):
    item = next(item for item in choices[category] if item[0] not in used)
    image_id, x, y, width, height = item
    used.add(image_id)
    left, top = max(0, x - width * 0.62), max(0, y - height * 0.62)
    right, bottom = min(1, x + width * 0.62), min(1, y + height * 0.62)
    samples.append({
        "id": f"val2017-{category}-{image_id}",
        "image": f"val2017/{image_id}.jpg",
        "expected": objects[category]["expected"],
        "acceptedNames": objects[category]["acceptedNames"],
        "crop": [left, top, right - left, bottom - top],
        "sourceURL": f"https://s3.amazonaws.com/images.cocodataset.org/val2017/{image_id}.jpg",
    })
output = root / "docs/validation/detector-manifest.json"
output.write_text(json.dumps(sorted(samples, key=lambda item: item["id"]), indent=2) + "\n")
print(f"Frozen {len(samples)} different val2017 images: {output}")
