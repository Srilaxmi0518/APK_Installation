import argparse
import json, os, subprocess, re
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
BASE_SH = os.path.join(BASE, "Base_script.sh")

os.makedirs(OUT, exist_ok=True)

# ---------- load mapping ----------
with open(MAPPING) as f:
    mapping = json.load(f)

state = {"last_mapping": {}}
if os.path.exists(STATE):
    with open(STATE) as f:
        state = json.load(f)

last_mapping = state.get("last_mapping", {})

# ---------- read base.sh ----------
with open(BASE_SH, "r", newline=None) as f:
    base_script = f.read().replace("\r\n", "\n")


# ---------- version logic ----------
def next_version(mo):
    prefix = f"call_{mo}_v_"
    versions = []

    for f in os.listdir(OUT):
        if f.startswith(prefix) and f.endswith(".sh"):
            try:
                versions.append(int(f[len(prefix):-3]))
            except ValueError:
                pass

    return max(versions, default=0) + 1


# ---------- patch main_loop ----------
def render_services(entry):
    s = entry["services"]

    lines = [
        "        network_check"
    ]

    if s["data"]["enable"]:
        lines.append("        data_service")

    if s["voice"]["enable"]:
        dur = s["voice"].get("duration", 20)
        lines.append(f'        voice_service "{dur}"')

    if s["sms"]["enable"]:
        lines.append("        sms_service")

    if s["mms"]["enable"]:
        lines.append("        mms_service")

    lines += [
        "        self_update",
        "        sleep 2"
    ]

    return "\n".join(lines)


def render_script(entry):
    content = base_script

    # replace MT
    content = content.replace("{{MT}}", entry["mt"])

    # replace main_loop body
    content = re.sub(
        r"main_loop\(\)\s*{\s*while true; do.*?done\s*}",
        lambda _: f"""main_loop() {{
    while true; do
{render_services(entry)}
    done
}}""",
        content,
        flags=re.S
    )

    return f"# Generated on {datetime.utcnow().isoformat()} UTC\n\n{content}"

generated = []

# ---------- generate ----------
for mo, entry in mapping.items():
    last_entry = last_mapping.get(mo)

    # NORMAL MODE → skip unchanged MT + services
    if not args.force and last_entry == entry:
        continue

    v = next_version(mo)
    filename = f"call_{mo}_v_{v}.sh"
    path = os.path.join(OUT, filename)

    content = render_script(entry)

    with open(path, "w", newline="\n") as f:
        f.write(content)

    os.chmod(path, 0o755)
    generated.append(path)
    print(f"Generated {path}")

# ---------- update state ----------
if generated or args.force:
    state["last_mapping"] = mapping
    with open(STATE, "w") as f:
        json.dump(state, f, indent=2)

# ---------- git ----------
if generated:
    try:
        subprocess.run(["git", "add"] + generated, check=True)
        subprocess.run(
            ["git", "commit", "-m", f"Auto-generate scripts ({len(generated)} files)"],
            check=True
        )
        subprocess.run(["git", "push", "origin", "master"], check=True)
        print("Git committed and pushed")
    except subprocess.CalledProcessError as e:
        print("Git commit failed:", e)
else:
    print("No changes detected. Nothing generated.")

if args.force:
    print("Force mode enabled.")
