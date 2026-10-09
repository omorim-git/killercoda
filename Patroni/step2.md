# 性能劣化を解析する

利用者から「API の応答が以前より遅い。アクセスが増える時間帯に特に気になる」と問い合わせがありました。原因、影響範囲、発生条件は未確認です。

正常時の記録と比較して症状を確認し、根拠を集めて原因を特定してください。変更前の状態と復元方法を記録したうえで復旧を試み、同じ負荷条件で改善を検証することが課題です。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh after-update 50
```

`dropped_iterations`（実行枠が足りず開始できなかった試験回数）が、どのリクエスト数から増えるかも比較してください。

```bash
~/kc-patroni-lab/rate-sweep.sh after-update-sweep 30 40 50 75 100
~/kc-patroni-lab/compare-results.sh
```

rate-sweep の最後の列 `job_status` は、k6の終了状態です。`k6-failed`でも測定結果のログがあれば、そのrateの記録を表示して次のrateへ進みます。HTTPエラーが増えた場合は、応答時間や実行できなかった回数だけでなく、APIが再起動していないかも確認してください。

```bash
kubectl get pods -n tat-lab -l app=tat-api -o wide
kubectl describe pod -n tat-lab -l app=tat-api
kubectl logs -n tat-lab deploy/tat-api --previous
kubectl get events -n tat-lab --sort-by=.lastTimestamp | tail -n 40
```

`--previous`でログが取れない場合、コンテナが再起動していない可能性があります。Podの`Restart Count`、終了理由、イベントも合わせて確認します。調査用ログには次のコマンドでこれらの情報も含められます。

```bash
~/kc-patroni-lab/analysis-bundle.sh
```

負荷中のリソースは自動で採取・保存されます。各測定の CPU、メモリ、ディスク読書量の集計も正常時と比較してください。CPU全体・system・softirqの時系列はSVG画像に保存されます。下のリンクは最新測定の画像を表示します。測定後にページを再読み込みして比較してください。各測定固有の画像は`~/kc-patroni-lab/results/`内の`*-cpu.svg`です。採取対象はcontrolplane全体です。負荷生成側node01の状況は必要に応じて追加調査してください。

[CPU使用率グラフを開く]({{TRAFFIC_HOST1_8090}}/latest.svg)

解析のヒント:

- 応答時間、成功率、完了件数を比較し、どの負荷条件から差が出るか確認する
- `dropped_iterations` は開始できなかった反復数として、HTTP エラーと分けて評価する
- 対象サーバー全体のCPU平均だけでなく、各CPU、CPU時間の内訳、上位プロセスを見て、どこが処理時間を使っているか確認する
- プロセス使用率が低くてもCPU全体が高い場合は、割り込みやネットワーク処理の割合と `NET_RX` / `NET_TX` の件数を確認する
- メモリ、ディスク I/O、プロセスや Pod の状態も合わせて確認する
- アプリケーション、OS、通信経路、負荷生成条件を候補にし、観測結果から優先順位を付ける
- 一度に変更する項目を一つに絞り、変更前後の測定結果と反証も残す

生成AI（LLM）に調査を手伝わせる場合は、次のコマンドで保存済みの測定ログと時刻付きリソース記録を1つのファイルにまとめます。現在の状態も別見出しで収録するため、負荷中の記録と区別して読んでください。

```bash
~/kc-patroni-lab/analysis-bundle.sh
ls -1t ~/kc-patroni-lab/results/*analysis-bundle.txt | head -n 1
```

作成されたファイルを `less ファイル名` で確認し、機密情報がないことを確認してから渡してください。

生成AIに渡す依頼文の例:

```text
以下は Kubernetes の2台のサーバーを使った演習環境のログです。
利用者から API が遅いという問い合わせがありました。原因は未特定です。

やってほしいこと:
1. 観測できた事実と仮説、情報不足を区別する
2. 原因候補を優先度順に挙げ、それぞれの根拠と反証方法を示す
3. 次に確認すべき読み取り専用コマンドを 5 個以内で、対象ノードと確認目的付きで提案する
4. 復旧案を出す場合は、影響範囲、元に戻す方法、改善の検証方法を示す

ログ:
<作成された調査用ログファイルの内容を貼る>
```

演習準備のエラー表示が出た場合は、次の準備完了・失敗ファイルを確認してください。完了ファイルがなければkillercodaを開きなおしてみてください。

```bash
ls -l /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
```

次のステップでは、原因の確認方法と復旧方法の解答例を示します。
