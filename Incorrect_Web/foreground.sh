while [ ! -f /tmp/background-finished ]; do sleep 5; echo '環境準備中のためお待ちください...'; done
echo '準備完了!'