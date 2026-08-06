# シナリオ概要

この演習では、`kubernetes-kubeadm-2nodes` 環境で次の構成を作り、`nftables` の大量ルールにより API の TAT が劣化する状況を観測します。

- `controlplane`: SUT を置くノード
- `node01`: `k6` runner を置くノード
- `tat-api`: controlplane 上で `hostNetwork` で動く薄い HTTP API
- `k6`: node01 上で Job として実行される負荷試験

準備が終わったら、まずトポロジと状態を確認してください。

```bash
~/kc-patroni-lab/topology.sh
~/kc-patroni-lab/cluster-status.sh
```

次のステップでは正常時の TAT ベースラインを取得します。
