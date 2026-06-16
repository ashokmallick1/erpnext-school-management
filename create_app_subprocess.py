import subprocess

process = subprocess.run(
    ["bench", "new-app", "quorvia_erp", "--no-git"],
    input=b"Quorvia ERP\nInstitution Management Platform\nQuorvia\nhello@quorvia.com\nmit\ny\n",
    capture_output=True
)
print("STDOUT:", process.stdout.decode())
print("STDERR:", process.stderr.decode())
