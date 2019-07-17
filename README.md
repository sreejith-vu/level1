#### Step 1:
Creaing the cluster with name dc2

```gcloud container clusters create dc2 --enable-autorepair --enable-autoupgrade --enable-cloud-logging --max-nodes=3 --min-nodes=2 --machine-type=custom-1-1024```

#### Step 2:
Iam familiar with helm so i have installed nginx controller with helm.

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

helm init --service-account tiller
helm init --upgrade --service-account tiller
helm install --name nginx-ingress stable/nginx-ingress --set rbac.create=true --set controller.publishService.enabled=true

#### Step 3:
Created namespaces staging and production
kubectl create ns staging
kubectl create ns production

#### Step 4: 
Deployed guestbook application in staging. Modified frontend deployment yaml file to create single replica.

#### Step 5: 
Enabled horizontal pod autoscaling on frontend deployment.
On reaching 50% CPU, pod will scale to maximum 10 nodes.

kubectl autoscale deployment frontend --cpu-percent=50 --min=1 --max=10 -n staging

#### Step 6: 
To test pod scaling i have created a kind:Pod yaml which will send multiple requests to the loadbalancer.
YAML - load-generator.yaml

As the requests started triggering CPU usage got increased and pods started scaling.
I have reduced the CPU limit by `kubectl edit hpa -n staging` and set it to 10% for immediate result.



