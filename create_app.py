import os
import pty
import time

def create_app():
    pid, fd = pty.fork()
    if pid == 0:
        # Child process
        os.environ['PYTHONUNBUFFERED'] = '1'
        os.execvp("bench", ["bench", "new-app", "quorvia_erp", "--no-git"])
    else:
        # Parent process
        time.sleep(1)
        # Write Title
        os.write(fd, b"Quorvia ERP\n")
        time.sleep(1)
        # Write Description
        os.write(fd, b"Institution Management Platform\n")
        time.sleep(1)
        # Write Publisher
        os.write(fd, b"Quorvia\n")
        time.sleep(1)
        # Write Email
        os.write(fd, b"hello@quorvia.com\n")
        time.sleep(1)
        # Write License
        os.write(fd, b"MIT\n")
        time.sleep(2)
        try:
            print(os.read(fd, 1024).decode())
            print(os.read(fd, 1024).decode())
        except Exception:
            pass

create_app()
