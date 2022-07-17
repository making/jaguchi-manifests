## アプリをインターネットに公開する

> ⚠️ 現在、この機能のサポートを中止しています

`*.run.jaguchi.maki.lol`ドメインでデプロイしたアプリにアクセスすることでインターネット経由でアプリにアクセスできます。
ドメインは [DomainMapping](https://knative.dev/docs/serving/services/custom-domains) で追加できます。

### Spring Musicのデプロイ

[こちらのドキュメント](https://github.com/tanzu-japan/jaguchi-manifests/blob/main/docs/onboarding_ja.md#workload%E3%81%AE%E4%BD%9C%E6%88%90)の通りSpring Musicをデプロイする。


```
$ tanzu apps workload get -n ${NAMESPACE} spring-music
# spring-music: Ready
---
lastTransitionTime: "2022-05-17T05:36:01Z"
message: ""
reason: Ready
status: "True"
type: Ready

Pods
NAME                                             STATUS      RESTARTS   AGE
spring-music-00001-deployment-58d65bbb4b-wp9hd   Running     0          62s
spring-music-build-1-build-pod                   Succeeded   0          8m14s
spring-music-config-writer-7qzkb-pod             Succeeded   0          86s

Knative Services
NAME           READY   URL
spring-music   Ready   https://spring-music-making.apps.jaguchi.maki.lol
```

### DomainMappingの作成

デプロイされたspring-musicに`run.jaguchi.maki.lol`ドメインをマッピングします。


```yaml
cat <<EOF > domainmapping.yaml
apiVersion: serving.knative.dev/v1alpha1
kind: DomainMapping
metadata:
  name: spring-music-${NAMESPACE}.run.jaguchi.maki.lol
  namespace: ${NAMESPACE}
spec:
  ref:
    name: spring-music
    kind: Service
    apiVersion: serving.knative.dev/v1
EOF
```

applyします。

```
kubectl apply -f domainmapping.yaml
```

DomainMappingのREADYがTrueになっていればOKです。

```
$ kubectl get domainmapping -n ${NAMESPACE}
NAME                                       URL                                                READY   REASON
spring-music-making.run.jaguchi.maki.lol   https://spring-music-making.run.jaguchi.maki.lol   True    
```

VPNの外で `https://spring-music-${NAMESPACE}.run.jaguchi.maki.lol` にアクセスできることを確認してください。

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/168737317-a50d027c-b630-459f-8009-877bff3ae403.png">

