# 調査して復旧する

性能劣化の原因を特定し、正常時の性能に戻してください。

よく見るポイント:

```bash
systemctl status firewalld --no-pager
firewall-cmd --get-active-zones
sudo ip -br link show kcbr0 veth-standby
sudo ip netns exec kc-primary ip -br link
sudo ip netns exec kc-standby ip -br link
sudo ip netns exec kc-primary tc -s qdisc show dev eth0
sudo ip netns exec kc-standby tc -s qdisc show dev eth0
sudo ip netns exec kc-client ping -M do -s 8972 -c 2 10.66.0.12
```

復旧できたかは次で確認します。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh recovered 20
~/kc-patroni-lab/compare-results.sh
```

`Check` は次の状態を見ています。

- Jumbo ping が再び通る
- Primary / Standby の `netem` が外れている
- Standby 側の MTU が `9000` に戻っている
- 同期レプリケーションが維持されている

`firewalld` は停止しても、通信を維持したまま有効化しても構いません。検証は性能復旧を優先します。
