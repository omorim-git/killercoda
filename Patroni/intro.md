# シナリオ概要

あなたは API サービスの運用担当者です。利用者から応答が遅いという問い合わせを受けたとき、何を確認し、どう原因を絞り込むかを体験します。原因や影響範囲は調査開始時点では分かっていません。

対象は `kubernetes-kubeadm-2nodes` 環境の次の構成です。

- `controlplane`: Web/API と PostgreSQL Primary が動くサーバー。Kubernetes の管理機能も動いています
- `node01`: PostgreSQL Standby と負荷試験ツール k6 が動くサーバー
- PostgreSQL は Patroni で管理し、Primary の更新を Standby に同期レプリケーションします
- API はリクエストごとにDBへ書き込み、COMMIT完了後に応答します
- `k6`: API に繰り返しリクエストを送り、応答時間や失敗率を測るツール

2ノード環境の制約でStandbyとk6 runnerは同じ `node01` に載ります。CPU・メモリを完全には分離できない点も結果の評価に含めてください。

準備が終わったら、まずサーバー構成と稼働状態を確認してください。

```bash
~/kc-patroni-lab/topology.sh
~/kc-patroni-lab/cluster-status.sh
```

次のステップでは、比較の基準となる正常時の応答時間を記録します。
