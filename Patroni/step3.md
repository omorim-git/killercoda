# 追加調査データを集める

Step2で確認した同じ負荷レートを使い、k6実行中のworker側CPUを1秒間隔で記録します。次のコマンドはcontrolplane上で実行してください。内部で`ssh node01`を使い、worker CPUの記録とk6実行を行います。workerのCPU記録にはStandbyとk6 runnerの両方の負荷が含まれます。

```bash
~/kc-patroni-lab/worker-cpu-benchmark.sh 50
```

`50`は例です。Step2で遅延や`dropped_iterations`が現れたレートに置き換え、正常時と同じ負荷条件で比較してください。workerログの`us`（ユーザー処理）、`sy`（OS処理）、`id`（CPUアイドル）、`wa`（I/O待ち）、`st`（仮想CPU待ち）を見ます。`vmstat`の最初のデータ行は累積平均なので、その後の行を負荷中の記録として扱います。

## LLMへ渡す調査ログ

Step2の分析bundleにworker CPUログを追加し、LLMに渡す調査ファイルを更新します。

```bash
~/kc-patroni-lab/analysis-bundle.sh
```

作成された`*-analysis-bundle.txt`を、CPUグラフ画像と同じファイル一覧からダウンロードしてください。bundleにはStep2の調査で保存した測定ファイルも含まれます。LLMへ渡す前に、ログ中に機密情報がないことを確認してください。

[調査ファイル一覧を開く]({{TRAFFIC_HOST1_8090}}/)

Step2で渡したログと暫定分析に、この追加bundleを加えて再度LLMに渡してください。Step2の分析を維持するだけでなく、新しいworker記録で支持・弱化された仮説を更新します。

```text
以下は、APIの性能劣化を調査している2ノードKubernetes演習環境のログです。
これはStep2の暫定分析にworker側CPUの追加観測を加えたものです。原因の解説や復旧作業は行わず、別途の解説打ち合わせに向けて分析を更新してください。

依頼:
1. Step2の暫定分析と比較し、追加ログで新たに確認できた事実を示す
2. controlplaneとworkerのCPU記録を時刻・負荷条件に沿って比較し、k6/Standbyが同じworkerを共有する影響も明記する
3. 応答時間、p95、失敗率、dropped_iterations、同期レプリケーション状態を関連付け、支持・弱化された仮説と判断できない点を更新する
4. なお必要な追加ログや読み取り専用コマンドを、取得対象ノードと目的付きで提案する
5. 原因の断定、解答、設定変更・復旧手順は提示しない

ログ:
<analysis-bundle.txtの内容>
```
