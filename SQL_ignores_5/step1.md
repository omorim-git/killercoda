### Step 1: テーブルを作成
以下のシェルを実行してください。<br>
usersテーブルを作成し、id0～99のユーザ名nameにUser0からUser99を設定します。<br>
テーブルを書き換えた後も、同シェルを再度実行すれば初期状態に戻せます。
```bash
~/init_table.sh
```{{copy}}

### Step 2: テーブルを確認
以下のコマンドでusersテーブルを確認してください。
```bash
sudo -u postgres env PAGER=cat psql -d data_db -c "select * from users;"
```{{copy}}

### Step 3: バッチ処理を実行
以下のコマンドでnameを書き換えるバッチ処理を実行してください。
```bash
~/run.sh
```{{copy}}

### Step 4: バッチ処理後のテーブルを確認
以下のコマンドでテーブルを確認してください。nameに"Updated_"が追加されていますがUser5だけ書き換わっていないことが確認できます。
```bash
sudo -u postgres env PAGER=cat psql -d data_db -c "select * from users;"
```{{copy}}

### Step 5: 資材を確認する
catやnano、viなどのコマンドや、コンソール左上のEditorタブでエディタを開いて処理内容を確認し、問題点を修正してください。再度コマンドを実行し、結果も確認してみましょう。
```bash
cat ~/run.sh
```{{copy}}

解決したら次のページに進んでください。