# シナリオ概要

この演習では、Patroni の同期レプリケーション構成で「OS バージョンアップ後に急に遅くなった」状況を調査します。

Killercoda 上では 1 台の `ubuntu` ホストを 4 つの Linux network namespace に分け、次のノードを擬似的に作っています。

- `kc-primary`: PostgreSQL + Patroni の Primary
- `kc-standby`: PostgreSQL + Patroni の Standby
- `kc-etcd`: Patroni の DCS 用 etcd
- `kc-client`: `pgbench` を実行するクライアント

準備が終わったら、まずトポロジとクラスタ状態を確認してください。

```bash
~/kc-patroni-lab/topology.sh
~/kc-patroni-lab/cluster-status.sh
```

次のステップでは正常時のベースラインを取得します。
