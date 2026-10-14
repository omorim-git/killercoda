# まとめ

今回の原因は、PostgreSQL Standby側の `nftables` に大量の照合ルールが設定され、PrimaryからStandbyへのレプリケーション通信の処理が重くなったことです。

APIは各リクエストでDB更新を行い、同期レプリケーションのCOMMIT確認を待ってから応答します。そのため、DB間通信が遅くなるとAPI宛てのHTTP通信に直接ルールを追加していなくても応答時間が延びます。

観測できたはずの兆候:

- APIとDB Primaryはcontrolplane、DB Standbyとk6はnode01で動いている
- API は動作継続している
- `http_req_failed` は低いまま
- それでも `http_req_duration` が大きく悪化する
- node01上で `nft list table inet kc_tat_lab` を実行すると大量の照合ルールを確認できる

このKillercodaシナリオは2ノード構成のため、Standbyとk6 runnerは同じworkerを共有します。実環境で負荷発生源の影響を分離する場合は、負荷生成用サーバーを別に用意してください。
