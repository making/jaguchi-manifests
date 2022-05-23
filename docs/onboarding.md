## Developer on-boarding

### Installation of required CLI

Please install the following CLI in advance

* [`kubectl`](https://kubernetes.io/docs/tasks/tools/)
* `tanzu` ([TAP version](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap//GUID-install-tanzu-cli.html) or [TCE version](https://tanzucommunityedition.io/docs/v0.12/cli-installation/))
* [`pinniped`](https://pinniped.dev/docs/howto/install-cli/)

### TAP GUIへのアクセス

Members of [jaguchi-users team](https://github.com/orgs/tanzu-japan/teams/jaguchi-users) in [tanzu-japan org](https://github.com/tanzu-japan) org can log in to the [TAP GUI](https://tap-gui.jaguchi.maki.lol).

URL: https://tap-gui.jaguchi.maki.lol (VMware VPN is required)

<img src="https://user-images.githubusercontent.com/106908/167983482-d0fd3d34-1726-4ebb-8f4d-0d218c0279a9.png">

Click "SIGN IN" and log in via GitHub (Dex).

Go to https://tap-gui.jaguchi.maki.lol/settings and make sure your username and email are displayed correctly in the Profile page.

<img src="https://user-images.githubusercontent.com/106908/167986313-02033b48-88d7-4833-ac99-043ce0d8cb55.png">

### Crate Namespace and RBAC

Next, we will create a namespace for Developer and configure RBAC ( [reference document](https://docs.vmware.com/en/Tanzu-Application-Platform/1.1/tap/GUID-install-components.html#setup) ).

Go to https://github.com/tanzu-japan/jaguchi-manifests/blob/main/jaguchi/config/platform/tap-users/tap-users-data-values.yaml and click the edit button as bellow.

<img src="https://user-images.githubusercontent.com/106908/167986932-bbd793ad-b31c-4064-8f0a-771d04109c3e.png">

Add the following YAML to `users`.

```yaml
- name: <GitHub Account Name>
  email: <Email Address displayed in the TAP GUI Profile>
  clusterroles:
  - app-editor
  - edit # (optional)
```

Add only `app-editor` if it is enough to create the K8s resources (Workload, etc.) required for TAP, and `edit` if you want to create K8s (Deployment, Pod, etc.) other than TAP under the `clusterroles`.

**Example**
```yaml
- name: making-bot
  email: makingx+bot@gmail.com
  clusterroles:
  - app-editor
```

<img src="https://user-images.githubusercontent.com/106908/167987196-981c96bc-eec4-4dd9-ad09-91e0dcd785f9.png">

Press the "Propose changes" button.

<img src="https://user-images.githubusercontent.com/106908/167991752-2e495124-8490-4bd6-b5ea-711b9cdd22b6.png">

Check the YAML diff and press the "Create pull request" button.

<img src="https://user-images.githubusercontent.com/106908/167992033-25dc2a12-acfe-4de7-a988-9f24181471a3.png">

Press the "Create pull request" button again.
<img src="https://user-images.githubusercontent.com/106908/167992818-b3daba6b-8b6f-48c0-9be4-ac461d4c413d.png">

Wait until it is merged.
<img src="https://user-images.githubusercontent.com/106908/167992996-261b2e56-5c6c-4348-92a0-74045bc6c888.png">

After merging, Namespace, Secret, RoleBinding, etc. will be created automatically after about 1 minute, and you will be able to access the K8s cluster.

<img src="https://user-images.githubusercontent.com/106908/167993294-b819f319-e2c1-45b4-8fed-582aad941a8b.png">

### Access to the Kubernetes cluster

**Connect to VMware VPN.**

Save the following YAML in `$HOME/.kube/jaguchi.yaml` . (You can change the path)

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

Set the saved file path in the environment variable `KUBECONFIG`.

```
export KUBECONFIG=$HOME/.kube/jaguchi.yaml
```

Then run the following command.

```
kubectl get pod
```

Your browser will launch and you will be asked to log in to GitHub. A message `you have been logged in and may now close this tab` will be output on the browser saying that you can log in .

<img src="https://user-images.githubusercontent.com/106908/167994365-534cf9df-4169-473b-9659-6ca22c131a30.png">

The following message is output to the console. Since you are not given permission to access the `default` namespace, it is OK if `Forbidden` and `<your email address>` is output.

```
Error from server (Forbidden): pods is forbidden: User "makingx+bot@gmail.com" cannot list resource "pods" in API group "" in the namespace "default"
```

Then access the `<GitHub Account Name>` namespace.

```
kubectl get pod -n <GitHub Account Name>
```

**Example**
```
$ kubectl get pod -n making-bot
No resources found in making-bot namespace.
```

The message `No resources found in making-bot namespace` is printed because `<GitHub Account Name>` namespace has read permission for the pod.

### Create a Workload
Deploy a sample application with the following command.

```
NAMESPACE=<GitHub Account Name>

tanzu apps workload apply spring-music \
  --app spring-music \
  --git-repo https://github.com/tanzu-japan/spring-music \
  --git-branch tanzu \
  --type web \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n ${NAMESPACE} -y
tanzu apps workload tail spring-music -n ${NAMESPACE}
```

It is easier to see the progress if you open another terminal and execute the following command.

```
export KUBECONFIG=$HOME/.kube/jaguchi.yaml
NAMESPACE=<GitHub Account Name>

watch kubectl get pod,workload,gitrepo,build,taskrun,app,ksvc -n ${NAMESPACE}
```

It is OK if the following log starts to be output. Please wait 5-10 minutes.

<img width="1024" src="https://user-images.githubusercontent.com/106908/167995983-ad2c45d6-a609-4cd9-9f5b-9e0a383e6bab.png">

Go to https://tap-gui.jaguchi.maki.lol/supply-chain to see your workload.

<img src="https://user-images.githubusercontent.com/106908/167996205-badcca0e-c274-40d3-a1d7-d574565a12c6.png">

Select your Worload to see the progress of your Supply Chain.

<img src="https://user-images.githubusercontent.com/106908/167996416-87e4085b-48e3-42e0-86e0-5f828aea934f.png">

The first build will take about 8 minutes. When the Workload STATUS becomes Ready, run the following command.

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

It is OK if you access the URL (`https://spring-music-<GitHub Account Name>.apps.jaguchi.maki.lol`) of Knative Services and the screen of the application is displayed.



<img src="https://user-images.githubusercontent.com/106908/167996804-0aa9f275-6412-454b-8453-cfb5a543e34e.png">

After confirming the operation, delete Workload with the following command.

```
tanzu apps workload delete spring-music -n ${NAMESPACE} -y
```

### What's Next

* [Create and bind a Tanzu SQL with PostgreSQL instance](postgresql.md)
* [Create and bind a MongoDB instance](mongodb.md)
* [Create and bind a Tanzu RabbitMQ for Kubernetes instannce](rabbitmq.md)
* [Publish apps to the Internet (in Japanese)](publish-apps-to-internet_ja.md)