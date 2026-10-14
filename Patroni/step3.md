# 解答例と復旧

今回の原因は、PostgreSQL Standby が動く `node01` の `nftables` に大量の照合ルールが設定され、PrimaryからStandbyへ送るレプリケーション通信の処理が重くなっていたことです。API自身の通信を直接制限しているわけではありません。

APIは各リクエストでDBへ書き込み、同期COMMITが完了してから応答します。PrimaryはStandbyからWALの受信確認を得るまでCOMMITを完了できないため、DB間通信の遅れがAPIの応答時間に現れます。

確認方法:

```bash
STANDBY_NODE="$(kubectl get pod -n tat-lab -l cluster-name=kc-sync-lab,spilo-role=replica -o jsonpath='{.items[0].spec.nodeName}')"
ssh "$STANDBY_NODE" sudo nft list table inet kc_tat_lab
ssh "$STANDBY_NODE" sudo nft list chain inet kc_tat_lab replication_guard | head
ssh "$STANDBY_NODE" sudo nft list chain inet kc_tat_lab replication_guard | grep -c 'ip saddr '
```

復旧方法:

```bash
ssh "$STANDBY_NODE" sudo nft delete table inet kc_tat_lab
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
- Patroniの状態表示でStandbyが同期状態に戻っている
