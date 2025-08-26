bash --rcfile <(cat ~/.bashrc; echo 'PS1="\[\e[36m\](CUSTOM)\u@\h:\w\$ \[\e[0m\]"')
while [ ! -f /tmp/background-finished ]; do echo '環境準備中のためお待ちください...'; sleep 5; done
echo '準備完了!'