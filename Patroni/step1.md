# 正常時の応答時間を記録する

まずは正常時の API 応答時間を確認します。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh baseline 50
```

期待する観点:

- `tat-api` が `controlplane` に載っている
- `k6` は `node01` で実行される
- 既定では 20 秒間、指定した `rate` で負荷をかける
- `http_req_duration` の `avg` / `p(95)` が基準値になる
- `http_req_failed` は `0.00%` 近辺になる

必要なら結果ファイルの場所を控えてください。

```bash
ls -1 ~/kc-patroni-lab/results
```

1秒あたりのリクエスト数を順に増やして、試験を開始できない回数が増える条件も調べます。

```bash
~/kc-patroni-lab/rate-sweep.sh baseline-sweep 30 40 50 75 100
```

結果の列は次の意味です。

| 列 | 意味 |
| --- | --- |
| label | 測定名 |
| rate | 1秒あたりに開始したいリクエスト数 |
| avg | 平均応答時間 |
| p95 | 応答時間の95パーセンタイル。約95%の応答がこの時間以内に収まります |
| failed | 送信したHTTPリクエストの失敗率 |
| dropped | 実行枠が足りず開始できなかった試験回数。HTTPエラーとは別です |
| reqs | 実測の1秒あたりリクエスト数。終了待ちの時間も影響します |

応答時間は `ms` がミリ秒、`s` が秒です。表の後のリソース表示は測定終了後の値です。負荷中の状態は下記のコマンドで記録してください。メモリは「空き」だけでなく、キャッシュを再利用できる分を含む「利用可能」を確認します。

負荷中のリソース状況も見たい場合は、別端末で次を実行します。

```bash
~/kc-patroni-lab/watch-resources.sh baseline-resources 30 5
```

CPU、メモリ、ディスク I/O の正常時の値を記録してください。後の調査では、同じ負荷条件で取得した値と比較します。
