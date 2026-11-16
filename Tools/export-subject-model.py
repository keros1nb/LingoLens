#!/usr/bin/env python3
"""Export the official CLIP ViT-B/16 image encoder and local text embeddings.

Development tool only. The iOS app uses Core ML and bundled binary resources.
Run with the environment described in requirements-model.txt after preparing
SubjectNames.json, .validation/clip-core and .validation/ViT-B-16.pt.
"""

import hashlib
import json
import sys
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from PIL import Image

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".validation/clip-core"))
import clip

torch.set_num_threads(4)
torch.backends.mha.set_fastpath_enabled(False)
checkpoint = root / ".validation/ViT-B-16.pt"
assert hashlib.sha256(checkpoint.read_bytes()).hexdigest() == "5806e77cd80f8b59890b7e101eabd078d9fb84e6937f9e85e4ecb61988df416f"
output = root / "LingoLens/Models"
names = json.loads((output / "SubjectNames.json").read_text())
model, _ = clip.load(str(checkpoint), device="cpu", jit=False)
model = model.float().eval()

templates = ["a photo of {}.", "a close-up photo of {}.", "a photo of a {}.", "a photo of the {}."]
backgrounds = ["a completely black image", "a completely white image", "a blank image",
               "a severely blurred photograph", "random visual noise", "a photograph with no visible object"]
prompts = [template.format(name) for name in names for template in templates] + backgrounds
device = "mps" if torch.backends.mps.is_available() else "cpu"
print(f"Encoding {len(names)} object names on {device}", flush=True)
model = model.to(device)
features = []
with torch.no_grad():
    for start in range(0, len(prompts), 64):
        tokens = clip.tokenize(prompts[start:start + 64]).to(device)
        values = model.encode_text(tokens).float()
        values /= values.norm(dim=-1, keepdim=True)
        features.append(values.cpu().numpy())
        if start % 640 == 0:
            print(f"Text prompts: {start}/{len(prompts)}", flush=True)
features = np.concatenate(features)
objects = features[:-len(backgrounds)].reshape(len(names), len(templates), 512).mean(axis=1)
objects /= np.linalg.norm(objects, axis=1, keepdims=True)
vectors = np.concatenate([objects, features[-len(backgrounds):]]).astype("<f4")
(output / "SubjectEmbeddings.bin").write_bytes(vectors.tobytes())
model = model.cpu()


class ImageEncoder(torch.nn.Module):
    def __init__(self, visual):
        super().__init__()
        self.visual = visual
        self.register_buffer("mean", torch.tensor([0.48145466, 0.4578275, 0.40821073]).reshape(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor([0.26862954, 0.26130258, 0.27577711]).reshape(1, 3, 1, 1))

    def forward(self, image):
        embedding = self.visual((image - self.mean) / self.std)
        return embedding / embedding.norm(dim=-1, keepdim=True)


encoder = ImageEncoder(model.visual).eval()
example = torch.full((1, 3, 224, 224), 128 / 255)
print("Tracing the image encoder", flush=True)
with torch.no_grad():
    traced = torch.jit.trace(encoder, example, check_trace=False)
converted = ct.convert(traced, convert_to="mlprogram", minimum_deployment_target=ct.target.iOS18,
                       compute_precision=ct.precision.FLOAT16,
                       inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224), scale=1 / 255,
                                            color_layout=ct.colorlayout.RGB)],
                       outputs=[ct.TensorType(name="embedding", dtype=np.float32)])
print("Quantizing weights to int8", flush=True)
configuration = ct.optimize.coreml.OptimizationConfig(global_config=ct.optimize.coreml.OpLinearQuantizerConfig(
    mode="linear_symmetric", dtype="int8", granularity="per_channel"))
converted = ct.optimize.coreml.linear_quantize_weights(converted, config=configuration)
converted.author = "OpenAI"
converted.license = (root / ".validation/clip-core/LICENSE").read_text()
converted.short_description = "CLIP ViT-B/16 image embeddings for private, on-device object recognition."
converted.user_defined_metadata["source_checkpoint_sha256"] = "5806e77cd80f8b59890b7e101eabd078d9fb84e6937f9e85e4ecb61988df416f"
converted.user_defined_metadata["object_names"] = str(len(names))
destination = output / "SubjectImageEncoder.mlpackage"
converted.save(str(destination))

# Check numerical agreement of the exported model and its original encoder.
image = Image.new("RGB", (224, 224), (128, 128, 128))
with torch.no_grad():
    original = encoder(example).numpy().reshape(-1)
actual = converted.predict({"image": image})["embedding"].reshape(-1)
cosine = float(np.dot(original, actual) / (np.linalg.norm(original) * np.linalg.norm(actual)))
assert cosine > 0.99, f"Core ML conversion drift: cosine={cosine}"
report = {"model": "OpenAI CLIP ViT-B/16", "objectCount": len(names), "embeddingDimension": 512,
          "backgroundCount": len(backgrounds), "conversionCosine": cosine,
          "checkpointSHA256": hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
          "namesSHA256": hashlib.sha256((output / "SubjectNames.json").read_bytes()).hexdigest(),
          "embeddingsSHA256": hashlib.sha256((output / "SubjectEmbeddings.bin").read_bytes()).hexdigest(),
          "templates": templates, "backgrounds": backgrounds}
(root / "docs/validation/subject-model-export.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Saved {destination}; conversion cosine {cosine:.6f}", flush=True)
