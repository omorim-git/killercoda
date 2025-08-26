#!/bin/bash
set -euo pipefail

sudo apt-get update -y

curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

npm init -y
npm install express

bash --rcfile <(cat ~/.bashrc; echo 'PS1="\[\e[36m\](CUSTOM)\u@\h:\w\$ \[\e[0m\]"')

# 準備完了表示
touch /tmp/background-finished