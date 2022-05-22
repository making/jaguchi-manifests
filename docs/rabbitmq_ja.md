## Tanzu RabbitMQ for Kubernetesインスタンスの作成とバインド

### Rabbitmqインスタンスの作成
https://docs.vmware.com/en/VMware-Tanzu-RabbitMQ-for-Kubernetes/1.2/tanzu-rmq/GUID-kubernetes-operator-using-operator.html#create-a-rabbitmq-instance

RabbitmqClusterリソースのYAMLを作成

```yaml
cat <<EOF > /tmp/demo-rabbitmq.yaml
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: demo-rabbitmq
spec:
  imagePullSecrets:
  - name: tap-registry
EOF
```

applyする。

```yaml
NAMESPACE=<GitHubのアカウント名>
kubectl apply -f /tmp/demo-rabbitmq.yaml -n ${NAMESPACE}
```

次のコマンドで進捗を確認。

```
watch kubectl get sts,pod,svc,secret -n ${NAMESPACE} -o wide -l app.kubernetes.io/name=demo-rabbitmq
```

次のように表示されればOK

```
NAME                                    READY   AGE   CONTAINERS   IMAGES
statefulset.apps/demo-rabbitmq-server   1/1     82s   rabbitmq     registry.tanzu.vmware.com/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo@sha256:f2f2c778062abd0cf2a95baea7cbffccc9eadb4f558c55cfb0eeab96d0deccc3

NAME                         READY   STATUS    RESTARTS   AGE   IP             NODE                                     NOMINATED NODE   READINESS GATES
pod/demo-rabbitmq-server-0   1/1     Running   0          82s   100.96.5.217   jaguchi-workers-52tfd-577c655bfc-dk8jb   <none>           <none>

NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                        AGE   SELECTOR
service/demo-rabbitmq         ClusterIP   100.70.122.155   <none>        15672/TCP,15692/TCP,5672/TCP   84s   app.kubernetes.io/name=demo-rabbitmq
service/demo-rabbitmq-nodes   ClusterIP   None             <none>        4369/TCP,25672/TCP             84s   app.kubernetes.io/name=demo-rabbitmq

NAME                                 TYPE     DATA   AGE
secret/demo-rabbitmq-default-user    Opaque   7      83s
secret/demo-rabbitmq-erlang-cookie   Opaque   1      83s
```

```
$ kubectl get rabbitmqcluster -n ${NAMESPACE} 
NAME            ALLREPLICASREADY   RECONCILESUCCESS   AGE
demo-rabbitmq   True               True               6m57s
```

### (Optional) Kubectl RabbitMQ Pluginのインストール

