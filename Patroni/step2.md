# 性能劣化を解析する

利用者から「API の応答が以前より遅い。アクセスが増える時間帯に特に気になる」と問い合わせがありました。原因、影響範囲、発生条件は未確認です。

正常時の記録と比較して症状を確認し、根拠を集めて原因を特定してください。変更前の状態と復元方法を記録したうえで復旧を試み、同じ負荷条件で改善を検証することが課題です。

```bash
~/kc-patroni-lab/cluster-status.sh
~/kc-patroni-lab/benchmark.sh after-update 50
```

`dropped_iterations` が出始めるレート差も観測してください。

```bash
~/kc-patroni-lab/rate-sweep.sh after-update-sweep 30 40 50 75 100
~/kc-patroni-lab/compare-results.sh
```

負荷中のリソース概況も確認してください。別端末でよいです。

```bash
~/kc-patroni-lab/watch-resources.sh after-update-resources 30 5
```

解析のヒント:

- 応答時間、成功率、完了件数を比較し、どの負荷条件から差が出るか確認する
- `dropped_iterations` は開始できなかった反復数として、HTTP エラーと分けて評価する
- 対象サービスと負荷生成側の両方で CPU、メモリ、ディスク I/O、プロセスや Pod の状態を確認する
- アプリケーション、OS、通信経路、負荷生成条件を候補にし、観測結果から優先順位を付ける
- 一度に変更する項目を一つに絞り、変更前後の測定結果と反証も残す

LLM に解析を手伝わせる場合は、まずログ bundle を採取します。

```bash
~/kc-patroni-lab/analysis-bundle.sh
ls -1t ~/kc-patroni-lab/results/*analysis-bundle.txt | head -n 1
```

LLM へのプロンプト例:

```text
以下は kubeadm 2nodes の性能劣化ラボのログです。
利用者から API が遅いという問い合わせがありました。原因は未特定です。

やってほしいこと:
1. 観測できた事実と仮説、情報不足を区別する
2. 原因候補を優先度順に挙げ、それぞれの根拠と反証方法を示す
3. 次に確認すべき読み取り専用コマンドを 5 個以内で、対象ノードと確認目的付きで提案する
4. 復旧案を出す場合は、影響範囲、元に戻す方法、改善の検証方法を示す

ログ:
<analysis-bundle の内容を貼る>
```

演習準備のエラー表示が出た場合は、次の準備完了・失敗ファイルを確認してください。完了ファイルがなければ測定を始めず、講師に連絡してください。

```bash
ls -l /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
```

次の step では、原因の確認方法と復旧方法の解答例を示します。
