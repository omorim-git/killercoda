# 解答例と復旧

今回の原因は、API が動く controlplane の OS にある通信制御機能 `nftables` に、大量のルールが設定されていたことです。
受信した通信データ（パケット）を順にルールと照合する処理が増えます。その影響を、応答時間や `dropped_iterations`（開始できなかった試験回数）の変化から確認します。

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

- ルールをまとめたテーブル `kc_tat_lab` が消えている
- API がまだ応答している
- `recovered` 実行結果の平均応答時間が `after-update` より改善している
