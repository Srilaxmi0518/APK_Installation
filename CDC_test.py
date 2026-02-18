import os

from flask import Flask, request, redirect, render_template_string
import json, subprocess, sys
from waitress import serve

app = Flask(__name__)
MAPPING = "Testdata.json"
IMPORTED_JSON = "IMEI.json"

HTML = """
<h3>MO → MT Mapping</h3>

<form method="post">
<table border="1" cellpadding="6">
<tr><th>MO</th><th>MT</th></tr>
{% for mo, mt in mapping.items() %}
<tr>
  <td>{{ mo }}</td>
  <td><input name="edit_{{ mo }}" value="{{ mt }}"></td>
</tr>
{% endfor %}
</table>
<br>
<button type="submit" name="action" value="update">Save Changes</button>
</form>

<hr>

<h3>Add New Mapping</h3>
<form method="post">
MO: <input name="new_mo" required>
MT: <input name="new_mt" required>
<br><br>
<button type="submit" name="action" value="add">Add & Generate</button>
</form>

<hr>

<h3>Script Operations</h3>
<form method="post">
<button
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
"""

@app.route("/", methods=["GET", "POST"])
def index():
    with open(MAPPING) as f:
        mapping = json.load(f)

    if request.method == "POST":
        action = request.form.get("action")

        if action == "update":
            for mo in mapping:
                key = f"edit_{mo}"
                if key in request.form:
                    mapping[mo] = request.form[key]

            with open(MAPPING, "w") as f:
                json.dump(mapping, f, indent=2)

            subprocess.run(
                [sys.executable, "generate.py"],
                check=True
            )

        elif action == "add":
            mo = request.form.get("new_mo").strip()
            mt = request.form.get("new_mt").strip()

            if mo in mapping:
                return f"MO {mo} already exists", 400

            mapping[mo] = mt

            with open(MAPPING, "w") as f:
                json.dump(mapping, f, indent=2)

            subprocess.run(
                [sys.executable, "generate.py"],
                check=True
            )

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
    app.run(port=5000, debug=True)
    #serve(app, host="::", port=5000)