[knew](https://krew.sigs.k8s.io/docs/user-guide/setup/install/) を事前にインストール。

```
kubectl krew install rabbitmq
```

```
$ kubectl rabbitmq -n ${NAMESPACE} list          
NAME            ALLREPLICASREADY   RECONCILESUCCESS   AGE
demo-rabbitmq   True               True               53m

$ kubectl rabbitmq -n ${NAMESPACE} get demo-rabbitmq
NAME                         READY   STATUS    RESTARTS   AGE
pod/demo-rabbitmq-server-0   1/1     Running   0          54m

NAME                                   DATA   AGE
configmap/demo-rabbitmq-plugins-conf   1      54m
configmap/demo-rabbitmq-server-conf    2      54m

NAME                                    READY   AGE
statefulset.apps/demo-rabbitmq-server   1/1     54m

NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                        AGE
service/demo-rabbitmq         ClusterIP   100.70.122.155   <none>        15672/TCP,15692/TCP,5672/TCP   54m
service/demo-rabbitmq-nodes   ClusterIP   None             <none>        4369/TCP,25672/TCP             54m

NAME                                 TYPE     DATA   AGE
secret/demo-rabbitmq-default-user    Opaque   7      54m
secret/demo-rabbitmq-erlang-cookie   Opaque   1      54m
```

### Management UIにアクセス

次のコマンドでユーザー名とパスワードを確認
```
kubectl get secret -n making demo-rabbitmq-default-user -ojson | jq '.data | map_values(@base64d)'
```

<img width="904" alt="image" src="https://user-images.githubusercontent.com/106908/169693704-d06c8b29-2a31-43e0-a483-d1501bb7475f.png">


`demo-rabbitmq` Serviceの15672に対してport-forwardすれば良いが、Kubectl RabbitMQ Pluginを使うとアクセスが簡単

```
kubectl rabbitmq -n ${NAMESPACE} manage demo-rabbitmq
```

> Kubectl RabbitMQ Pluginがない場合は、次のコマンドで代替可能
> ```
> kubectl port-forward -n ${NAMESPACE} svc/demo-rabbitmq 15672:15672
> ```

ブラウザが起動する
<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169693748-db8dbad5-3ac5-461e-b8d4-2a13138ddaf6.png">

ユーザー名・パスワードを入力してログイン
<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169693790-1bb1abec-90a2-4ee2-981c-b9e6d86608df.png">

### サンプルアプリ(receiver)のデプロイ

Workloadの作成

```
tanzu apps workload apply demo-rabbitmq-receiver \
  --app demo-rabbitmq-receiver \
  --git-repo https://github.com/making/demo-rabbitmq-receiver \
  --git-branch main \
  --type web \
  --build-env BP_JVM_VERSION=17 \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref demo-rabbitmq=rabbitmq.com/v1beta1:RabbitmqCluster:demo-rabbitmq \
  -n ${NAMESPACE}
```

ログを追跡
```
tanzu apps workload tail demo-rabbitmq-receiver -n ${NAMESPACE}
```

進捗を確認
```
watch kubectl get pod,workload,gitrepo,build,taskrun,pod,workload,gitrepo,build,taskrun,imagerepository,app,ksvc,servicebinding,app,ksvc,servicebinding -l app.kubernetes.io/part-of=demo-rabbitmq-receiver -n ${NAMESPACE}
```

次のような出力になればOK (revision 00001は無視)

```
NAME                                                           READY   STATUS      RESTARTS   AGE
pod/demo-rabbitmq-receiver-00002-deployment-6f8bf749dc-nxlzp   2/2     Running     0          114s
pod/demo-rabbitmq-receiver-build-1-build-pod                   0/1     Completed   0          10m
pod/demo-rabbitmq-receiver-config-writer-wb55z-pod             0/1     Completed   0          2m58s

NAME                                        SOURCE                                             SUPPLYCHAIN     READY   REASON   AGE
workload.carto.run/demo-rabbitmq-receiver   https://github.com/making/demo-rabbitmq-receiver   source-to-url   True    Ready    10m

NAME                                                            URL                                                READY   STATUS                                                            AGE
gitrepository.source.toolkit.fluxcd.io/demo-rabbitmq-receiver   https://github.com/making/demo-rabbitmq-receiver   True    Fetched revision: main/6a2158be8766c732ebdd5ceaa0a86ac63afd4055   10m

NAME                                            IMAGE                                                                                                                   SUCCEEDED
build.kpack.io/demo-rabbitmq-receiver-build-1   ghcr.io/jaguchi/demo-rabbitmq-receiver-making@sha256:61d0cee41e112a148eb6a7fbaf3ed2e07f0cbbeac1e53a938fd952684dc25394   True

NAME                                                            SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
taskrun.tekton.dev/demo-rabbitmq-receiver-config-writer-wb55z   True        Succeeded   2m59s       2m47s

NAME                                                                           IMAGE                                                                                       URL                                                                                                                                                                                                                 READY   REASON   AGE
imagerepository.source.apps.tanzu.vmware.com/demo-rabbitmq-receiver-delivery   ghcr.io/jaguchi/demo-rabbitmq-receiver-making-bundle:f33ff900-61f6-484d-b4d8-f9306d269128   http://source-controller-manager-artifact-service.source-system.svc.cluster.local./imagerepository/making/demo-rabbitmq-receiver-delivery/0cbb91773951ca19a965224cf7636c6bb645fbb08b1d6020373bcc06d6509684.tar.gz   True    Ready    10m

NAME                                          DESCRIPTION           SINCE-DEPLOY   AGE
app.kappctrl.k14s.io/demo-rabbitmq-receiver   Reconcile succeeded   118s           10m

NAME                                                 URL                                                           LATESTCREATED                  LATESTREADY                    READY   REASON
service.serving.knative.dev/demo-rabbitmq-receiver   https://demo-rabbitmq-receiver-making.apps.jaguchi.maki.lol   demo-rabbitmq-receiver-00002   demo-rabbitmq-receiver-00002   True    

NAME                                                                    READY   REASON   AGE
servicebinding.servicebinding.io/demo-rabbitmq-receiver-demo-rabbitmq   True    Ready    118s
```

`tanzu apps workload get`でも確認。

```
$ tanzu apps workload get demo-rabbitmq-receiver -n ${NAMESPACE}
# demo-rabbitmq-receiver: Ready
---
lastTransitionTime: "2022-05-22T12:17:49Z"
message: ""
reason: Ready
status: "True"
type: Ready

Services
CLAIM           NAME            KIND              API VERSION
demo-rabbitmq   demo-rabbitmq   RabbitmqCluster   rabbitmq.com/v1beta1

Pods
NAME                                                       STATUS      RESTARTS   AGE
demo-rabbitmq-receiver-00002-deployment-6f8bf749dc-nxlzp   Running     0          4m51s
demo-rabbitmq-receiver-build-1-build-pod                   Succeeded   0          13m
demo-rabbitmq-receiver-config-writer-wb55z-pod             Succeeded   0          5m55s

Knative Services
NAME                     READY   URL
demo-rabbitmq-receiver   Ready   https://demo-rabbitmq-receiver-making.apps.jaguchi.maki.lol
```

↓のログを確認してPostgreSQLに接続できていることを確認。

```
$ kubectl logs -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=demo-rabbitmq-receiver -c workload -n ${NAMESPACE} --tail=1000

Setting Active Processor Count to 4
Calculating JVM memory based on 12545588K available memory
`For more information on this calculation, see https://paketo.io/docs/reference/java-reference/#memory-calculator
Calculated JVM Memory Configuration: -XX:MaxDirectMemorySize=10M -Xmx11952729K -XX:MaxMetaspaceSize=80858K -XX:ReservedCodeCacheSize=240M -Xss1M (Total Memory: 12545588K, Thread Count: 250, Loaded Class Count: 11862, Headroom: 0%)
Enabling Java Native Memory Tracking
Adding 128 container CA certificates to JVM truststore
Spring Cloud Bindings Enabled
Picked up JAVA_TOOL_OPTIONS: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.endpoint.health.show-details=always -Dmanagement.endpoints.web.base-path="/actuator" -Dmanagement.endpoints.web.exposure.include=* -Dmanagement.health.probes.enabled="true" -Dmanagement.server.port="8081" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s" -Djava.security.properties=/layers/paketo-buildpacks_bellsoft-liberica/java-security-properties/java-security.properties -XX:+ExitOnOutOfMemoryError -XX:ActiveProcessorCount=4 -XX:MaxDirectMemorySize=10M -Xmx11952729K -XX:MaxMetaspaceSize=80858K -XX:ReservedCodeCacheSize=240M -Xss1M -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -Dorg.springframework.cloud.bindings.boot.enable=true

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v2.7.0)

