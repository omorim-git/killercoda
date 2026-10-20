# トラブル発生

利用者から「API の応答が以前より遅い。アクセスが増える時間帯に特に気になる」と問い合わせがありました。API、データベース、ノードのどこに原因があるかは未確認です。

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

調査ログは次のファイル一覧から取得できます。CPUグラフのほか、測定ログやanalysis bundleも表示されます。

[調査ファイル一覧を開く]({{TRAFFIC_HOST1_8090}}/)

LLMで解析する際の例を示します。各種ログを記載したanalysis-bundle.txtを添付して解析する。

```text
添付は、APIの性能劣化を調査している2ノードKubernetes演習環境の現時点のログです。
原因の解説や設定変更・復旧手順は提示せず、観測事実と仮説を整理してください。

依頼:
1. ログから直接確認できる事実、考えられる仮説、判断できない点を分ける
2. 正常時と劣化時の応答時間、p95、失敗率、dropped_iterations、CPU・メモリ・ディスク・Pod状態を関連付ける
3. 相関だけで原因と断定せず、現時点で有力な仮説とその根拠・反証材料を示す
4. 仮説を区別するために追加採取すべき情報を、取得コマンドと確認目的付きで提案する
```

負荷中のリソースはcontrolplaneで自動採取されます。CPU、メモリ、ディスク読書量を正常時と比較してください。Standbyとk6 runnerはnode01を共有するため、必要ならworker側の状態も確認してください。

workerへは controlplane から SSH 接続できます。まずノード名を取得して接続し、`exit` で controlplane に戻ります。

```bash
ssh node01
```

worker上では、CPU・メモリ・上位プロセスなどを確認できます。`vmstat`の最初のデータ行は起動後からの平均なので、以降の1秒間隔の行を負荷中の値として見てください。

```bash
hostname
LC_ALL=C vmstat -w 1 5
free -h
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 12
exit
```

Step3では、k6実行中のworker CPUを時系列で記録し、controlplaneの自動採取結果と合わせて追加分析できるようにします。

[CPU使用率グラフ画像の一覧を開く]({{TRAFFIC_HOST1_8090}}/)

解析のヒント:

- 応答時間、成功率、完了件数を比較し、どの負荷条件から差が出るか確認する
- `dropped_iterations` は開始できなかった反復数として、HTTP エラーと分けて評価する
- 対象サーバー全体のCPU平均だけでなく、各CPU、CPU時間の内訳、上位プロセスを見て、どこが処理時間を使っているか確認する
- プロセス使用率が低くてもCPU全体が高い場合は、割り込みやネットワーク処理の割合と `NET_RX` / `NET_TX` の件数を確認する
- メモリ、ディスク I/O、プロセスや Pod の状態も合わせて確認する
- アプリケーション、OS、通信経路、負荷生成条件を候補にし、観測結果から優先順位を付ける
- 一度に変更する項目を一つに絞り、変更前後の測定結果と反証も残す

演習準備のエラー表示が出た場合は、次の準備完了・失敗ファイルを確認してください。完了ファイルがなければkillercodaを開きなおしてみてください。

```bash
ls -l /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
```

次のステップでは、追加の観測結果とLLMに渡す調査ログを準備します。原因の解説と復旧判断はこの手順では行わず、別途検討します。
