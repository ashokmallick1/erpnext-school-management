import os

hooks_path = "apps/quorvia_erp/quorvia_erp/hooks.py"
with open(hooks_path, "r") as f:
    content = f.read()

content += """
app_name = "quorvia_erp"
app_title = "Quorvia ?"
app_publisher = "Quorvia"
app_description = "Institution Management Platform"

app_logo_url = "/assets/quorvia_erp/images/quorvia_logo.svg"

app_include_css = "/assets/quorvia_erp/css/quorvia_erp.css"
web_include_css = "/assets/quorvia_erp/css/quorvia_erp.css"

"""
with open(hooks_path, "w") as f:
    f.write(content)
