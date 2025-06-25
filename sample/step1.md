# ステップ1: PostgreSQLのインストールと設定確認

このステップはすでに自動的に完了しています。確認だけ行いましょう：

```bash
# PostgreSQLの状態確認
systemctl status postgresql

# max_connections の確認
sudo -u postgres psql -c "SHOW max_connections;"
```

すでに `max_connections = 5` に設定されています。
