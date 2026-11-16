#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p .validation

model="LingoLens/Models/SubjectImageEncoder.mlpackage"
python3 - <<'PY'
import hashlib
from pathlib import Path
files = {
    "YOLOv3Int8LUT.mlmodel": "0e32f297ad9cfc0ea8e67276867956488c7ee10dc87c057da4debc939e20b76d",
    "SubjectImageEncoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin": "e5f8bd6545e3825375e08bedb05f386bc840dc29ee740cefdebb5b2d9b1b472d",
    "SubjectImageEncoder.mlpackage/Data/com.apple.CoreML/model.mlmodel": "dbdf1143f089937590aa09c5f01974f6ed4c880086d12c5d0c88f07e8a61ab56",
    "SubjectNames.json": "3ec9e2c3f1a553a7c29cf766b5d809728b5d4becb31b0fab2edd76b66c1f9a54",
    "SubjectEmbeddings.bin": "333081df4855f7f072923d1e314031c84f07b2b8dac9acc5bd49b43fd04c6e78",
}
for name, expected in files.items():
    actual = hashlib.sha256((Path("LingoLens/Models") / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"Resource differs from the evaluated version: {name}")
PY

python3 Tools/fetch-benchmark-images.py docs/validation/detector-manifest.json \
    .validation/detector-images > .validation/detector-image-sha256.json
cmp docs/validation/detector-image-sha256.json .validation/detector-image-sha256.json
python3 Tools/fetch-benchmark-images.py docs/validation/extended-manifest.json \
    .validation/extended-images > .validation/extended-image-sha256.json
cmp docs/validation/extended-image-sha256.json .validation/extended-image-sha256.json

swiftc -swift-version 6 -module-cache-path .validation/ModuleCache \
    LingoLens/Recognition/RecognitionCandidate.swift \
    LingoLens/Recognition/ObjectDetection.swift \
    LingoLens/Recognition/SubjectVocabulary.swift \
    LingoLens/Recognition/RecognitionService.swift \
    Tools/VisionBenchmark.swift -o .validation/vision-benchmark

# Run both sets even when one misses the 24/30 target.
status=0
.validation/vision-benchmark docs/validation/detector-manifest.json \
    .validation/detector-images .validation/subject-coco-results.json "$model" || status=$?
.validation/vision-benchmark docs/validation/extended-manifest.json \
    .validation/extended-images .validation/subject-extended-results.json "$model" || status=$?
exit "$status"
