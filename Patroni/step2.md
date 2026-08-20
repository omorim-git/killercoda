# nftables 投入後の TAT 劣化

このステップに進んだ時点で、controlplane の API 入口に `nftables` の大量ルールが自動投入されています。

適用された内容:

- API ポート `8080` 宛て packet を専用 chain に誘導
- 実際には一致しない blacklist ルールを大量に追加
- `node01` からの k6 リクエストはその評価コストを毎回受ける

まずは現象を観測してください。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh after-update 50
```

追加で次の観点も確認すると切り分けしやすくなります。

```bash
sudo nft list table inet kc_tat_lab
curl -sS "$(~/kc-patroni-lab/topology.sh | awk '/tat-api/ {print $3}')" | jq .
kubectl get jobs -n tat-lab -o wide
```

step 遷移時に background 実行エラーが出た場合は、まず次を確認してください。

```bash
cat /tmp/kc-patroni-lab-update.log
ls -l /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
```

ポイント:

- API 自体は動いている
- `http_req_failed` はほぼ増えない
- それでも `http_req_duration` が悪化する
- k6 runner は別ノードなので、SUT node の CPU 競合とは切り分けやすい
- `benchmark.sh <label> <rate>` で、時間ではなく到達レートを指定する

`dropped_iterations` が出始めるレート差を見せたい場合は、同じレート列で比較します。

```bash
~/kc-patroni-lab/rate-sweep.sh after-update-sweep 30 40 50 75 100
~/kc-patroni-lab/compare-results.sh
```

負荷中のリソース状況も、別端末で合わせて取ると切り分けしやすくなります。

```bash
~/kc-patroni-lab/watch-resources.sh after-update-resources 30 5
```

見せたいポイント:

- TAT は大きく悪化する
- `dropped_iterations` が出始める rate は小さくなる
- それでも CPU / メモリ / ディスク I/O は主因に見えにくい
