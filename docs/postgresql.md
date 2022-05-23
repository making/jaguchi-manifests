## Create and bind a Tanzu SQL with PostgreSQL instance

### Create a PostgreSQL Instance

https://docs.vmware.com/en/VMware-Tanzu-SQL-with-Postgres-for-Kubernetes/1.7/tanzu-postgres-k8s/GUID-create-delete-postgres.html

Create manifest. Click [here](https://docs.vmware.com/en/VMware-Tanzu-SQL-with-Postgres-for-Kubernetes/1.7/tanzu-postgres-k8s/GUID-postgres-crd-reference.html) for details on the manifest .

```yaml
cat <<EOF > /tmp/music-db.yaml 
apiVersion: sql.tanzu.vmware.com/v1
kind: Postgres
metadata:
  name: music-db
spec:
  storageClassName: k8s-storage
  storageSize: 1Gi
  cpu: "0.25"
  memory: 256Mi
  imagePullSecret:
    name: tap-registry
  monitorStorageClassName: k8s-storage
  monitorStorageSize: 1Gi
  resources:
    monitor:
      limits:
        cpu: 256m
        memory: 256Mi
      requests:
        cpu: 128m
        memory: 128Mi
  pgConfig:
    username: pgadmin
    appUser: music
    dbname: music
  postgresVersion:
    name: postgres-14  
  serviceType: ClusterIP
  highAvailability:
    enabled: false
EOF
```

apply
```
NAMESPACE=<GitHub Account Name>
kubectl apply -f /tmp/music-db.yaml  -n ${NAMESPACE}
```

Check the progress with the command ↓

```
watch kubectl get postgres,pod,sts,svc,pvc,certificate,secret -l postgres-instance=music-db -n ${NAMESPACE}  
```


If it looks like ↓, it's OK

```
NAME                                     STATUS    DB VERSION   BACKUP LOCATION   AGE
postgres.sql.tanzu.vmware.com/music-db   Running   14.2                           5m39s

NAME                     READY   STATUS    RESTARTS   AGE
pod/music-db-0           5/5     Running   0          3m11s
pod/music-db-monitor-0   4/4     Running   0          5m27s

NAME                                READY   AGE
statefulset.apps/music-db           1/1     3m12s
statefulset.apps/music-db-monitor   1/1     5m39s

NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/music-db         ClusterIP   100.67.177.121   <none>        5432/TCP   5m40s
service/music-db-agent   ClusterIP   None             <none>        <none>     5m40s

NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/music-db-monitor-music-db-monitor-0   Bound    pvc-17a62708-df99-4b28-acca-9f5ef34a24a1   1Gi        RWO            k8s-storage    5m30s
persistentvolumeclaim/music-db-pgdata-music-db-0            Bound    pvc-58f5ef89-c0c7-41a5-856b-d8c84e2d65b6   1Gi        RWO            k8s-storage    3m13s

NAME                                                            READY   SECRET                         AGE
certificate.cert-manager.io/music-db-internal-ssl-certificate   True    music-db-internal-ssl-secret   5m41s
certificate.cert-manager.io/music-db-metrics-tls-certificate    True    music-db-metrics-tls-secret    5m40s

NAME                                  TYPE                           DATA   AGE
secret/music-db-app-user-db-secret    servicebinding.io/postgresql   8      5m41s
secret/music-db-db-secret             Opaque                         5      5m41s
secret/music-db-empty-secret          Opaque                         0      5m41s
secret/music-db-internal-ssl-secret   kubernetes.io/tls              3      5m40s
secret/music-db-metrics-secret        Opaque                         4      5m41s
secret/music-db-metrics-tls-secret    kubernetes.io/tls              3      5m39s
secret/music-db-monitor-secret        Opaque                         4      5m41s
secret/music-db-pgbackrest-secret     Opaque                         3      5m41s
```

### Access PostgreSQL with psql

https://docs.vmware.com/en/VMware-Tanzu-SQL-with-Postgres-for-Kubernetes/1.7/tanzu-postgres-k8s/GUID-accessing.html

```
$ kubectl exec -it music-db-0 -n ${NAMESPACE} -- bash -c psql           
Defaulted container "pg-container" out of: pg-container, instance-logging, reconfigure-instance, postgres-metrics-exporter, postgres-sidecar
psql (14.2 (VMware Postgres 14.2.1))
Type "help" for help.

postgres=# \d
                 List of relations
 Schema |          Name           | Type |  Owner   
--------+-------------------------+------+----------
 public | pg_stat_statements      | view | postgres
 public | pg_stat_statements_info | view | postgres
(2 rows)

postgres=# \l
                                 List of databases
   Name    |  Owner   | Encoding | Collate |  Ctype  |      Access privileges       
-----------+----------+----------+---------+---------+------------------------------
 music     | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =Tc/postgres                +
           |          |          |         |         | postgres=CTc/postgres       +
           |          |          |         |         | music=CTc/postgres
 postgres  | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =Tc/postgres                +
           |          |          |         |         | postgres=CTc/postgres       +
           |          |          |         |         | postgres_exporter=c/postgres
 template0 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres                 +
           |          |          |         |         | postgres=CTc/postgres
 template1 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres                 +
           |          |          |         |         | postgres=CTc/postgres
(4 rows)

postgres=# select now();
              now              
-------------------------------
 2022-05-16 05:24:32.918021+00
(1 row)

postgres=# 
```

### Create the Service Bind music-db to spring-music app


https://docs.vmware.com/en/VMware-Tanzu-SQL-with-Postgres-for-Kubernetes/1.7/tanzu-postgres-k8s/GUID-creating-service-bindings.html

Create a Workload

```
tanzu apps workload apply spring-music \
  --app spring-music \
  --git-repo https://github.com/tanzu-japan/spring-music \
  --git-branch tanzu \
  --type web \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref music-db=sql.tanzu.vmware.com/v1:Postgres:music-db \
  -n ${NAMESPACE}
```

Check the log with ↓


```
tanzu apps workload tail spring-music -n ${NAMESPACE}
```

Check the progress with ↓


```
watch kubectl get pod,workload,gitrepo,build,taskrun,pod,workload,gitrepo,build,taskrun,imagerepository,app,ksvc,servicebinding,app,ksvc,servicebinding -l app.kubernetes.io/part-of=spring-music -n ${NAMESPACE}
```

If the result is like ↓, it's OK


```
NAME                                                 READY   STATUS      RESTARTS   AGE
pod/spring-music-00002-deployment-86c9569b7c-9xhhp   2/2     Running     0          6m15s
pod/spring-music-build-1-build-pod                   0/1     Completed   0          24m
pod/spring-music-config-writer-jnp85-pod             0/1     Completed   0          17m

NAME                              SOURCE                                        SUPPLYCHAIN     READY   REASON   AGE
workload.carto.run/spring-music   https://github.com/tanzu-japan/spring-music   source-to-url   True    Ready    25m

NAME                                                  URL                                           READY   STATUS                                                             AGE
gitrepository.source.toolkit.fluxcd.io/spring-music   https://github.com/tanzu-japan/spring-music   True    Fetched revision: tanzu/7a7641687498e837a34a3e07964bab589285084d   24m

NAME                                  IMAGE                                                                                                         SUCCEEDED
build.kpack.io/spring-music-build-1   ghcr.io/jaguchi/spring-music-making@sha256:7ff5d6901548edee5e44fc0c8144427b675c311a30435290d2cdf0a8fb2a3808   True

NAME                                                  SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
taskrun.tekton.dev/spring-music-config-writer-jnp85   True        Succeeded   17m         17m

NAME                                                                 IMAGE                                                                             URL                                                                                                                                                                                                       READY   REASON   AGE
imagerepository.source.apps.tanzu.vmware.com/spring-music-delivery   ghcr.io/jaguchi/spring-music-making-bundle:f2b7cb11-2c1f-40cb-84ba-6040a5175865   http://source-controller-manager-artifact-service.source-system.svc.cluster.local./imagerepository/making/spring-music-delivery/a1982ae0ecca8a2970f1daa8ce97d9e08cb2791e4db263e4547fc753b38abe55.tar.gz   True    Ready    24m

NAME                                DESCRIPTION           SINCE-DEPLOY   AGE
app.kappctrl.k14s.io/spring-music   Reconcile succeeded   6m20s          24m

NAME                                       URL                                                 LATESTCREATED        LATESTREADY          READY   REASON
service.serving.knative.dev/spring-music   https://spring-music-making.apps.jaguchi.maki.lol   spring-music-00002   spring-music-00002   True    

NAME                                                     READY   REASON   AGE
servicebinding.servicebinding.io/spring-music-music-db   True    Ready    6m19s
```

Check `tanzu apps workload get` as well.

```
$ tanzu apps workload get spring-music -n ${NAMESPACE}
# spring-music: Ready
---
lastTransitionTime: "2022-05-16T05:40:19Z"
message: ""
reason: Ready
status: "True"
type: Ready

Services
CLAIM      NAME       KIND       API VERSION
music-db   music-db   Postgres   sql.tanzu.vmware.com/v1

Pods
NAME                                             STATUS      RESTARTS   AGE
spring-music-00002-deployment-86c9569b7c-9xhhp   Running     0          6m48s
spring-music-build-1-build-pod                   Succeeded   0          25m
spring-music-config-writer-jnp85-pod             Succeeded   0          18m

Knative Services
NAME           READY   URL
spring-music   Ready   https://spring-music-making.apps.jaguchi.maki.lol
```


Check the log of ↓ and confirm that you can connect to PostgreSQL.

```
$ kubectl logs -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-music -c workload -n ${NAMESPACE} --tail=1000
Setting Active Processor Count to 4
Calculating JVM memory based on 13651632K available memory
`For more information on this calculation, see https://paketo.io/docs/reference/java-reference/#memory-calculator
Calculated JVM Memory Configuration: -XX:MaxDirectMemorySize=10M -Xmx13006199K -XX:MaxMetaspaceSize=133432K -XX:ReservedCodeCacheSize=240M -Xss1M (Total Memory: 13651632K, Thread Count: 250, Loaded Class Count: 21144, Headroom: 0%)
Enabling Java Native Memory Tracking
Adding 128 container CA certificates to JVM truststore
Spring Cloud Bindings Enabled
Picked up JAVA_TOOL_OPTIONS: -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.endpoint.health.show-details=always -Dmanagement.endpoints.web.base-path="/actuator" -Dmanagement.endpoints.web.exposure.include=* -Dmanagement.health.probes.enabled="true" -Dmanagement.server.port="8081" -Dserver.port="8080" -Dserver.shutdown.grace-period="24s" -Djava.security.properties=/layers/paketo-buildpacks_bellsoft-liberica/java-security-properties/java-security.properties -XX:+ExitOnOutOfMemoryError -XX:ActiveProcessorCount=4 -XX:MaxDirectMemorySize=10M -Xmx13006199K -XX:MaxMetaspaceSize=133432K -XX:ReservedCodeCacheSize=240M -Xss1M -XX:+UnlockDiagnosticVMOptions -XX:NativeMemoryTracking=summary -XX:+PrintNMTStatistics -Dorg.springframework.cloud.bindings.boot.enable=true

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v2.6.7)

