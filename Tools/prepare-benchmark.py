#!/usr/bin/env python3
"""Freeze 30 object crops from COCO128 annotations before running Vision.

Usage: python3 Tools/prepare-benchmark.py /path/to/coco128
Only the manifest is written. Images remain outside the application bundle.
"""

import json
import sys
from pathlib import Path


# COCO class IDs and acceptable object names, declared before inference.
OBJECTS = {
    39: ("bottle", ["bottle", "water bottle", "wine bottle", "beer bottle"]),
    40: ("wine glass", ["wine glass", "wineglass", "goblet"]),
    41: ("cup", ["cup", "mug", "coffee cup", "teacup", "coffee mug"]),
    42: ("fork", ["fork", "table fork"]),
    44: ("spoon", ["spoon", "tablespoon", "teaspoon"]),
    45: ("bowl", ["bowl", "soup bowl", "mixing bowl"]),
    46: ("banana", ["banana", "bananas"]),
    25: ("umbrella", ["umbrella", "parasol"]),
    50: ("broccoli", ["broccoli"]),
    51: ("carrot", ["carrot", "carrots"]),
    52: ("hot dog", ["hot dog", "hotdog"]),
    53: ("pizza", ["pizza"]),
    54: ("donut", ["donut", "doughnut", "donuts", "doughnuts"]),
    55: ("cake", ["cake", "birthday cake", "chocolate cake", "cheesecake"]),
    56: ("chair", ["chair", "armchair", "rocking chair", "folding chair"]),
    57: ("couch", ["couch", "sofa", "loveseat"]),
    58: ("potted plant", ["potted plant", "houseplant", "plant", "flowerpot", "pot plant"]),
    59: ("bed", ["bed", "bunk bed", "four poster bed"]),
    60: ("dining table", ["dining table", "dinner table", "table"]),
    61: ("toilet", ["toilet", "toilet seat", "toilet bowl"]),
    62: ("television", ["television", "tv", "television set"]),
    63: ("laptop", ["laptop", "laptop computer", "notebook computer"]),
    65: ("remote control", ["remote", "remote control"]),
    28: ("suitcase", ["suitcase", "luggage", "travel bag", "baggage"]),
    69: ("oven", ["oven", "stove", "kitchen stove", "range"]),
    71: ("sink", ["sink", "washbasin", "wash basin"]),
    72: ("refrigerator", ["refrigerator", "fridge", "icebox"]),
    74: ("clock", ["clock", "wall clock", "analog clock", "digital clock"]),
    75: ("vase", ["vase"]),
    77: ("teddy bear", ["teddy bear", "teddy", "stuffed bear", "stuffed animal"]),
}


def main():
    root = Path(sys.argv[1])
    candidates = {category: [] for category in OBJECTS}
    for label in sorted((root / "labels/train2017").glob("*.txt")):
        for line in label.read_text().splitlines():
            category, x, y, width, height = map(float, line.split())
            category = int(category)
            if category in candidates and width * height >= 0.03:
                candidates[category].append((width * height, label.stem, x, y, width, height))

    used_images = set()
    samples = []
    for category in sorted(OBJECTS, key=lambda key: (len(candidates[key]), key)):
        available = [item for item in candidates[category] if item[1] not in used_images]
        if not available:
            raise RuntimeError(f"No independent image for COCO class {category}")
        _, image_id, x, y, width, height = max(available)
        used_images.add(image_id)
        # A fixed 12% margin keeps context while centering the annotated object.
        left, top = max(0, x - width * 0.62), max(0, y - height * 0.62)
        right, bottom = min(1, x + width * 0.62), min(1, y + height * 0.62)
        expected, accepted = OBJECTS[category]
        samples.append({
            "id": f"coco-{category}-{image_id}",
            "image": f"images/train2017/{image_id}.jpg",
            "expected": expected,
            "acceptedNames": accepted,
            "crop": [left, top, right - left, bottom - top],
            "sourceURL": f"https://images.cocodataset.org/train2017/{image_id}.jpg",
        })

    output = Path(__file__).resolve().parents[1] / "docs/validation/recognition-manifest.json"
    output.write_text(json.dumps(sorted(samples, key=lambda item: item["id"]), indent=2) + "\n")
    print(f"Frozen {len(samples)} object crops from {len(used_images)} independent images: {output}")


if __name__ == "__main__":
    main()
