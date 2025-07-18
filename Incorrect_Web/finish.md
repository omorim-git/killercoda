# ✅ シナリオ完了：キャッシュによるリンク切れエラーを再現しました！

お疲れさまでした！  
このシナリオでは、**Webブラウザのキャッシュが原因で、資材更新が正しく反映されないトラブル**を再現しました。

---

## 🔁 実施したことの振り返り

- Webページにリンクがある初期状態を確認
- サーバ上の資材を更新（リンク削除・ファイルリネーム）
- ブラウザが**キャッシュした旧HTML**を使い続けたことで、リンク切れ（404）が発生
- `Cache-Control` や `ETag` によるキャッシュ制御の仕組みを確認

---

## 🧠 学んだポイント

- **キャッシュは便利だが、意図せぬ表示のズレやエラーの原因にもなる**
- HTMLやJSなどの静的ファイルを更新する際は、キャッシュ無効化やバージョニングが重要
- Webサーバ（Apache/nginx）では `Cache-Control` ヘッダーを明示的に設定できる
- ブラウザ側も `Ctrl + F5` などの強制リロードをしなければキャッシュを使い続けることがある

---

## 🔧 実運用での対策例

| 対策                             | 内容 |
|----------------------------------|------|
| `Cache-Control: no-cache`        | 常にサーバ確認。開発・緊急時向け。 |
| `ETag` や `Last-Modified` の活用 | キャッシュ有効期間と更新検知を両立 |
| ファイル名のバージョン付け       | `app.v2.js` などにすることで確実に再取得 |
| CD/CIによる資材更新後のキャッシュパージ | CDNやブラウザキャッシュのクリア |

---

## 🎯 次のステップ

- キャッシュ制御の違い（`no-cache`, `no-store`, `private`, `public`）を調べてみましょう
- CDN（例：Cloudflare, Akamai）でのキャッシュ動作も合わせて理解すると実践的です
- `.htaccess` や nginx.conf による詳細制御のテクニックも学ぶと応用力が上がります

---