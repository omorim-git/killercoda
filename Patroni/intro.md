# シナリオ概要

あなたは API サービスの運用担当者です。利用者から応答が遅いという問い合わせを受けたとき、何を確認し、どう原因を絞り込むかを体験します。原因や影響範囲は調査開始時点では分かっていません。

対象は `kubernetes-kubeadm-2nodes` 環境の次の構成です。

- `controlplane`: 調査対象の API が動くサーバー。Kubernetes の管理機能も動いています
- `node01`: 負荷試験ツール k6 が動く別のサーバー
- `tat-api`: リクエストに応答する簡単な HTTP API。controlplane のネットワークを直接利用します
- `k6`: API に繰り返しリクエストを送り、応答時間や失敗率を測るツール

準備が終わったら、まずサーバー構成と稼働状態を確認してください。

```bash
~/kc-patroni-lab/topology.sh
~/kc-patroni-lab/cluster-status.sh
```

次のステップでは、比較の基準となる正常時の応答時間を記録します。
