#!/usr/bin/env python3
"""Build the local object vocabulary from LVIS, Open Images and common objects."""

import ast
import csv
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
module = ast.parse((root / ".validation/lvis-categories.py").read_text())
categories = next(ast.literal_eval(node.value) for node in module.body
                  if isinstance(node, ast.Assign)
                  and any(isinstance(target, ast.Name) and target.id == "LVIS_CATEGORIES" for target in node.targets))

aliases = {
    "monitor_(computer_equipment) computer_monitor": "monitor",
    "computer monitor": "monitor", "computer mouse": "computer mouse",
    "mouse_(computer_equipment)": "computer mouse", "router_(computer_equipment)": "wi-fi router",
    "speaker_(stero_equipment)": "loudspeaker", "iron_(for_clothing)": "clothes iron",
    "bow_(weapon)": "bow and arrow", "bow_(decorative_ribbons)": "ribbon bow",
    "runner_(carpet)": "runner rug", "glass_(drink_container)": "drinking glass",
    "mat_(gym_equipment)": "exercise mat", "pan_(metal_container)": "metal tray",
    "poker_(fire_stirring_tool)": "fireplace poker", "pop_(soda)": "soft drink",
    "mixer_(kitchen_tool)": "stand mixer", "file_(tool)": "metal file",
    "cap_(headwear)": "cap", "arctic_(type_of_shoe)": "rubber boot",
    "knocker_(on_a_door)": "door knocker", "clippers_(for_plants)": "garden shears",
    "football_(American)": "american football", "triangle_(musical_instrument)": "musical triangle",
    "human face": "face", "human head": "head", "human hand": "hand",
    "human foot": "foot", "human arm": "arm", "human leg": "leg",
    "kitchen & dining room table": "dining table", "power plugs and sockets": "power socket",
    "mobile phone": "mobile phone", "cell phone": "mobile phone", "hotdog": "hot dog",
    "sofa": "sofa", "rug": "rug", "carpet": "rug",
}

generic = {
    "animal", "mammal", "reptile", "invertebrate", "carnivore", "marine mammal",
    "clothing", "fashion accessory", "food", "plant", "fruit", "vegetable", "seafood",
    "furniture", "vehicle", "land vehicle", "watercraft", "aircraft", "sports equipment",
    "musical instrument", "office supplies", "kitchen appliance", "home appliance",
    "kitchenware", "medical equipment", "toy", "drink", "baked goods", "dairy product",
    "tool", "weapon", "building", "building material", "personal care", "electronic device",
    "fast food", "auto part", "packaged goods", "mode of transport", "person",
}


def normalize(value):
    if value in aliases:
        return aliases[value]
    value = re.sub(r"_\([^)]*\)", "", value).replace("_", " ").strip().lower()
    return aliases.get(value, value)


names = {normalize(category["name"]) for category in categories}
with (root / ".validation/openimages-labels.csv").open() as source:
    names.update(normalize(row[1]) for row in csv.reader(source))

names.update("""headphones|earbuds|wireless earbuds|earbud case|headset|door|sock|rug|monitor|
computer keyboard|mouse pad|usb cable|usb-c cable|charging cable|phone charger|power adapter|
power bank|extension cord|power strip|wall socket|light switch|smartwatch|tablet|
game controller|webcam|microphone|laptop stand|desk lamp|desk|whiteboard marker|
ballpoint pen|mechanical pencil|pencil case|notebook|sticky notes|paper clip|
key|keyring|door lock|door handle|bottle cap|bottle opener|can opener|tea bag|
coffee capsule|dish sponge|soap dispenser|toothpaste|shampoo bottle|hairbrush|
laundry basket|vacuum cleaner|robot vacuum|electric kettle|frying pan|saucepan|
cutting board|water filter jug|food container|storage box|shopping bag|
shoe box|tissue box|toilet paper roll|paper towel roll|duvet|pillowcase|
curtain rod|blinds|shower curtain|bath mat|doormat|slippers|sneakers|
remote control|dining table|television|potted plant|teddy bear|wine glass|cup|
refrigerator|oven|sink|bowl|fork|spoon|carrot|pizza|banana|broccoli|bottle""".replace("\n", "").split("|"))
names = sorted(name.strip() for name in names if name.strip() and name not in generic)
assert len(names) == len(set(names))
assert all(name in names for name in ["headphones", "door", "sock", "rug", "monitor"])
output = root / "LingoLens/Models/SubjectNames.json"
output.write_text(json.dumps(names, ensure_ascii=False, indent=2) + "\n")
print(f"Frozen {len(names)} object names in {output}")
