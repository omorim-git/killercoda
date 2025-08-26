#!/bin/bash
set -euo pipefail

sudo apt-get update -y

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

npm init -y
npm install express

# 準備完了表示
touch /tmp/background-finished