### トラブル発生
トラブルが発生し、Webアクセスが遅くなっています。Webの状況確認を行い、原因を調査し、改善してください。

👉 [Webページを開く]({{TRAFFIC_HOST1_30081}})

役立つコマンド群は以下です。

- ノードと Pod の状態を見る
```bash
kubectl get nodes -o wide
```{{copy}}
```bash
kubectl get pods -A -o wide
```{{copy}}
```bash
kubectl -n latency-demo get deploy
```{{copy}}
```bash
kubectl describe nodes
```{{copy}}
- リソース使用量を見る
```bash
kubectl top nodes
```{{copy}}
```bash
kubectl top pods -A
```{{copy}}
```bash
kubectl -n latency-demo top pods
```{{copy}}
- Pod の詳細・イベント確認<br>※pod名をkubectl top pods -Aで確認したNAMEに置き換え
```bash
kubectl -n latency-demo describe pod pod名
```{{copy}}
- Pod のログを確認<br>※pod名をkubectl top pods -Aで確認したNAMEに置き換え
```bash
kubectl -n latency-demo logs pod名
```{{copy}}
- Pod の起動<br>※app名をkubectl -n latency-demo get deployで確認したNAMEに置き換え
```bash
kubectl -n latency-demo scale deploy/app名 --replicas=1
```{{copy}}
- Pod の停止<br>※app名をkubectl -n latency-demo get deployで確認したNAMEに置き換え
```bash
kubectl -n latency-demo scale deploy/app名 --replicas=0
```{{copy}}
- Pod 内へのコマンド実行(psコマンドの例)<br>※pod名をkubectl top pods -Aで確認したNAMEに置き換え
```bash
kubectl -n latency-demo exec pod名 -- ps aux
```{{copy}}
- Pod 内へのログイン<br>※pod名をkubectl top pods -Aで確認したNAMEに置き換え
```bash
kubectl -n latency-demo exec -it pod名 -- /bin/sh
```{{copy}}