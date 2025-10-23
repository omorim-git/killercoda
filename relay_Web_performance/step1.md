### Step 1: ページ確認
Webページを開いて通常時の性能を確認しましょう。

準備が完了したら以下のリンクからアクセスできます。

👉 [Webページを開く]({{TRAFFIC_HOST1_30081}})

  flowchart TD
      User["ユーザ<br>(Webブラウザ)"]
      Relay["Relay<br>中継サーバ / 計測＆転送"]
      Frontend["Frontend<br>静的ファイル配信"]
      Backend["Backend<br>動的処理・アプリ本体"]

      User -->|"HTTP (画面表示/操作)"| Relay
      Relay -->|"静的ファイル取得"| Frontend
      Relay -->|"HTTP/JSON (API要求)"| Backend
      Backend -->|"処理結果 (JSON)"| Relay
      Relay -->|"応答 (計測付き)"| User

  - Relay (中継サーバ): ユーザからのリクエストを受け、計測情報を付けつつ Backend へ転送するサーバです。疑似的に入力のセキュリティチェックを行います。Frontend の静的ファイルもここ経由で配信されます。
  - Frontend: HTML/JS/CSS などの静的ファイルを提供します。
  - Backend: 実際のビジネスロジックや計測処理を担当し、動的レスポンス（処理時間など）を返します。

次に進むとトラブルが発生し、性能劣化します。