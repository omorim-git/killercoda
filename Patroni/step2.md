# nftables 投入後の TAT 劣化

このステップに進んだ時点で、controlplane の API 入口に `nftables` の大量ルールが自動投入されています。

適用された内容:

- API ポート `8080` 宛て packet を専用 chain に誘導
- 実際には一致しない blacklist ルールを大量に追加
- `node01` からの k6 リクエストはその評価コストを毎回受ける

まずは現象を観測してください。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh after-update 20
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
