#### Step 1:
Creaing the cluster with name dc2

```
gcloud container clusters create dc2 --enable-autorepair --enable-autoupgrade --enable-cloud-logging --max-nodes=3 --min-nodes=2 --machine-type=custom-1-1024
```

#### Step 2:
Iam familiar with helm so i have installed nginx controller with helm.
```
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

helm init --service-account tiller
helm init --upgrade --service-account tiller
helm install --name nginx-ingress stable/nginx-ingress --set rbac.create=true --set controller.publishService.enabled=true
```
#### Step 3:
Created namespaces staging and production
```
kubectl create ns staging
kubectl create ns production
```
#### Step 4: 
Deployed guestbook application in staging. Modified frontend deployment yaml file to create single replica.

#### Step 5: 
Enabled horizontal pod autoscaling on frontend deployment.
On reaching 10% CPU(for testing purpose only i have given this), pod will scale to maximum 10 nodes.
```
kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n staging
```
#### Step 6: 
To test pod scaling i have created a kind:Pod yaml which will send multiple requests to the loadbalancer.
YAML - load-generator.yaml
```
kubectl apply -f load-generator.yaml -n staging
```
As the requests started triggering CPU usage got increased and pods started scaling.
I have reduced the CPU limit by `kubectl edit hpa -n staging` and set it to 10% for immediate result.

Similarly I have configured production environment

Commands Production:
```
kubectl apply -f guestbook/redis-master-deployment.yaml -n production
kubectl apply -f guestbook/redis-master-service.yaml -n production
kubectl apply -f guestbook/redis-slave-deployment.yaml -n production
kubectl apply -f guestbook/redis-slave-service.yaml -n production
kubectl apply -f guestbook/frontend-deployment.yaml -n production

kubectl apply -f guestbook/frontend-production-service.yaml -n production
kubectl apply -f production-guestbook-ingress.yaml -n production

kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n production

kubectl apply -f load-generator/load-generator.yaml -n production
```

Commands Staging:
```
kubectl apply -f guestbook/redis-master-deployment.yaml -n staging
kubectl apply -f guestbook/redis-master-service.yaml -n staging
kubectl apply -f guestbook/redis-slave-deployment.yaml -n staging
kubectl apply -f guestbook/redis-slave-service.yaml -n staging
kubectl apply -f guestbook/frontend-deployment.yaml -n staging

kubectl apply -f guestbook/frontend-staging-service.yaml -n staging
kubectl apply -f staging-guestbook-ingress.yaml -n staging

kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n staging

kubectl apply -f load-generator/load-generator.yaml -n staging
```

All tasks in single script.

kubectl apply -f guestbook/redis-master-deployment.yaml -n staging
kubectl apply -f guestbook/redis-master-service.yaml -n staging
kubectl apply -f guestbook/redis-slave-deployment.yaml -n staging
kubectl apply -f guestbook/redis-slave-service.yaml -n staging
kubectl apply -f guestbook/frontend-deployment.yaml -n staging

kubectl apply -f guestbook/frontend-staging-service.yaml -n staging
kubectl apply -f staging-guestbook-ingress.yaml -n staging

kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n staging

STG_LB_PUB_IP=$(kubectl get svc -n staging |grep LoadBalancer |awk '{print $4}')

echo $STG_LB_PUB_IP

sed -i "" "s/LB_IP/$STG_LB_PUB_IP/g" load-generator/staging-load-generator.yaml

kubectl apply -f load-generator/staging-load-generator.yaml -n staging


kubectl apply -f guestbook/redis-master-deployment.yaml -n staging
kubectl apply -f guestbook/redis-master-service.yaml -n staging
kubectl apply -f guestbook/redis-slave-deployment.yaml -n staging
kubectl apply -f guestbook/redis-slave-service.yaml -n staging
kubectl apply -f guestbook/frontend-deployment.yaml -n staging

kubectl apply -f guestbook/frontend-staging-service.yaml -n staging
kubectl apply -f staging-guestbook-ingress.yaml -n staging

kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n staging

PROD_LB_PUB_IP=$(kubectl get svc -n production |grep LoadBalancer |awk '{print $4}')

sed -i "" "s/LB_IP/$PROD_LB_PUB_IP/g" load-generator/production-load-generator.yaml

kubectl apply -f load-generator/production-load-generator.yaml -n staging
