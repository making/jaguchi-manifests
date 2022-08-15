## Add test to Supply Chain

In addition to [Out of the Box Supply Chain Basic](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap//GUID-scc-ootb-supply-chain-basic.html), Jaguchi also offers [Out of the Box Supply Chain with Testing](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap//GUID-scc-ootb-supply-chain-testing.html).

Jaguchi is [customized](https://github.com/tanzu-japan/jaguchi-manifests/commit/f4f10ad50fe5dff1f206faece2d011ec7dc3fa6a) to allow you to configure [multiple Pipelines](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap//GUID-scc-ootb-supply-chain-testing.html#multiple-pl) for your namespace. Whereas the TAP documentation identifies Pipeline by using `apps.tanzu.vmware.com/language` label, Jaguchi uses `apps.jaguchi.maki.lol/test-type`.

Create your own Pipeline as you like. Here are some use cases.

### Testing with Maven

Create the following pipeline.

```yaml
cat <<'EOF' > pipeline-maven.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: maven-test-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test
    apps.jaguchi.maki.lol/test-type: maven-jdk-17
spec:
  params:
  - name: source-url
  - name: source-revision
  tasks:
  - name: test
    params:
    - name: source-url
      value: $(params.source-url)
    - name: source-revision
      value: $(params.source-revision)
    taskSpec:
      params:
      - name: source-url
      - name: source-revision
      steps:
      - name: test
        image: eclipse-temurin:17
        script: |-
          set -ex
          cd `mktemp -d`
          curl -s $(params.source-url) | tar -xzvf -
          ./mvnw clean test -V --no-transfer-progress
EOF
```

```
NAMESPACE=...

kubectl apply -f pipeline-maven.yaml -n ${NAMESPACE}
```

Create Workload as follows:

```
tanzu apps workload apply hello-servlet \
  --app hello-servlet \
  --git-repo https://github.com/making/hello-servlet \
  --git-branch master \
  --type web \
  --label apps.tanzu.vmware.com/has-tests=true \
  --label apps.jaguchi.maki.lol/test-type=maven-jdk-17 \
  -n ${NAMESPACE} -y

tanzu apps workload tail hello-servlet -n ${NAMESPACE}
```

OK if the test is successful and the image is built

```
$ kubectl get gitrepo,pipelinerun,build -n ${NAMESPACE} -l app.kubernetes.io/part-of=hello-servlet
NAME                                                   URL                                       READY   STATUS                                                              AGE
gitrepository.source.toolkit.fluxcd.io/hello-servlet   https://github.com/making/hello-servlet   True    Fetched revision: master/10c1f4fe94bf8e0609b977a9fb273dc6fd223a6e   1h   

NAME                                         SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
pipelinerun.tekton.dev/hello-servlet-tjvmq   True        Succeeded   1h          1h   

NAME                                   IMAGE                                                                                                          SUCCEEDED
build.kpack.io/hello-servlet-build-1   ghcr.io/jaguchi/hello-servlet-making@sha256:48fd6872e90f29ab13b5256bf6b778c9fd1a24eb9db47e1de9b78749a39d6c6e   True
```

After checking, delete unnecessary Workload.

```
tanzu apps workload delete hello-servlet -n ${NAMESPACE} -y
```

### Testing with Gradle

Create the following pipeline.

```yaml
cat <<'EOF' > pipeline-gradle.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: gradle-test-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test
    apps.jaguchi.maki.lol/test-type: gradle-jdk-17
spec:
  params:
  - name: source-url
  - name: source-revision
  tasks:
  - name: test
    params:
    - name: source-url
      value: $(params.source-url)
    - name: source-revision
      value: $(params.source-revision)
    taskSpec:
      params:
      - name: source-url
      - name: source-revision
      steps:
      - name: test
        image: eclipse-temurin:17
        script: |-
          set -ex
          cd `mktemp -d`
          curl -s $(params.source-url) | tar -xzvf -
          ./gradlew --no-daemon test
EOF
```

```
NAMESPACE=...

kubectl apply -f pipeline-gradle.yaml -n ${NAMESPACE}
```

Create Workload as follows:

```
tanzu apps workload apply spring-music \
  --app spring-music \
  --git-repo https://github.com/tanzu-japan/spring-music \
  --git-branch tanzu \
  --type web \
  --label apps.tanzu.vmware.com/has-tests=true \
  --label apps.jaguchi.maki.lol/test-type=gradle-jdk-17 \
  -n ${NAMESPACE} -y

tanzu apps workload tail spring-music -n ${NAMESPACE}
```

OK if the test is successful and the image is built

```
$ kubectl get gitrepo,pipelinerun,build -n ${NAMESPACE} -l app.kubernetes.io/part-of=spring-music
NAME                                                  URL                                           READY   STATUS                                                             AGE
gitrepository.source.toolkit.fluxcd.io/spring-music   https://github.com/tanzu-japan/spring-music   True    Fetched revision: tanzu/7a7641687498e837a34a3e07964bab589285084d   1h

NAME                                        SUCCEEDED   REASON      STARTTIME   COMPLETIONTIME
pipelinerun.tekton.dev/spring-music-fk2g8   True        Succeeded   1h          1h

NAME                                  IMAGE                                                                                                         SUCCEEDED
build.kpack.io/spring-music-build-1   ghcr.io/jaguchi/spring-music-making@sha256:408f63b5957152254f88b091564d2fdaf14149f28cf35698814bc8bf617dc8c9   True
```

After checking, delete unnecessary Workload.

```
tanzu apps workload delete spring-music -n ${NAMESPACE} -y
```

### How to use the cache

#### Maven

```yaml
NAMESPACE=...

cat <<EOF > hello-servlet-pipeline-cache-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hello-servlet-pipeline-cache
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: "1Gi"
EOF

kubectl apply -f hello-servlet-pipeline-cache-pvc.yaml -n ${NAMESPACE}
```

```yaml
cat <<'EOF' > pipeline-maven.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: maven-test-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test
    apps.jaguchi.maki.lol/test-type: maven-jdk-17
spec:
  params:
  - name: source-url
  - name: source-revision
  workspaces:
  - name: cache
  tasks:
  - name: test
    params:
    - name: source-url
      value: $(params.source-url)
    - name: source-revision
      value: $(params.source-revision)
    workspaces:
    - name: cache
      workspace: cache
    taskSpec:
      params:
      - name: source-url
      - name: source-revision
      workspaces:
      - name: cache
      steps:
      - name: test
        image: eclipse-temurin:17
        script: |-
          set -ex
          rm -rf ~/.m2
          mkdir -p $(workspaces.cache.path)/.m2
          ln -fs $(workspaces.cache.path)/.m2 ~/.m2
          cd `mktemp -d`
          curl -s $(params.source-url) | tar -xzvf -
          ./mvnw clean test -V --no-transfer-progress
EOF

kubectl apply -f pipeline-maven.yaml -n ${NAMESPACE}

# To Re-run the pipeline
kubectl delete pipelinerun -n ${NAMESPACE} -l app.kubernetes.io/part-of=hello-servlet
```

#### Gradle

```yaml
NAMESPACE=...

cat <<EOF > spring-music-pipeline-cache-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: spring-music-pipeline-cache
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: "1Gi"
EOF

kubectl apply -f spring-music-pipeline-cache-pvc.yaml -n ${NAMESPACE}
```

```yaml
cat <<'EOF' > pipeline-gradle.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: gradle-test-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test
    apps.jaguchi.maki.lol/test-type: gradle-jdk-17
spec:
  params:
  - name: source-url
  - name: source-revision
  workspaces:
  - name: cache
  tasks:
  - name: test
    params:
    - name: source-url
      value: $(params.source-url)
    - name: source-revision
      value: $(params.source-revision)
    workspaces:
    - name: cache
      workspace: cache
    taskSpec:
      params:
      - name: source-url
      - name: source-revision
      workspaces:
      - name: cache
      steps:
      - name: test
        image: eclipse-temurin:17
        script: |-
          set -ex
          rm -rf ~/.gradle
          mkdir -p $(workspaces.cache.path)/.gradle
          ln -fs $(workspaces.cache.path)/.gradle ~/.gradle
          cd `mktemp -d`
          curl -s $(params.source-url) | tar -xzvf -
          ./gradlew --no-daemon test
EOF

kubectl apply -f pipeline-gradle.yaml -n ${NAMESPACE}

# To Re-run the pipeline
kubectl delete pipelinerun -n ${NAMESPACE} -l app.kubernetes.io/part-of=spring-music
