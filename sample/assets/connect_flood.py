import subprocess
import time

print("Starting DB connection test using psql (persistent connections)...")
processes = []

for i in range(10):
    try:
        proc = subprocess.Popen(
            ["psql", "-U", "testuser", "-h", "localhost", "-d", "postgres"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={"PGPASSWORD": "testpass"}
        )
        processes.append(proc)
        print(f"[OK] Opened connection #{i+1}")
        time.sleep(1)
    except Exception as e:
        print(f"[ERROR] Connection #{i+1} failed: {e}")