2022-05-22 12:19:09.606  INFO 1 --- [           main] c.example.demo.DemoReceiverApplication   : Starting DemoReceiverApplication v0.0.1-SNAPSHOT using Java 17.0.3 on demo-rabbitmq-receiver-00002-deployment-6f8bf749dc-nxlzp with PID 1 (/workspace/BOOT-INF/classes started by cnb in /workspace)
2022-05-22 12:19:09.618  INFO 1 --- [           main] c.example.demo.DemoReceiverApplication   : No active profile set, falling back to 1 default profile: "default"
2022-05-22 12:19:09.696  INFO 1 --- [           main] .BindingSpecificEnvironmentPostProcessor : Creating binding-specific PropertySource from Kubernetes Service Bindings
2022-05-22 12:19:11.211  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2022-05-22 12:19:11.225  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-22 12:19:11.225  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.63]
2022-05-22 12:19:11.316  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2022-05-22 12:19:11.316  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 1617 ms
2022-05-22 12:19:12.409  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2022-05-22 12:19:12.476  INFO 1 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-22 12:19:12.477  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-22 12:19:12.478  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 1 ms
2022-05-22 12:19:12.624  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8081 (http)
2022-05-22 12:19:12.626  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-22 12:19:12.628  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.63]
2022-05-22 12:19:12.648  INFO 1 --- [           main] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring embedded WebApplicationContext
2022-05-22 12:19:12.652  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 235 ms
2022-05-22 12:19:12.671  INFO 1 --- [           main] o.s.b.a.e.web.EndpointLinksResolver      : Exposing 14 endpoint(s) beneath base path '/actuator'
2022-05-22 12:19:12.729  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8081 (http) with context path ''
👇👇👇👇👇👇👇👇👇👇
2022-05-22 12:19:12.735  INFO 1 --- [           main] o.s.a.r.c.CachingConnectionFactory       : Attempting to connect to: [demo-rabbitmq.making.svc:5672]
2022-05-22 12:19:12.805  INFO 1 --- [           main] o.s.a.r.c.CachingConnectionFactory       : Created new connection: rabbitConnectionFactory#32faa16c:0/SimpleConnection@2fd1ad8a [delegate=amqp://default_user_XJ0iKFkls2qx4T6sqDp@100.70.122.155:5672/, localPort= 47490]
👆👆👆👆👆👆👆👆👆👆
2022-05-22 12:19:12.902  INFO 1 --- [           main] c.example.demo.DemoReceiverApplication   : Started DemoReceiverApplication in 3.745 seconds (JVM running for 4.185)
2022-05-22 12:19:13.003  INFO 1 --- [nio-8081-exec-1] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-22 12:19:13.005  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-22 12:19:13.006  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 1 ms
```

Management UIを見ると`hello`というExchangeと
<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169694892-8ce09ad8-35b0-46c1-91da-b5886561e324.png">
`hello.demo`というQueueができている
<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169694901-e2bbf3c0-24b4-467a-b63d-7066d8f80eda.png">

### サンプルアプリ(sender)のデプロイ

Workloadの作成

```
tanzu apps workload apply demo-rabbitmq-sender \
  --app demo-rabbitmq-sender \
  --git-repo https://github.com/making/demo-rabbitmq-sender \
  --git-branch main \
  --type web \
  --build-env BP_JVM_VERSION=17 \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref demo-rabbitmq=rabbitmq.com/v1beta1:RabbitmqCluster:demo-rabbitmq \
  -n ${NAMESPACE}
