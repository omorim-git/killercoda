# シナリオ概要

あなたは API サービスの運用担当者です。利用者から応答が遅いという問い合わせを受けたとき、何を確認し、どう原因を絞り込むかを体験します。原因や影響範囲は調査開始時点では分かっていません。

対象は `kubernetes-kubeadm-2nodes` 環境の次の構成です。

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
