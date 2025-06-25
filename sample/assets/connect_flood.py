import psycopg2
from time import sleep

connections = []

for i in range(10):
    try:
        conn = psycopg2.connect(
            dbname="postgres",
            user="testuser",
            password="testpass",
            host="localhost"
        )
        connections.append(conn)
        print(f"[OK] Connected #{i+1}")
        sleep(1)
    except Exception as e:
        print(f"[ERROR] Connection #{i+1} failed: {e}")