```

ログを追跡
```
tanzu apps workload tail demo-rabbitmq-sender -n ${NAMESPACE}
```

進捗を確認
```
watch kubectl get pod,workload,gitrepo,build,taskrun,pod,workload,gitrepo,build,taskrun,imagerepository,app,ksvc,servicebinding,app,ksvc,servicebinding -l app.kubernetes.io/part-of=demo-rabbitmq-sender -n ${NAMESPACE}
```

次のような出力になればOK (revision 00001は無視)

```
NAME                                                         READY   STATUS      RESTARTS   AGE
pod/demo-rabbitmq-sender-00002-deployment-5f7cc84c84-m5cdt   2/2     Running     0          77s
pod/demo-rabbitmq-sender-build-1-build-pod                   0/1     Completed   0          11m
pod/demo-rabbitmq-sender-config-writer-8m52p-pod             0/1     Completed   0          3m41s

NAME                                      SOURCE                                           SUPPLYCHAIN     READY   REASON   AGE
workload.carto.run/demo-rabbitmq-sender   https://github.com/making/demo-rabbitmq-sender   source-to-url   True    Ready    11m

NAME                                                          URL                                              READY   STATUS                                                            AGE
gitrepository.source.toolkit.fluxcd.io/demo-rabbitmq-sender   https://github.com/making/demo-rabbitmq-sender   True    Fetched revision: main/65e23e1f2eb7240b86bbca5fcde8d37a0863187d   11m

NAME                                          IMAGE                                                                                                                 SUCCEEDED
build.kpack.io/demo-rabbitmq-sender-build-1   ghcr.io/jaguchi/demo-rabbitmq-sender-making@sha256:4c2780113a75b034c12aa162fe89760482fcde0cb277147923196c6e014d2435   True

NAME                                                          SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
taskrun.tekton.dev/demo-rabbitmq-sender-config-writer-8m52p   True        Succeeded   3m42s       3m31s

NAME                                                                         IMAGE                                                                                     URL                                                                                                                                                                                                               READY   REASON   AGE
imagerepository.source.apps.tanzu.vmware.com/demo-rabbitmq-sender-delivery   ghcr.io/jaguchi/demo-rabbitmq-sender-making-bundle:c046eb17-4bf0-40ba-bb74-b33fb3fa18ae   http://source-controller-manager-artifact-service.source-system.svc.cluster.local./imagerepository/making/demo-rabbitmq-sender-delivery/cd301bc4da1fa8855dd70a29e7ba0e5396fd7a293fe89217ccebd71f1f027261.tar.gz   True    Ready    11m

NAME                                        DESCRIPTION           SINCE-DEPLOY   AGE
app.kappctrl.k14s.io/demo-rabbitmq-sender   Reconcile succeeded   3m13s          11m

NAME                                               URL                                                         LATESTCREATED                LATESTREADY                  READY   REASON
service.serving.knative.dev/demo-rabbitmq-sender   https://demo-rabbitmq-sender-making.apps.jaguchi.maki.lol   demo-rabbitmq-sender-00002   demo-rabbitmq-sender-00002   True    

NAME                                                                  READY   REASON   AGE
servicebinding.servicebinding.io/demo-rabbitmq-sender-demo-rabbitmq   True    Ready    3m14s
```

`tanzu apps workload get`でも確認。



```
$ tanzu apps workload get -n ${NAMESPACE} demo-rabbitmq-sender        

# demo-rabbitmq-sender: Ready
---
lastTransitionTime: "2022-05-22T13:10:53Z"
message: ""
reason: Ready
status: "True"
type: Ready

Services
CLAIM           NAME            KIND              API VERSION
demo-rabbitmq   demo-rabbitmq   RabbitmqCluster   rabbitmq.com/v1beta1

Pods
NAME                                                     STATUS      RESTARTS   AGE
demo-rabbitmq-sender-00002-deployment-5f7cc84c84-m5cdt   Running     0          2m14s
demo-rabbitmq-sender-build-1-build-pod                   Succeeded   0          12m
demo-rabbitmq-sender-config-writer-8m52p-pod             Succeeded   0          4m38s

Knative Services
NAME                   READY   URL
demo-rabbitmq-sender   Ready   https://demo-rabbitmq-sender-making.apps.jaguchi.maki.lol
```

↓のログを確認してPostgreSQLに接続できていることを確認。

```
$ kubectl logs -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=demo-rabbitmq-sender -c workload -n ${NAMESPACE} --tail=1000
Setting Active Processor Count to 4
Calculating JVM memory based on 12512328K available memory
`For more information on this calculation, see https://paketo.io/docs/reference/java-reference/#memory-calculator
Calculated JVM Memory Configuration: -XX:MaxDirectMemorySize=10M -Xmx11919469K -XX:MaxMetaspaceSize=80858K -XX:ReservedCodeCacheSize=240M -Xss1M (Total Memory: 12512328K, Thread Count: 250, Loaded Class Count: 11862, Headroom: 0%)
Enabling Java Native Memory Tracking
Adding 128 container CA certificates to JVM truststore
Spring Cloud Bindings Enabled
Picked up JAVA_TOOL_OPTIONS: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.endpoint.health.show-details=always -Dmanagement.endpoints.web.base-path="/actuator" -Dmanagement.endpoints.web.exposure.include=* -Dmanagement.health.probes.enabled="true" -Dmanagement.server.port="8081" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s" -Djava.security.properties=/layers/paketo-buildpacks_bellsoft-liberica/java-security-properties/java-security.properties -XX:+ExitOnOutOfMemoryError -XX:ActiveProcessorCount=4 -XX:MaxDirectMemorySize=10M -Xmx11919469K -XX:MaxMetaspaceSize=80858K -XX:ReservedCodeCacheSize=240M -Xss1M -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -Dorg.springframework.cloud.bindings.boot.enable=true

  .   ____          _            __ _ _
 /¥¥ / ___'_ __ _ _(_)_ __  __ _ ¥ ¥ ¥ ¥
( ( )¥___ | '_ | '_| | '_ ¥/ _` | ¥ ¥ ¥ ¥
 ¥¥/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_¥__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v2.7.0)

