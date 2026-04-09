# アップデート後の性能劣化

このステップに進んだ時点で、夜間アップデートを模した変更が自動適用されています。

適用された内容:

- `firewalld` の有効化
- Standby 側 MTU の `9000 -> 1500` 変更
- Primary / Standby の通信に `tc netem` で遅延とロスを付与

まずは現象を観測してください。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh after-update 20
```

追加で次の観点も確認すると切り分けしやすくなります。

```bash
sudo ip netns exec kc-client ping -M do -s 8972 -c 2 10.66.0.12
sudo ip netns exec kc-primary netstat -s | egrep -i 'retrans|segments retransmitted'
sudo ip netns exec kc-primary tc -s qdisc show dev eth0
sudo ip netns exec kc-standby tc -s qdisc show dev eth0
```

ポイント:

- DB は落ちていない
- すぐにエラーにもならない
- CPU ボトルネックにも見えにくい
- それでも COMMIT 待ちで体感的に遅い
