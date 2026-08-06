# 調査して復旧する

性能劣化の原因を特定し、正常時に近い TAT に戻してください。

よく見るポイント:

```bash
~/kc-patroni-lab/cluster-status.sh
sudo nft list table inet kc_tat_lab
sudo nft list ruleset | less
kubectl get pods -n tat-lab -o wide
```

復旧の一例:

```bash
sudo nft delete table inet kc_tat_lab
```

復旧できたかは次で確認します。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh recovered 200
~/kc-patroni-lab/compare-results.sh
```

`Check` は次の状態を見ています。

- `kc_tat_lab` table が消えている
- API がまだ応答している
- `recovered` 実行結果の平均 TAT が `after-update` より改善している
