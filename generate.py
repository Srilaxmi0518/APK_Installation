import argparse
import json, os, re, subprocess
from datetime import datetime

# ---------- args ----------
parser = argparse.ArgumentParser()
parser.add_argument(
    "--force",
    action="store_true",
    help="Force generate new version for all mappings"
)
args = parser.parse_args()

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "Versions")
STATE = os.path.join(BASE, "state.json")
MAPPING = os.path.join(BASE, "Testdata.json")
os.makedirs(OUT, exist_ok=True)

# ---------- load mapping ----------
with open(MAPPING) as f:
    mapping = json.load(f)

state = {"last_mapping": {}}
if os.path.exists(STATE):
    with open(STATE) as f:
        state = json.load(f)

last = state.get("last_mapping", {})

# ---------- find template ----------
templates = []
for f in os.listdir(BASE):
    if f.endswith(".sh"):
        with open(os.path.join(BASE, f)) as fh:
            if "{{MT}}" in fh.read():
                templates.append(f)

if len(templates) != 1:
    raise RuntimeError("Exactly one template .sh with {{MT}} required")

with open(os.path.join(BASE, templates[0])) as f:
    template = f.read()

# ---------- version logic ----------
def next_version(mo):
    versions = []
    prefix = f"call_{mo}_v_"

    for f in os.listdir(OUT):
        if f.startswith(prefix) and f.endswith(".sh"):
            try:
                v = int(f[len(prefix):-3])
                versions.append(v)
            except ValueError:
                pass

    return max(versions, default=0) + 1

generated = []

# ---------- generate ----------
for mo, mt in mapping.items():

    # NORMAL MODE → skip unchanged MT
    if not args.force and last.get(mo) == mt:
        continue

    v = next_version(mo)
    filename = f"call_{mo}_v_{v}.sh"
    path = os.path.join(OUT, filename)

    content = (
        f"# Generated on {datetime.utcnow().isoformat()} UTC\n"
        + template.replace("{{MT}}", mt)
    )

    with open(path, "w") as f:
        f.write(content)

    os.chmod(path, 0o755)
    generated.append(path)
    print(f"Generated {path}")

# ---------- update state ----------
state["last_mapping"] = mapping
with open(STATE, "w") as f:
    json.dump(state, f, indent=2)

if not generated:
    print("No MT changes detected. Nothing generated.")
elif args.force:
    print("Force mode enabled: new versions generated for all MOs.")
