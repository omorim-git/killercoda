### Step 1: 非同期処理を実行
以下のコマンドで非同期処理を実行してください。
```bash
~/run.sh
```{{copy}}

### Step 2: 非同期処理の結果を確認
以下のコマンドで結果を確認してください。
```bash
sudo -u postgres psql -d mydb -c "select * from data_table;"
```{{copy}}

### Step 3: 資材を確認する
viなどで処理を確認し、問題点を修正してください。再度コマンドを実行し、結果も確認してみましょう。
```bash
~/run.sh
```{{copy}}

解決したら次のページに進んでください。