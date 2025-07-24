### Step 1: 🔍 初期状態のWebページを確認

まず、初期状態のWebページを開いてリンクが表示されることを確認しましょう。以下のリンクからアクセスできます。

👉 [Webページを開く]({{TRAFFIC_HOST1_80}})

### Step 2: 🔁 リンク先ページにもアクセスしてみよう

リンク「Subpage」をクリックすると、次のページが表示されます。

### Step 3: 🛠 資材を更新する

`~/` に更新用のHTMLが配置されています。以下のコマンドで更新してください。

```bash
sudo cp ~/index_after.html /var/www/html/index.html
sudo mv /var/www/html/subpage.html /var/www/html/subpage_updated.html
```{{copy}}

### Step 4: ⚠ もう一度リンク先ページにアクセスしてみよう

最初に開いたページのリンクをクリックしてみてください