# 性能劣化を解析する

このステップに進んだ時点で、環境側に性能劣化要因が自動投入されています。  
何が変わったかはまだ明かしません。まずは症状を観測し、原因候補を絞ってください。

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

- API 自体は動いている
- `http_req_failed` は増えないか、増えても主因ではない
- `http_req_duration` と `dropped_iterations` が悪化する
- k6 runner は別ノードなので、SUT node の CPU 競合とは切り分けやすい
- CPU / メモリ / ディスク I/O が極端に張り付いていないなら、アプリ内部以外も疑う
- host OS のネットワーク設定、packet filtering、経路上の待ちを確認する

LLM に解析を手伝わせる場合は、まずログ bundle を採取します。

```bash
~/kc-patroni-lab/analysis-bundle.sh
ls -1t ~/kc-patroni-lab/results/*analysis-bundle.txt | head -n 1
```

LLM へのプロンプト例:

```text
以下は kubeadm 2nodes の性能劣化ラボのログです。
症状は API は応答しているが TAT が悪化し、dropped_iterations が増えていることです。

やってほしいこと:
1. ログから主なボトルネック候補を優先度順に列挙する
2. CPU、メモリ、ディスク I/O が主因かどうか判断する
3. host OS のネットワーク設定や packet filtering を疑うべきか判断する
4. 次に controlplane で確認すべきコマンドを 5 個以内で提案する

ログ:
<analysis-bundle の内容を貼る>
```

step 遷移時に background 実行エラーが出た場合は、まず次を確認してください。

```bash
cat /tmp/kc-patroni-lab-update.log
ls -l /tmp/kc-patroni-lab-update.failed /tmp/kc-patroni-lab-update.finished
```

次の step では、原因の確認方法と復旧方法の解答例を示します。
