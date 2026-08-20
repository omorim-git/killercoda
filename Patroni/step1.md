# 正常時のベースライン

まずは正常時の API 応答時間を確認します。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh baseline 50
```

期待する観点:

- `tat-api` が `controlplane` に載っている
- `k6` は `node01` で実行される
- `nftables` 用の専用 table はまだ存在しない
- 既定では 20 秒間、指定した `rate` で負荷をかける
- `http_req_duration` の `avg` / `p(95)` が基準値になる
- `http_req_failed` は `0.00%` 近辺になる

必要なら結果ファイルの場所を控えてください。

```bash
ls -1 ~/kc-patroni-lab/results
```

単一点の TAT だけでなく、drop が出始める負荷レートも見たい場合は次を使います。

```bash
~/kc-patroni-lab/rate-sweep.sh baseline-sweep 30 40 50 75 100
```

負荷中のリソース状況も見たい場合は、別端末で次を実行します。

```bash
~/kc-patroni-lab/watch-resources.sh baseline-resources 30 5
```

ここで見たいのは、TAT が悪化しても CPU/メモリ/ディスク I/O が極端には張り付かないことです。
