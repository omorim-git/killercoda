# 正常時のベースライン

まずは正常時のスループットと同期レプリ状態を確認します。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh baseline 20
```

期待する観点:

- `firewalld` は停止している
- `kc-primary` / `kc-standby` の MTU は `9000`
- `tc netem` は入っていない
- Patroni クラスタは `Leader` と `Replica` で安定している
- `pgbench` の `tps` と `latency average` が基準値になる

必要なら結果を比較しやすいように、出力されたログファイルの場所を控えてください。

```bash
ls -1 ~/kc-patroni-lab/results
```
