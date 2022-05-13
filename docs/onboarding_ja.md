## Developerのon-boarding

### 必要なCLIのインストール

以下のCLIを事前にインストールしてください

* [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
* `tanzu` ([TAP版](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap//GUID-install-tanzu-cli.html) or [TCE版](https://tanzucommunityedition.io/docs/v0.12/cli-installation/))
* [`pinniped`](https://pinniped.dev/docs/howto/install-cli/)

### TAP GUIへのアクセス

[tanzu-japan org](https://github.com/tanzu-japan) orgの[jaguchi-users team](https://github.com/orgs/tanzu-japan/teams/jaguchi-users)に所属するメンバーは[TAP GUI](https://tap-gui.jaguchi.maki.lol)にログインできます。

URL: https://tap-gui.jaguchi.maki.lol

<img src="https://user-images.githubusercontent.com/106908/167983482-d0fd3d34-1726-4ebb-8f4d-0d218c0279a9.png">

"SIGN IN"をクリックして、GitHub (Dex) 経由でログインしてください。

https://tap-gui.jaguchi.maki.lol/settings にアクセスして、Profileのユーザー名とEmailが正しく表示されていることを確認してください。

<img src="https://user-images.githubusercontent.com/106908/167986313-02033b48-88d7-4833-ac99-043ce0d8cb55.png">

### Namespaceの作成及びRBACの設定

Developer用のNamespaceの作成とRBACの設定を行います ([参考ドキュメント](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-install-components.html#setup
))。

https://github.com/tanzu-japan/jaguchi-manifests/blob/main/jaguchi/config/platform/tap-users/tap-users-data-values.yaml にアクセスして、編集ボタンをクリックしてください。

<img src="https://user-images.githubusercontent.com/106908/167986932-bbd793ad-b31c-4064-8f0a-771d04109c3e.png">

`users`に次のYAMLを追記してください。

```yaml
- name: <GitHubのアカウント名>
  email: <TAP GUIのProfileに表示されているemailアドレス>
  clusterroles:
  - app-editor
  - edit # (optional)
```
`clusterroles`にはTAPに必要なK8sリソース(Workloadなど)作成するだけで十分な場合は`app-editor`のみを、TAP以外のK8s(Deployment, Podなど)も作成したい場合は`edit`も追加してください。

**記述例**
```yaml
- name: making-bot
  email: makingx+bot@gmail.com
  clusterroles:
  - app-editor
```

<img src="https://user-images.githubusercontent.com/106908/167987196-981c96bc-eec4-4dd9-ad09-91e0dcd785f9.png">

"Propose changes"ボタンを押してください。

<img src="https://user-images.githubusercontent.com/106908/167991752-2e495124-8490-4bd6-b5ea-711b9cdd22b6.png">

YAMLの差分を確認して、"Create pull request"ボタンを押してください。

<img src="https://user-images.githubusercontent.com/106908/167992033-25dc2a12-acfe-4de7-a988-9f24181471a3.png">

もう一度、"Create pull request"ボタンを押してください。
<img src="https://user-images.githubusercontent.com/106908/167992818-b3daba6b-8b6f-48c0-9be4-ac461d4c413d.png">

マージされるまで待ってください。
<img src="https://user-images.githubusercontent.com/106908/167992996-261b2e56-5c6c-4348-92a0-74045bc6c888.png">

マージされると、約1分後にNamespaceやSecret、RoleBindingなどが自動で作成され、K8sクラスタへアクセス可能になります。
<img src="https://user-images.githubusercontent.com/106908/167993294-b819f319-e2c1-45b4-8fed-582aad941a8b.png">

### Kubernetesクラスタへのアクセス

**VMware VPNに接続してください。**


次のYAMLを`$HOME/.kube/jaguchi.yaml`に保存してください。(パスは変えても良いです)

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM2akNDQWRLZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1EVXdPVEUyTURRek1Gb1hEVE15TURVd05qRTJNRGt6TUZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTDBhCndVU3ErOVhaVmR3ek5LR3NOTjFXNWEwRFUxb2t0MVFJeGNaV1J0bkFGL2trM3FRdXl6ZkdlOXMrSWZoeFM3SjUKVUFqeHh0TTlGSk1BQysyeGVvcVdFYzZHQkhpOGJWMlQveEgwOWhvcnFYUk5qQ2g3Z1ZnN2piZUxvcGpFVzAwLwplY0FsTHFUNFM4NEYyQVI0SkhYWDBybTZYSjd4enBLMTRuOHFqakkzTG40OXdoU3V2dWZCbWN4alk3THVvQ0tzCmd0T2lNYkhJcnhLVmFOZGc3aWhyS0s4SnNFNHI0NzVBWXcxSW4vS0RnM3RXYWRVR3NrZkFPTVhXVzZpazhnb3gKSnkvS2xYVVcvRkJGeWx3SkpvR1ZvZ1RIMDBXdjA2eXZQbEI2dit0aVN5Y3BFVi9EazQ1THM1WVo5T1VIUWVFUQpSK2Z4VzFsS00rc1lxQnhCak1rQ0F3RUFBYU5GTUVNd0RnWURWUjBQQVFIL0JBUURBZ0trTUJJR0ExVWRFd0VCCi93UUlNQVlCQWY4Q0FRQXdIUVlEVlIwT0JCWUVGRHJKTzh0amNHYWJjak1VSDZiUUZ1YUlzK1pMTUEwR0NTcUcKU0liM0RRRUJDd1VBQTRJQkFRQ0JRQmV4ckNSa0JxbkhoK053TjUyVUk2djZuSG9tYjNwN0thczcvNFA0U3g2LwpDK3hORUVUYmNJUlVsa296VC9wRWFVTkFNODRDQ2ttQVgvOElDZDBhR1lMcFpwM0xWQzYzYmRDUlZscDBHY1JjCjZmZDNKeStXL0hZMlppQVpLM3NHUUwwcXpJN01pdUlpa2llUlFQekVlM2JhVHk0ZE9ScCtJN2I5cFV5Y09KR0EKVmxMN3BVLzhDUnZFUXlhZjR1MjUrU2d5SWpwdmU5cXhqT28xS2VUNjVoQ3g2b3lDMllMSDFmSmNRSEtGbERsdgpJbVNIejNaS1ExQm9oeEdHQ01JYXhOVkR5YkM1aW9LOWNlS29Rd2FIbmF6akhHYWo0NlljYStkWGpvNkhVYU8rClpxeThJd002T3lLcXh5RU9JNGNTWm45QmxNZlFJdVgybml4WWdsRHAKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
    server: https://10.90.21.195:6443
  name: 10.90.21.195-pinniped
contexts:
- context:
    cluster: 10.90.21.195-pinniped
    user: local-pinniped
  name: jaguchi-pinniped
current-context: jaguchi-pinniped
kind: Config
preferences: {}
users:
- name: local-pinniped
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - login
      - oidc
      - --enable-concierge
      - --concierge-api-group-suffix=pinniped.dev
      - --concierge-authenticator-name=dex-jwt-authenticator
      - --concierge-authenticator-type=jwt
      - --concierge-endpoint=https://10.90.21.195:6443
      - --concierge-ca-bundle-data=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM2akNDQWRLZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1EVXdPVEUyTURRek1Gb1hEVE15TURVd05qRTJNRGt6TUZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTDBhCndVU3ErOVhaVmR3ek5LR3NOTjFXNWEwRFUxb2t0MVFJeGNaV1J0bkFGL2trM3FRdXl6ZkdlOXMrSWZoeFM3SjUKVUFqeHh0TTlGSk1BQysyeGVvcVdFYzZHQkhpOGJWMlQveEgwOWhvcnFYUk5qQ2g3Z1ZnN2piZUxvcGpFVzAwLwplY0FsTHFUNFM4NEYyQVI0SkhYWDBybTZYSjd4enBLMTRuOHFqakkzTG40OXdoU3V2dWZCbWN4alk3THVvQ0tzCmd0T2lNYkhJcnhLVmFOZGc3aWhyS0s4SnNFNHI0NzVBWXcxSW4vS0RnM3RXYWRVR3NrZkFPTVhXVzZpazhnb3gKSnkvS2xYVVcvRkJGeWx3SkpvR1ZvZ1RIMDBXdjA2eXZQbEI2dit0aVN5Y3BFVi9EazQ1THM1WVo5T1VIUWVFUQpSK2Z4VzFsS00rc1lxQnhCak1rQ0F3RUFBYU5GTUVNd0RnWURWUjBQQVFIL0JBUURBZ0trTUJJR0ExVWRFd0VCCi93UUlNQVlCQWY4Q0FRQXdIUVlEVlIwT0JCWUVGRHJKTzh0amNHYWJjak1VSDZiUUZ1YUlzK1pMTUEwR0NTcUcKU0liM0RRRUJDd1VBQTRJQkFRQ0JRQmV4ckNSa0JxbkhoK053TjUyVUk2djZuSG9tYjNwN0thczcvNFA0U3g2LwpDK3hORUVUYmNJUlVsa296VC9wRWFVTkFNODRDQ2ttQVgvOElDZDBhR1lMcFpwM0xWQzYzYmRDUlZscDBHY1JjCjZmZDNKeStXL0hZMlppQVpLM3NHUUwwcXpJN01pdUlpa2llUlFQekVlM2JhVHk0ZE9ScCtJN2I5cFV5Y09KR0EKVmxMN3BVLzhDUnZFUXlhZjR1MjUrU2d5SWpwdmU5cXhqT28xS2VUNjVoQ3g2b3lDMllMSDFmSmNRSEtGbERsdgpJbVNIejNaS1ExQm9oeEdHQ01JYXhOVkR5YkM1aW9LOWNlS29Rd2FIbmF6akhHYWo0NlljYStkWGpvNkhVYU8rClpxeThJd002T3lLcXh5RU9JNGNTWm45QmxNZlFJdVgybml4WWdsRHAKLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
      - --issuer=https://dex.jaguchi.maki.lol
      - --client-id=pinniped-cli
      - --scopes=openid,email,groups
      - --listen-port=12345
      - --request-audience=pinniped-cli
      command: /usr/local/bin/pinniped
      env: []
      installHint: The pinniped CLI does not appear to be installed.  See https://get.pinniped.dev/cli
        for more details
      provideClusterInfo: true
```

保存したファイルパスを環境変数`KUBECONFIG`に設定してください。

```
export KUBECONFIG=$HOME/.kube/jaguchi.yaml
```

この状態で、次のコマンドを実行してください。

```
kubectl get pod
```

ブラウザが立ち上がり、GitHubのログインが求められます。ログインができたら`you have been logged in and may now close this tab`というメッセージがブラウザ上に出力されます。

<img src="https://user-images.githubusercontent.com/106908/167994365-534cf9df-4169-473b-9659-6ca22c131a30.png">

コンソールには次のようなメッセージが出力されます。`default` namespaceにアクセスする権限が与えられていないので、`Forbidden`と`User "自分のメールアドレス"`が出力されていればOKです。

```
Error from server (Forbidden): pods is forbidden: User "makingx+bot@gmail.com" cannot list resource "pods" in API group "" in the namespace "default"
```

次に`<GitHubのアカウント名>` namespaceにアクセスします。
```
kubectl get pod -n <GitHubのアカウント名>
```

**実行例**
```
$ kubectl get pod -n making-bot
No resources found in making-bot namespace.
```

`<GitHubのアカウント名>` namespaceにはPodの読み取り権限があるため、`No resources found in making-bot namespace.`というメッセージが出力されます。

### Workloadの作成
次のコマンドでサンプルアプリケーションをデプロイします。

```
NAMESPACE=<GitHubのアカウント名>

tanzu apps workload apply spring-music \
  --app spring-music \
  --git-repo https://github.com/tanzu-japan/spring-music \
  --git-branch tanzu \
  --type web \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n ${NAMESPACE} -y
tanzu apps workload tail spring-music -n ${NAMESPACE}
```

別のターミナルを開いて次のコマンドを実行しておくと進捗がわかりやすいです。
```
export KUBECONFIG=$HOME/.kube/jaguchi.yaml
NAMESPACE=<GitHubのアカウント名>

watch kubectl get pod,workload,gitrepo,build,taskrun,app,ksvc -n ${NAMESPACE}
```

次のようなログが出力され始めればOKです。5-10分待ってください。

<img width="1024" src="https://user-images.githubusercontent.com/106908/167995983-ad2c45d6-a609-4cd9-9f5b-9e0a383e6bab.png">

https://tap-gui.jaguchi.maki.lol/supply-chain にアクセスすると自分のWorkloadが表示されます。

<img src="https://user-images.githubusercontent.com/106908/167996205-badcca0e-c274-40d3-a1d7-d574565a12c6.png">

自分のWorloadを選択すると、Supply Chainの進捗を確認できます。
<img src="https://user-images.githubusercontent.com/106908/167996416-87e4085b-48e3-42e0-86e0-5f828aea934f.png">

初回のビルドは8分ほどかかります。WorkloadのSTATUSがReadyになったら、次のコマンドを実行してください。

```
$ tanzu apps workload get spring-music -n ${NAMESPACE}
# spring-music: Ready
---
lastTransitionTime: "2022-05-12T05:10:24Z"
message: ""
reason: Ready
status: "True"
type: Ready

Pods
NAME                                             STATUS      RESTARTS   AGE
spring-music-00001-deployment-7ddd7c4b55-95w74   Running     0          3m53s
spring-music-build-1-build-pod                   Succeeded   0          10m
spring-music-config-writer-wpq9s-pod             Succeeded   0          4m49s

Knative Services
NAME           READY   URL
spring-music   Ready   https://spring-music-making-bot.apps.jaguchi.maki.lol
```

Knative ServicesのURL(`https://spring-music-<GitHubのアカウント名>.apps.jaguchi.maki.lol`)にアクセスし、アプリの画面が表示されればOKです。

<img src="https://user-images.githubusercontent.com/106908/167996804-0aa9f275-6412-454b-8453-cfb5a543e34e.png">


動作確認できたら次のコマンドでWorkloadを削除してください。
```
tanzu apps workload delete spring-music -n ${NAMESPACE} -y
```