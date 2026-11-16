#!/usr/bin/env python3
"""Download exactly the images listed in a frozen benchmark manifest."""

import hashlib
import json
import sys
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
destination = Path(sys.argv[2])


def fetch(item):
    output = destination / item["image"]
    if not output.exists():
        output.parent.mkdir(parents=True, exist_ok=True)
        temporary = output.with_suffix(".partial")
        subprocess.run(["curl", "-fsSL", "--max-time", "30", "--retry", "2",
                        item["sourceURL"], "-o", str(temporary)], check=True)
        temporary.replace(output)
    return item["image"], hashlib.sha256(output.read_bytes()).hexdigest()


with ThreadPoolExecutor(max_workers=4) as pool:
    hashes = dict(pool.map(fetch, manifest))
print(json.dumps(hashes, indent=2, sort_keys=True))
