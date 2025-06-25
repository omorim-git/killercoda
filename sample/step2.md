# ステップ2: 接続数を増やしてエラーを再現

このPythonスクリプトを実行してみてください：

```bash
cd /root/assets
python3 connect_flood.py
```

最初の5回程度は成功しますが、それ以降は以下のようなエラーが出ます：

```
psycopg2.OperationalError: FATAL:  too many connections for role "testuser"
```

このようにして、**DBサーバ側の制限によって接続できなくなる状況**を体験できます。
