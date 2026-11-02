#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p .validation

if [[ ! -f .validation/coco128.zip ]]; then
    curl -fL --max-time 120 \
        https://github.com/ultralytics/assets/releases/download/v0.0.0/coco128.zip \
        -o .validation/coco128.zip
fi
archive_sha="$(shasum -a 256 .validation/coco128.zip | cut -d ' ' -f 1)"
if [[ "$archive_sha" != "61e5e3028863d8ffc3b81d6a514603954889f0edd5e4b44c4ce60b2da99aeb8e" ]]; then
    echo "COCO128 archive differs from the frozen benchmark dataset." >&2
    exit 2
fi
if [[ ! -d .validation/coco128 ]]; then
    unzip -q .validation/coco128.zip -d .validation
fi

swiftc -swift-version 6 -module-cache-path .validation/ModuleCache \
    LingoLens/Recognition/RecognitionCandidate.swift \
    LingoLens/Recognition/RecognitionService.swift \
    Tools/VisionBenchmark.swift -o .validation/vision-benchmark

# Exit 1 means the measured accuracy is below the agreed quality gate.
.validation/vision-benchmark docs/validation/recognition-manifest.json \
    .validation/coco128 .validation/recognition-results.json
