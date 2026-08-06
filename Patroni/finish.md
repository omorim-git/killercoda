# まとめ

今回の劣化要因は、SUT node の `nftables` に API 向けの大量 rule を入れ、すべての request packet がその評価を受けるようになったことです。

観測できたはずの兆候:

- `k6` runner 自体は別ノードにいる
- API は動作継続している
- `http_req_failed` は低いまま
- それでも `http_req_duration` が大きく悪化する
- `nft list table inet kc_tat_lab` で専用 chain に大量 rule が見える

実運用では、アプリ内部だけでなく host firewall や packet filtering policy 変更も TAT 劣化要因になります。負荷生成を別ノードに分けると、SUT 側の問題に寄せて観測しやすくなります。
