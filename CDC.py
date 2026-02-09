from flask import Flask, request, redirect, render_template_string
import json, subprocess, sys

app = Flask(__name__)
MAPPING = "Testdata.json"

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

        elif action == "add":
            mo = request.form.get("new_mo").strip()
            mt = request.form.get("new_mt").strip()

            if mo in mapping:
                return f"MO {mo} already exists", 400

            mapping[mo] = mt  # 👈 add new entry

        with open(MAPPING, "w") as f:
            json.dump(mapping, f, indent=2)

        # run generator
        subprocess.run([sys.executable, "generate.py"], check=True)

        return redirect("/")

    return render_template_string(HTML, mapping=mapping)

app.run(port=5000, debug=True)