2022-05-22 13:13:25.901  INFO 1 --- [           main] com.example.demo.DemoSenderApplication   : Starting DemoSenderApplication v0.0.1-SNAPSHOT using Java 17.0.3 on demo-rabbitmq-sender-00002-deployment-5f7cc84c84-m5cdt with PID 1 (/workspace/BOOT-INF/classes started by cnb in /workspace)
2022-05-22 13:13:25.904  INFO 1 --- [           main] com.example.demo.DemoSenderApplication   : No active profile set, falling back to 1 default profile: "default"
2022-05-22 13:13:25.978  INFO 1 --- [           main] .BindingSpecificEnvironmentPostProcessor : Creating binding-specific PropertySource from Kubernetes Service Bindings
2022-05-22 13:13:27.416  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2022-05-22 13:13:27.428  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-22 13:13:27.428  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.63]
2022-05-22 13:13:27.507  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2022-05-22 13:13:27.507  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 1521 ms
2022-05-22 13:13:28.639  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2022-05-22 13:13:28.720  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8081 (http)
2022-05-22 13:13:28.721  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-22 13:13:28.721  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.63]
2022-05-22 13:13:28.732  INFO 1 --- [           main] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring embedded WebApplicationContext
2022-05-22 13:13:28.732  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 89 ms
2022-05-22 13:13:28.743  INFO 1 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-22 13:13:28.743  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-22 13:13:28.747  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 1 ms
2022-05-22 13:13:28.768  INFO 1 --- [           main] o.s.b.a.e.web.EndpointLinksResolver      : Exposing 14 endpoint(s) beneath base path '/actuator'
2022-05-22 13:13:28.877  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8081 (http) with context path ''
2022-05-22 13:13:28.948  INFO 1 --- [           main] com.example.demo.DemoSenderApplication   : Started DemoSenderApplication in 3.554 seconds (JVM running for 3.975)
2022-05-22 13:13:29.092  INFO 1 --- [nio-8081-exec-1] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-22 13:13:29.094  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-22 13:13:29.094  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 0 ms
👇👇👇👇👇👇👇👇👇👇
2022-05-22 13:13:29.126  INFO 1 --- [nio-8081-exec-1] o.s.a.r.c.CachingConnectionFactory       : Attempting to connect to: [demo-rabbitmq.making.svc:5672]
2022-05-22 13:13:29.203  INFO 1 --- [nio-8081-exec-1] o.s.a.r.c.CachingConnectionFactory       : Created new connection: rabbitConnectionFactory#48df4071:0/SimpleConnection@7633c73c [delegate=amqp://default_user_XJ0iKFkls2qx4T6sqDp@100.70.122.155:5672/, localPort= 33734]
👆👆👆👆👆👆👆👆👆👆
```
Management UIを見るとConnectionが二つできている

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169697039-f12752a8-5abe-40b7-b8ac-035333ef7e20.png">

### Senderにメッセージを送信

100件メッセージ送信

```
curl https://demo-rabbitmq-sender-${NAMESPACE}.apps.jaguchi.maki.lol/send -d count=100
```

receiverのログを確認。100件メッセージを受信できいればOK

```
$ kubectl logs -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=demo-rabbitmq-receiver -c workload -n ${NAMESPACE} --tail=105
2022-05-22 12:29:21.129  INFO 1 --- [           main] o.s.a.r.c.CachingConnectionFactory       : Created new connection: rabbitConnectionFactory#2bbb44da:0/SimpleConnection@689faf79 [delegate=amqp://default_user_XJ0iKFkls2qx4T6sqDp@100.70.122.155:5672/, localPort= 45058]
2022-05-22 12:29:21.216  INFO 1 --- [           main] c.example.demo.DemoReceiverApplication   : Started DemoReceiverApplication in 3.469 seconds (JVM running for 3.932)
2022-05-22 12:29:21.357  INFO 1 --- [nio-8081-exec-2] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-22 12:29:21.357  INFO 1 --- [nio-8081-exec-2] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-22 12:29:21.359  INFO 1 --- [nio-8081-exec-2] o.s.web.servlet.DispatcherServlet        : Completed initialization in 1 ms
2022-05-22 13:20:02.761  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello1]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=1, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=06249318-205e-1136-a857-3f9e4483eca8, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602761}
2022-05-22 13:20:02.782  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello2]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=2, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=86470ed8-c399-2fbe-d8c6-5d99289e0b9d, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602781}
2022-05-22 13:20:02.783  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello3]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=3, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1704653f-ebea-cec6-f0fe-c8deb8949cdb, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602783}
2022-05-22 13:20:02.784  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello4]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=4, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3b45ef19-2ce7-9754-f7b7-6fc8298fd87b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602784}
2022-05-22 13:20:02.785  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello5]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=5, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=b9771cb4-0d46-08a4-da56-71d7c52a371a, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602785}
2022-05-22 13:20:02.786  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello6]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=6, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1cee8082-8dab-71f8-e925-896e6888d8a2, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602785}
2022-05-22 13:20:02.786  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello7]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=7, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=35557b02-9b42-174f-581d-781c06abb2e0, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602786}
2022-05-22 13:20:02.787  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello8]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=8, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=953864c9-9d27-74ad-c03b-af6123269c48, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602787}
2022-05-22 13:20:02.788  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello9]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=9, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=149779a3-eaa2-f4d8-9b6e-bc42591c8e80, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602788}
2022-05-22 13:20:02.788  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello10]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=10, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4d87f8d7-5033-ac05-cb0a-3ce7d68db714, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602788}
2022-05-22 13:20:02.789  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello11]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=11, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1fec1624-8f68-d270-13d5-50fbdbf63ba5, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602789}
2022-05-22 13:20:02.790  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello12]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=12, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2d39cfc2-db8d-10eb-9c9a-e4873e3eb798, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602790}
2022-05-22 13:20:02.800  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello13]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=13, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=5f47b0e3-5e24-ea0d-7259-337ce9f3e008, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602800}
2022-05-22 13:20:02.802  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello14]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=14, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=5f392347-b32d-ca36-05f9-623158dfe82f, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602802}
2022-05-22 13:20:02.805  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello15]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=15, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1d70d952-6d46-7f69-a992-29c71fde6616, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602805}
2022-05-22 13:20:02.809  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello16]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=16, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4c8f54d5-8e90-30eb-164a-c4566212f8a2, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602808}
2022-05-22 13:20:02.811  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello17]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=17, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=e291badb-106e-15be-e8b5-c09f5c61e375, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602811}
2022-05-22 13:20:02.814  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello18]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=18, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9cee6771-600b-7a25-20d8-5a00d8415f2c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602814}
2022-05-22 13:20:02.815  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello19]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=19, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=78ccf1dc-ddb9-da00-a1a6-7141bbda52c0, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602815}
2022-05-22 13:20:02.817  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello20]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=20, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=38478af2-5e1a-201c-b423-54fc7871acba, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602816}
2022-05-22 13:20:02.821  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello21]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=21, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=e6c3f85f-a917-468a-8406-e9269a28a7d7, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602820}
2022-05-22 13:20:02.822  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello22]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=22, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4a55986a-fdb0-f7be-a3f3-f2a03e0e9a8d, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602822}
2022-05-22 13:20:02.824  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello23]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=23, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=76300e74-8994-e962-8445-7373967a2aa0, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602824}
2022-05-22 13:20:02.824  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello24]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=24, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3b31aabe-f289-fdcd-fe64-6dd167befb8a, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602824}
2022-05-22 13:20:02.826  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello25]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=25, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=b16ea356-d1ac-78a9-cfb1-8ccf8b213618, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602826}
2022-05-22 13:20:02.827  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello26]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=26, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=b3dfa2b9-3377-d67b-17fb-6e3671317fe8, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602827}
2022-05-22 13:20:02.828  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello27]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=27, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=600f4ed2-179c-02c7-d987-95c9985f3d0b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602828}
2022-05-22 13:20:02.829  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello28]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=28, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9ce1c321-f3b1-03f1-7daf-3edb17f04007, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602829}
2022-05-22 13:20:02.830  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello29]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=29, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=8d673d7d-30ad-6066-5102-aa0b18382cdd, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602830}
2022-05-22 13:20:02.831  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello30]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=30, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1ec4449a-a92a-cb44-0302-89a0582c359e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602831}
2022-05-22 13:20:02.833  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello31]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=31, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=7f2034c0-308a-d863-286a-9ef7a93f1a2b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602833}
2022-05-22 13:20:02.835  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello32]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=32, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=a2b0ee59-0ad9-d3c0-b908-ce3571916490, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602834}
2022-05-22 13:20:02.836  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello33]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=33, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=c0c705cf-6d8c-f229-9126-1f7a296c513e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602836}
2022-05-22 13:20:02.838  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello34]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=34, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=d3fcbbff-090c-7684-f07f-738ade13fd0b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602838}
2022-05-22 13:20:02.839  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello35]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=35, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=195f98fb-7c0c-8430-fbcc-f425b2e4a88e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602839}
2022-05-22 13:20:02.840  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello36]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=36, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=97ba7b0e-dcb9-bfdc-39da-7ae75cc136cf, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602839}
2022-05-22 13:20:02.841  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello37]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=37, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=94ec690c-32b2-ed92-1731-6ce8a4d133d1, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602841}
2022-05-22 13:20:02.842  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello38]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=38, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=194879d8-f9cf-2ce6-6650-db22e8900cb0, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602842}
2022-05-22 13:20:02.843  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello39]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=39, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=780a9a7f-a3c4-8df2-d874-e2e79b2c4450, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602843}
2022-05-22 13:20:02.844  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello40]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=40, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=c2df27e4-1483-134d-86f1-7f9dc032c9c3, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602844}
2022-05-22 13:20:02.845  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello41]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=41, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4f7777e3-257a-661a-6d18-755d7390c189, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602845}
2022-05-22 13:20:02.846  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello42]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=42, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3a28d212-229f-c441-ecb2-e9fc60e067c3, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602846}
2022-05-22 13:20:02.848  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello43]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=43, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=e3a591ad-4d48-f818-470a-d67a4a09d450, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602848}
2022-05-22 13:20:02.849  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello44]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=44, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=6bc44d12-59d7-5ff5-2780-75d1862cc989, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602849}
2022-05-22 13:20:02.850  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello45]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=45, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3b4d4e39-ef33-50c5-18b7-43ad7de4e2ef, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602850}
2022-05-22 13:20:02.851  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello46]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=46, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=7de3b2e2-2c16-5c34-0a4b-469a2ed3bbc8, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602851}
2022-05-22 13:20:02.852  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello47]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=47, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=a1f802d7-2121-4ae4-d119-a5cea980e707, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602852}
2022-05-22 13:20:02.853  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello48]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=48, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=dad01779-52cd-c3f3-a51b-d3d79589d951, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602853}
2022-05-22 13:20:02.853  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello49]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=49, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9f979214-3823-0763-a3cb-c915aa1d142a, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602853}
2022-05-22 13:20:02.854  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello50]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=50, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2a8450c8-bf45-25e6-4920-191e38ce3790, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602854}
2022-05-22 13:20:02.855  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello51]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=51, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=fc0d8fa8-c8cc-975b-fe13-ced69facce68, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602855}
2022-05-22 13:20:02.856  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello52]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=52, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=5731b2b8-a8ef-366d-88bd-7157d5b8ec0f, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602856}
2022-05-22 13:20:02.856  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello53]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=53, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=c3c3dea8-a87f-dad8-93f8-a264e39fff5c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602856}
2022-05-22 13:20:02.857  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello54]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=54, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=89d8dad7-83b2-2f7d-319e-0ca968ca6730, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602857}
2022-05-22 13:20:02.859  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello55]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=55, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3b35e6f5-eabc-8d8e-554d-baa414bbb45c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602858}
2022-05-22 13:20:02.860  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello56]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=56, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2ad67cc9-033d-d346-57c3-0daa2ebd9e5e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602859}
2022-05-22 13:20:02.861  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello57]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=57, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=ee823503-e674-96fa-73c4-d6250fe317e0, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602861}
2022-05-22 13:20:02.862  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello58]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=58, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=e3722ec2-1f55-32bd-4994-4fdea5540e74, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602862}
2022-05-22 13:20:02.863  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello59]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=59, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=a601ba66-2f57-7aa4-5ffe-ffcaf1edb951, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602863}
2022-05-22 13:20:02.864  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello60]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=60, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9b733d95-0b28-1f4c-9aee-c8a5892d8f17, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602864}
2022-05-22 13:20:02.865  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello61]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=61, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=6aca73d7-9b22-0e70-c999-9a5b177331c7, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602865}
2022-05-22 13:20:02.866  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello62]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=62, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=7ea9861e-3c9a-5554-1a36-9711d88dfe3c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602866}
2022-05-22 13:20:02.867  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello63]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=63, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=854aaf84-3ff5-5738-a343-a4891d9b0d5f, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602867}
2022-05-22 13:20:02.868  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello64]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=64, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=f3815111-6897-5742-da64-ac4fcd34bb20, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602868}
2022-05-22 13:20:02.869  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello65]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=65, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=7ed3c2ee-6f9c-a527-1dc7-133fe1ef1c41, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602869}
2022-05-22 13:20:02.871  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello66]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=66, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=a3962f75-8262-fd54-2c1b-219ee72af65b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602871}
2022-05-22 13:20:02.872  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello67]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=67, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=202b50aa-c1e4-d681-aa1d-5d43812c087e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602871}
2022-05-22 13:20:02.873  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello68]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=68, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=783de059-c1e5-b968-9faf-2af7e391d7ee, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602873}
2022-05-22 13:20:02.874  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello69]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=69, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=721b0ab7-0aea-dbd5-f87e-198a570d414b, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602873}
2022-05-22 13:20:02.874  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello70]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=70, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9a18388b-9902-935c-063f-b5e6bc74775d, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602874}
2022-05-22 13:20:02.875  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello71]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=71, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=bf02fe52-5f67-67cb-fb70-d3bb03204558, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602875}
2022-05-22 13:20:02.876  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello72]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=72, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=73a60c4e-bfe1-cde5-70bc-a13ab197aa3c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602876}
2022-05-22 13:20:02.877  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello73]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=73, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=8f636173-1407-d501-e2d7-f6c96193343a, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602877}
2022-05-22 13:20:02.878  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello74]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=74, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=acd1236f-2943-4fe7-3001-a87e3f48a3cb, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602878}
2022-05-22 13:20:02.879  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello75]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=75, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=aa74e34b-bfb2-43b5-1f06-e59e8d07bd2a, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602879}
2022-05-22 13:20:02.880  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello76]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=76, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2d81272d-0bce-afa1-d6dc-dc74222d6677, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602880}
2022-05-22 13:20:02.880  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello77]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=77, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1bb1828d-34e3-e31e-62cc-2c3be55d5897, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602880}
2022-05-22 13:20:02.881  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello78]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=78, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1f289dc6-d960-0451-3325-dcfb57161365, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602881}
2022-05-22 13:20:02.882  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello79]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=79, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2968e645-8af0-79c5-9d89-e6d00789df3d, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602882}
2022-05-22 13:20:02.883  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello80]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=80, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=ec55e1b4-4a61-5a0d-59c6-96131bcd0160, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602883}
2022-05-22 13:20:02.884  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello81]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=81, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=5f4d3c88-1462-1433-013b-34aecd5c71d3, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602884}
2022-05-22 13:20:02.885  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello82]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=82, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=3d4627dd-530c-e802-97d2-c4f1ece3b2c8, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602885}
2022-05-22 13:20:02.887  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello83]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=83, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=85089a48-683e-f6c4-fe8b-e507575ead72, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602887}
2022-05-22 13:20:02.888  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello84]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=84, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=fa707c40-27c6-f056-8092-fb5686869461, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602888}
2022-05-22 13:20:02.889  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello85]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=85, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=a3c5e212-5a5b-b58a-46e6-3ff50194424e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602889}
2022-05-22 13:20:02.891  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello86]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=86, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4c1ad0f3-3d6a-5d4e-e394-6795e6499b16, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602891}
2022-05-22 13:20:02.892  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello87]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=87, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=04c53086-00ae-8c69-ca81-ea2d6755d264, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602892}
2022-05-22 13:20:02.893  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello88]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=88, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9de2fe68-499b-088b-d3be-2afa4afcae1c, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602893}
2022-05-22 13:20:02.894  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello89]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=89, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=30ebc2bd-af9a-e2f8-ba74-fe5a671b2733, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602893}
2022-05-22 13:20:02.895  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello90]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=90, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=9656e251-4013-bf74-a05b-5e8a2e75eb05, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602895}
2022-05-22 13:20:02.896  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello91]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=91, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=ef506e10-fb44-03cd-88c3-3a0c1e50bfa1, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602896}
2022-05-22 13:20:02.897  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello92]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=92, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=1f7f64a6-57f3-f322-db2c-b9444f65b5a7, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602897}
2022-05-22 13:20:02.898  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello93]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=93, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=4cd393cf-bbdf-0e25-e570-5ca2e91eacaa, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602898}
2022-05-22 13:20:02.899  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello94]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=94, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=62719796-0314-295c-557a-d958ab26a3ef, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602899}
2022-05-22 13:20:02.900  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello95]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=95, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=8fa399ee-02fd-1b31-c18d-9abf6544c474, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602900}
2022-05-22 13:20:02.901  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello96]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=96, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=c7ded071-fa54-0b80-2022-33057e8c3904, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602901}
2022-05-22 13:20:02.902  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello97]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=97, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=41d7e8bb-25de-8d65-4e49-460f6ede2ae1, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602902}
2022-05-22 13:20:02.903  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello98]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=98, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=f8a4c9cb-30ed-4271-8ba8-a10c45b37c4e, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602903}
2022-05-22 13:20:02.904  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello99]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=99, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=2bf86e14-bbc3-9e90-fc00-8f75233c2ac8, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602904}
2022-05-22 13:20:02.905  INFO 1 --- [ntContainer#0-1] com.example.demo.HelloListener           : payload=Hello[message=hello100]	headers={amqp_receivedDeliveryMode=PERSISTENT, amqp_receivedExchange=hello, amqp_deliveryTag=100, amqp_consumerQueue=hello.demo, amqp_redelivered=false, amqp_receivedRoutingKey=hello, amqp_contentEncoding=UTF-8, id=dd5dc168-daba-f7d3-2948-9ef4bed05449, amqp_consumerTag=amq.ctag-jp5Qoehk6PIjPx7qRM90AA, amqp_lastInBatch=false, contentType=application/json, __TypeId__=com.example.demo.Hello, timestamp=1653225602905}
```

Management UIでメッセージの流れを確認
<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/169697489-ffd120e9-ec0b-4d3e-b412-121483c4949f.png">

### リソースの削除

不要になったら次のコマンドでWorkloadとRabbitMQを削除してください。

```
tanzu apps workload delete demo-rabbitmq-sender -n ${NAMESPACE} -y
tanzu apps workload delete demo-rabbitmq-receiver -n ${NAMESPACE} -y
kubectl delete -f /tmp/demo-rabbitmq.yaml  -n ${NAMESPACE}
```