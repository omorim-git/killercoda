# 解答例と復旧

今回の原因は、controlplane 側 host OS の `nftables` に API 向けの大量ルールが入っていたことです。  
request ごとにその評価コストが乗るため、エラー率は高くないのに TAT と `dropped_iterations` が悪化していました。

確認方法:

```bash
sudo nft list table inet kc_tat_lab
sudo nft list ruleset | less
sudo nft list chain inet kc_tat_lab api_guard | head
sudo nft list chain inet kc_tat_lab api_guard | grep -c 'ip saddr '
```

復旧方法:

```bash
sudo nft delete table inet kc_tat_lab
```

復旧確認:

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh recovered 50
~/kc-patroni-lab/compare-results.sh
```

必要なら同じレート列で再比較します。

```bash
~/kc-patroni-lab/rate-sweep.sh recovered-sweep 30 40 50 75 100
```

`Check` は次を見ています。

- `kc_tat_lab` table が消えている
- API がまだ応答している
- `recovered` 実行結果の平均 TAT が `after-update` より改善している