👇👇👇👇👇👇👇👇👇👇
2022-05-16 05:52:01.878  INFO 1 --- [           main] .m.c.SpringApplicationContextInitializer : Found bindings [postgresql]
2022-05-16 05:52:01.883  INFO 1 --- [           main] .m.c.SpringApplicationContextInitializer : Setting service profile postgresql
👆👆👆👆👆👆👆👆👆👆
2022-05-16 05:52:01.891  INFO 1 --- [           main] o.c.samples.music.Application            : Starting Application using Java 11.0.15 on spring-music-00002-deployment-86c9569b7c-9xhhp with PID 1 (/workspace/BOOT-INF/classes started by cnb in /workspace)
2022-05-16 05:52:01.893  INFO 1 --- [           main] o.c.samples.music.Application            : The following 1 profile is active: "postgresql"
2022-05-16 05:52:01.957  INFO 1 --- [           main] .BindingSpecificEnvironmentPostProcessor : Creating binding-specific PropertySource from Kubernetes Service Bindings
2022-05-16 05:52:03.328  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Multiple Spring Data modules found, entering strict repository configuration mode!
2022-05-16 05:52:03.334  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Bootstrapping Spring Data JPA repositories in DEFAULT mode.
2022-05-16 05:52:03.585  INFO 1 --- [           main] .s.d.r.c.RepositoryConfigurationDelegate : Finished Spring Data repository scanning in 231 ms. Found 1 JPA repository interfaces.
2022-05-16 05:52:04.308  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2022-05-16 05:52:04.324  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-16 05:52:04.325  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.62]
2022-05-16 05:52:04.422  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2022-05-16 05:52:04.423  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 2462 ms
2022-05-16 05:52:04.774  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Starting...
2022-05-16 05:52:06.243  INFO 1 --- [           main] com.zaxxer.hikari.HikariDataSource       : HikariPool-1 - Start completed.
2022-05-16 05:52:06.368  INFO 1 --- [           main] o.hibernate.jpa.internal.util.LogHelper  : HHH000204: Processing PersistenceUnitInfo [name: default]
2022-05-16 05:52:06.459  INFO 1 --- [           main] org.hibernate.Version                    : HHH000412: Hibernate ORM core version 5.6.8.Final
2022-05-16 05:52:06.680  INFO 1 --- [           main] o.hibernate.annotations.common.Version   : HCANN000001: Hibernate Commons Annotations {5.1.2.Final}
👇👇👇👇👇👇👇👇👇👇
2022-05-16 05:52:06.869  INFO 1 --- [           main] org.hibernate.dialect.Dialect            : HHH000400: Using dialect: org.hibernate.dialect.PostgreSQL10Dialect
👆👆👆👆👆👆👆👆👆👆
2022-05-16 05:52:08.623  INFO 1 --- [           main] o.h.e.t.j.p.i.JtaPlatformInitiator       : HHH000490: Using JtaPlatform implementation: [org.hibernate.engine.transaction.jta.platform.internal.NoJtaPlatform]
2022-05-16 05:52:08.638  INFO 1 --- [           main] j.LocalContainerEntityManagerFactoryBean : Initialized JPA EntityManagerFactory for persistence unit 'default'
2022-05-16 05:52:09.097  WARN 1 --- [           main] JpaBaseConfiguration$JpaWebConfiguration : spring.jpa.open-in-view is enabled by default. Therefore, database queries may be performed during view rendering. Explicitly configure spring.jpa.open-in-view to disable this warning
2022-05-16 05:52:09.396  INFO 1 --- [           main] o.s.b.a.w.s.WelcomePageHandlerMapping    : Adding welcome page: class path resource [static/index.html]
2022-05-16 05:52:09.926  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2022-05-16 05:52:10.029  INFO 1 --- [nio-8080-exec-1] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-16 05:52:10.030  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-16 05:52:10.034  INFO 1 --- [nio-8080-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 3 ms
2022-05-16 05:52:10.081  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8081 (http)
2022-05-16 05:52:10.085  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2022-05-16 05:52:10.087  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.62]
2022-05-16 05:52:10.122  INFO 1 --- [           main] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring embedded WebApplicationContext
2022-05-16 05:52:10.122  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 189 ms
2022-05-16 05:52:10.150  INFO 1 --- [           main] o.s.b.a.e.web.EndpointLinksResolver      : Exposing 13 endpoint(s) beneath base path '/actuator'
2022-05-16 05:52:10.215  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8081 (http) with context path ''
2022-05-16 05:52:10.245  INFO 1 --- [           main] o.c.samples.music.Application            : Started Application in 9.085 seconds (JVM running for 9.843)
2022-05-16 05:52:12.033  INFO 1 --- [nio-8081-exec-1] o.a.c.c.C.[Tomcat-1].[localhost].[/]     : Initializing Spring DispatcherServlet 'dispatcherServlet'
2022-05-16 05:52:12.033  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Initializing Servlet 'dispatcherServlet'
2022-05-16 05:52:12.036  INFO 1 --- [nio-8081-exec-1] o.s.web.servlet.DispatcherServlet        : Completed initialization in 3 ms
```

### Check the behavior

Go to `https://spring-music-${NAMESPACE}.apps.jaguchi.maki.lol` 

Press the ℹ️ button on the top right and you will see that PostgreSQL is bound

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/168529265-741b7c20-545c-434f-ba71-72f3419ed20e.png">


Add Album

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/168528692-9ce6eed7-4c4f-43d9-b300-95af5bbee965.png">

```
kubectl delete pod -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-music -n ${NAMESPACE}
```

Confirm that the data remains even after deletion.

<img width="1024" alt="スクリーンショット 2022-05-16 15 02 49" src="https://user-images.githubusercontent.com/106908/168529101-9d716f8e-37d4-41fb-9cf7-fce847c01080.png">

### Delete resources

Delete the Workload and database with the following command when you no longer need it.

```
tanzu apps workload delete spring-music -n ${NAMESPACE} -y
kubectl delete -f /tmp/music-db.yaml  -n ${NAMESPACE}
```
