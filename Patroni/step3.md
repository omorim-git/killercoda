# 追加調査データを集める

Step2と同じ負荷レートで再測定し、各負荷中のcontrolplaneとnode01両方のCPUグラフを取得します。次のコマンドはcontrolplane上で実行してください。引数を省略すると30/40/50/75/100 req/sを順に測定します。各rateのcontrolplaneグラフはbenchmarkが生成し、node01はk6実行時間中のCPUカウンターを1秒ごとに記録して内訳付きグラフを生成します。node01にはStandbyとk6 runnerの両方があるため、その合算負荷です。

```bash
~/kc-patroni-lab/worker-cpu-benchmark.sh
```

rateを限定する場合は、必要な数値を複数指定します（例: `~/kc-patroni-lab/worker-cpu-benchmark.sh 50 75`）。各rateについてcontrolplaneとnode01それぞれのSVGがファイル一覧に保存されます。node01の生ログ`*.procstat.log`はCPU別の累積カウンター（user、nice、system、idle、iowait、irq、softirq、steal等）を含み、対応する`.summary.txt`には試験区間の全CPU平均を記録します。グラフはCPU total、user、system、IRQ、softirqの推移を示します。累積値そのものではなく、連続サンプル間の差分を比較してください。

[負荷別CPUグラフと調査ファイルの一覧を開く]({{TRAFFIC_HOST1_8090}}/)

## LLMへ渡す調査ログ

Step2の分析bundleにworker CPUログを追加し、LLMに渡す調査ファイルを更新します。

```bash
~/kc-patroni-lab/analysis-bundle.sh
```

作成された`*-analysis-bundle.txt`を、CPUグラフ画像と同じファイル一覧からダウンロードしてください。bundleにはStep2の調査で保存した測定ファイル、各rateのnode01 CPUサマリーと生ログも含まれます。LLMへ渡す前に、ログ中に機密情報がないことを確認してください。

[調査ファイル一覧を開く]({{TRAFFIC_HOST1_8090}}/)

Step2で渡したログと暫定分析に、この追加bundleを加えて再度LLMに渡してください。追加のログから仮説を補強します。

```text
worker側CPUの追加観測を加えたものを添付する。分析を更新してください。

依頼:
1. 先ほどの分析と比較し、追加ログで新たに確認できた事実を示す
2. controlplaneとworkerのCPU記録を時刻・負荷条件に沿って比較し、workerのCPU別user/system/irq/softirq/idle等の内訳と、k6/Standbyが同じworkerを共有する影響も明記する
3. 応答時間、p95、失敗率、dropped_iterations、同期レプリケーション状態を関連付け、支持・弱化された仮説と判断できない点を更新する
4. なお必要な追加ログや読み取り専用コマンドを、取得対象ノードと目的付きで提案する
```
