# ステップ1: PostgreSQLのインストールと設定変更

```bash
# PostgreSQLのインストール
apt update && apt install -y postgresql

# サービス起動
systemctl start postgresql

# max_connections を 5 に設定
sudo -u postgres psql -c "ALTER SYSTEM SET max_connections = 5;"

# 設定を反映するためにサービスを再起動
systemctl restart postgresql

# testuser を作成
sudo -u postgres createuser testuser --createdb
sudo -u postgres psql -c "ALTER USER testuser WITH PASSWORD 'testpass';"
```

これで準備完了です。次のステップでスクリプトを使って大量接続を試みます。
