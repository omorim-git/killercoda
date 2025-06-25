#!/bin/bash

apt update && apt install -y postgresql > /dev/null 2>&1

systemctl start postgresql

sudo -u postgres psql -c "ALTER SYSTEM SET max_connections = 5;"
sudo -u postgres createuser testuser --createdb
sudo -u postgres psql -c "ALTER USER testuser WITH PASSWORD 'testpass';"
systemctl restart postgresql
