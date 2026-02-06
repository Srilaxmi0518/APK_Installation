from flask import Flask, request, redirect, render_template_string
import json, subprocess

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
<td><input name="{{ mo }}" value="{{ mt }}"></td>
</tr>
{% endfor %}
</table>
<br>
<button type="submit">Save & Generate</button>
</form>
"""

@app.route("/", methods=["GET", "POST"])
def index():
    with open(MAPPING) as f:
        mapping = json.load(f)

    if request.method == "POST":
        for mo in mapping:
            mapping[mo] = request.form.get(mo)

        with open(MAPPING, "w") as f:
            json.dump(mapping, f, indent=2)

        subprocess.run(["python", "generate.py"])
        return redirect("/")

    return render_template_string(HTML, mapping=mapping)

app.run(port=5000, debug=True)
