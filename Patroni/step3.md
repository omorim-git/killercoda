# 追加調査データを集める

Step2で確認した同じ負荷レートを使い、k6実行中のworker側CPUを1秒間隔で記録します。コマンドはcontrolplane上で実行してください。`benchmark.sh`はnode01上にk6 Jobを配置するため、workerのCPU記録にはStandbyとk6 runnerの両方の負荷が含まれます。

```bash
source ~/kc-patroni-lab/lib.sh
WORKER="$(worker_node)"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORKER_LOG="$HOME/kc-patroni-lab/results/worker-after-update-${STAMP}.vmstat.log"
mkdir -p "$HOME/kc-patroni-lab/results"

ssh "$WORKER" 'LC_ALL=C vmstat -w 1' >"$WORKER_LOG" 2>&1 &
MONITOR_PID=$!
sleep 2
set +e
~/kc-patroni-lab/benchmark.sh after-update-worker 50
BENCHMARK_STATUS=$?
set -e
kill "$MONITOR_PID" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true
printf 'worker_cpu_log: %s\n' "$WORKER_LOG"
exit "$BENCHMARK_STATUS"
```

`50`は例です。Step2で遅延や`dropped_iterations`が現れたレートに置き換え、正常時と同じ負荷条件で比較してください。workerログの`us`（ユーザー処理）、`sy`（OS処理）、`id`（CPUアイドル）、`wa`（I/O待ち）、`st`（仮想CPU待ち）を見ます。`vmstat`の最初のデータ行は累積平均なので、その後の行を負荷中の記録として扱います。

## LLMへ渡す調査ログ

測定ログ、時刻付きcontrolplaneリソース記録、Pod/DB/APIの状態、worker側の現在状態と上のworker CPUログを1ファイルにまとめます。

```bash
~/kc-patroni-lab/analysis-bundle.sh
```

作成された`*-analysis-bundle.txt`を、CPUグラフ画像と同じファイル一覧からダウンロードしてください。bundleにはStep2の調査で保存した測定ファイルも含まれます。LLMへ渡す前に、ログ中に機密情報がないことを確認してください。

依頼文では原因を先に決めつけず、次のように観測事実・仮説・不足情報を分けて分析するよう求めます。

```text
以下は、APIの性能劣化を調査している2ノードKubernetes演習環境のログです。
まだ原因の解説や復旧作業は行わず、別途の解説打ち合わせに向けて調査材料を整理してください。

依頼:
1. 観測された事実、仮説、判断できない点を分ける
2. controlplaneとworkerのCPU記録を時刻・負荷条件に沿って比較し、k6/Standbyが同じworkerを共有する影響も明記する
3. 応答時間、p95、失敗率、dropped_iterations、同期レプリケーション状態を関連付ける。ただし相関だけで原因と断定しない
4. 仮説を区別するために追加で必要なログや読み取り専用コマンドを、取得対象ノードと目的付きで提案する
5. 原因の断定、解答、設定変更・復旧手順は提示しない

ログ:
<analysis-bundle.txtの内容>
```
