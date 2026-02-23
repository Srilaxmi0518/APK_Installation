import os

from flask import Flask, request, redirect, render_template_string
import json, subprocess, sys
from waitress import serve

app = Flask(__name__)
MAPPING = "Testdata.json"
IMPORTED_JSON = "IMEI.json"

HTML = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>MO → MT Mapping</title>

<style>
body {
    font-family: Arial, sans-serif;
    background: #f6f7fb;
    margin: 30px;
}

h3 {
    margin-top: 30px;
}

table {
    border-collapse: collapse;
    width: 100%;
    background: white;
}

th, td {
    padding: 10px;
    border-bottom: 1px solid #ddd;
    text-align: center;
}

th {
    background: #0ea5a5;
    color: white;
    position: sticky;
    top: 0;
}

td:first-child,
td:nth-child(2) {
    text-align: left;
}

input[type="text"], input[type="number"] {
    padding: 6px;
}

input[type="number"] {
    width: 70px;
}

input.changed {
    background: #fff7cc;
    border: 1px solid #f59e0b;
}

button {
    padding: 10px 16px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
}

.primary { background: #0ea5a5; color: white; }
.secondary { background: #10b981; color: white; }
.danger { background: #ef4444; color: white; }

.search-box {
    margin-bottom: 10px;
    padding: 8px;
    width: 300px;
}

.toast {
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: #10b981;
    color: white;
    padding: 12px 18px;
    border-radius: 5px;
    display: none;
}
</style>

<script>
let dirty = false;

function markChanged(el) {
    el.classList.add("changed");
    dirty = true;
}

window.onbeforeunload = function () {
    if (dirty) return "You have unsaved changes.";
};

function filterTable() {
    let filter = document.getElementById("search").value.toLowerCase();
    document.querySelectorAll("tbody tr").forEach(row => {
        row.style.display = row.dataset.mo.includes(filter) ? "" : "none";
    });
}

function showToast(msg) {
    let t = document.getElementById("toast");
    t.innerText = msg;
    t.style.display = "block";
    setTimeout(() => t.style.display = "none", 2500);
}

document.addEventListener("change", function (e) {
    if (e.target.name && e.target.name.endsWith("_voice")) {
        let row = e.target.closest("tr");
        let dur = row.querySelector('input[name$="voice_duration"]');
        if (dur) dur.disabled = !e.target.checked;
    }
});
</script>
</head>

<body>

<h3>MO → MT Mapping</h3>

<input id="search"
       class="search-box"
       placeholder="Search MO..."
       onkeyup="filterTable()">

<form method="post" onsubmit="dirty=false; showToast('Changes saved!')">

<table>
<thead>
<tr>
    <th>MO</th>
    <th>MT</th>
    <th>Voice</th>
    <th>Duration</th>
    <th>SMS</th>
    <th>MMS</th>
    <th>Data</th>
</tr>
</thead>

<tbody>
{% for mo, data in mapping.items() %}
<tr data-mo="{{ mo|lower }}">
    <td><strong>{{ mo }}</strong></td>

    <td>
        <input type="text"
               name="edit_mt_{{ mo }}"
               value="{{ data.mt }}"
               onchange="markChanged(this)">
    </td>

    <td>
        <input type="checkbox"
               name="svc_{{ mo }}_voice"
               {% if data.services.voice.enable %}checked{% endif %}
               onchange="markChanged(this)">
    </td>

    <td>
        <input type="number"
               min="1"
               name="svc_{{ mo }}_voice_duration"
               value="{{ data.services.voice.duration }}"
               {% if not data.services.voice.enable %}disabled{% endif %}
               onchange="markChanged(this)">
    </td>

    <td>
        <input type="checkbox"
               name="svc_{{ mo }}_sms"
               {% if data.services.sms.enable %}checked{% endif %}
               onchange="markChanged(this)">
    </td>

    <td>
        <input type="checkbox"
               name="svc_{{ mo }}_mms"
               {% if data.services.mms.enable %}checked{% endif %}
               onchange="markChanged(this)">
    </td>

    <td>
        <input type="checkbox"
               name="svc_{{ mo }}_data"
               {% if data.services.data.enable %}checked{% endif %}
               onchange="markChanged(this)">
    </td>
</tr>
{% endfor %}
</tbody>
</table>

<br>
<button class="primary" type="submit" name="action" value="update">
💾 Save Changes
</button>
</form>

<hr>

<h3>Add New Mapping</h3>
<form method="post">

<input name="new_mo" placeholder="MO" required>
<input name="new_mt" placeholder="MT" required>

<br><br>

<label>
<input type="checkbox" name="new_voice"> Voice
</label>
<input type="number" name="new_voice_duration" value="20">

<label><input type="checkbox" name="new_sms"> SMS</label>
<label><input type="checkbox" name="new_mms"> MMS</label>
<label><input type="checkbox" name="new_data"> Data</label>

<br><br>

<button class="secondary" type="submit" name="action" value="add">
➕ Add & Generate
</button>
</form>

<hr>

<h3>Script Operations</h3>
<form method="post">
<button class="danger"
        type="submit"
        name="action"
        value="force"
        onclick="return confirm('This will generate NEW versions for ALL MOs. Continue?');">
🔁 Update Script (All MOs)
</button>
</form>

<hr>

<h3>Imported Test Data (Read-Only)</h3>
<form method="post">
<button type="submit" name="action" value="import">
  📥 Import & View Test Data
</button>
</form>

{% if imported %}
<br>
<table border="1" cellpadding="6">
<tr>
  <th>S.No</th>
  <th>IMEI</th>
  <th>MSISDN</th>
  <th>IMSI</th>
  <th>Network</th>
</tr>

{% for sno, row in imported.items() %}
<tr>
  <td>{{ sno }}</td>
  <td>{{ row.get("IMEI","-") }}</td>
  <td>{{ row.get("MSISDN","-") }}</td>
  <td>{{ row.get("IMSI","-") }}</td>
  <td>{{ row.get("Network","-") }}</td>
</tr>
{% endfor %}
</table>
{% endif %}

<div id="toast" class="toast"></div>

</body>
</html>

"""

def normalize(entry):
    entry.setdefault("mt", "")
    entry.setdefault("services", {})

    entry["services"].setdefault(
        "voice", {"enable": False, "duration": 20}
    )

    for svc in ["sms", "mms", "data"]:
        entry["services"].setdefault(svc, {"enable": False})


@app.route("/", methods=["GET", "POST"])
def index():
    with open(MAPPING) as f:
        mapping = json.load(f)

    # normalize all entries (important)
    for entry in mapping.values():
        normalize(entry)

    changed = False  # 🔑 global change flag

    if request.method == "POST":
        action = request.form.get("action")

        # --------------------------------------------------
        # UPDATE EXISTING MAPPINGS
        # --------------------------------------------------
        if action == "update":

            for mo, entry in mapping.items():
                normalize(entry)

                # ---------- MT ----------
                mt_key = f"edit_mt_{mo}"
                if mt_key in request.form:
                    new_mt = request.form[mt_key].strip()
                    if new_mt != entry["mt"]:
                        entry["mt"] = new_mt
                        changed = True

                services = entry["services"]

                # ---------- VOICE ----------
                voice_checked = f"svc_{mo}_voice" in request.form
                if voice_checked != services["voice"]["enable"]:
                    services["voice"]["enable"] = voice_checked
                    changed = True

                if voice_checked:
                    dur_key = f"svc_{mo}_voice_duration"
                    new_dur = int(request.form.get(dur_key, 20))
                    if new_dur != services["voice"]["duration"]:
                        services["voice"]["duration"] = new_dur
                        changed = True

                # ---------- SMS / MMS / DATA ----------
                for svc in ["sms", "mms", "data"]:
                    enabled = f"svc_{mo}_{svc}" in request.form
                    if enabled != services[svc]["enable"]:
                        services[svc]["enable"] = enabled
                        changed = True

            if changed:
                with open(MAPPING, "w") as f:
                    json.dump(mapping, f, indent=2)

                subprocess.run(
                    [sys.executable, "generate.py"],
                    check=True
                )

        # --------------------------------------------------
        # ADD NEW MAPPING
        # --------------------------------------------------
        elif action == "add":
            mo = request.form.get("new_mo", "").strip()
            mt = request.form.get("new_mt", "").strip()

            if mo in mapping:
                return f"MO {mo} already exists", 400

            mapping[mo] = {
                "mt": mt,
                "services": {
                    "voice": {
                        "enable": "new_voice" in request.form,
                        "duration": int(request.form.get("new_voice_duration", 20))
                    },
                    "sms":  {"enable": "new_sms" in request.form},
                    "mms":  {"enable": "new_mms" in request.form},
                    "data": {"enable": "new_data" in request.form}
                }
            }

            with open(MAPPING, "w") as f:
                json.dump(mapping, f, indent=2)

            subprocess.run(
                [sys.executable, "generate.py"],
                check=True
            )

        # --------------------------------------------------
        # FORCE GENERATE
        # --------------------------------------------------
        elif action == "force":
            subprocess.run(
                [sys.executable, "generate.py", "--force"],
                check=True
            )
        elif action == "import":
            if os.path.exists(IMPORTED_JSON):
                with open(IMPORTED_JSON) as f:
                    imported = json.load(f)
            return render_template_string(
                HTML,
                mapping=mapping,
                imported=imported
            )

        return redirect("/")

    return render_template_string(HTML, mapping=mapping)

if __name__ == "__main__":
    #app.run(host="[2a00:fbc:1250:1f51:5e78:ee66:3e4f:81f4]",port=5000, debug=True)
    app.run(host="[localhost]",port=5000, debug=True)
    # app.run(port=5000, debug=True)
    #serve(app, host="::", port=5000)
