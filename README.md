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

Demonstration of autoscaling is written as script.
For production - hba_prod_demostrate.sh
For Staging -hba_stg_demostrate.sh

Below is also a summary or logic of script.

```
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

kubectl get hpa -n staging
echo "Waiting for pod scaling"

REPLICA=1
while [[ $REPLICA -le 3 ]]
do
  kubectl get hpa -n staging
  kubectl get pods -n staging

  if [[ $REPLICA -ge 2 ]]
  then
    echo "Pod auto scaled on staging namespace"
    kubectl get hpa -n staging

    echo "Pod scaled successfully. Terminating load generator to reduce load"
    kubectl delete -f load-generator/staging-load-generator.yaml -n staging

    if [[ $? -eq 0 ]]
    then
      echo "Deleted load generator"
    else
      echo "Error while deleting pod/yaml"
    fi

    while [[ $REPLICA -ge 1 ]]
    do
      echo "Waiting for pod to scale down"
      kubectl get hpa -n staging
      kubectl get pods -n staging
      if [[ $REPLICA -eq 1  ]]
      then
        kubectl get hpa -n staging
        echo "Terminated pods as load is normal. Exiting from scipt"
        exit 0
      fi
    echo "Next check after 10 sec"
    sleep 10
    REPLICA=$(kubectl get hpa -n staging |grep frontend |awk '{print $6}')
   done

  fi
  echo "Next check after 10 sec"
  sleep 10
  REPLICA=$(kubectl get hpa -n staging |grep frontend |awk '{print $6}')
done


kubectl apply -f guestbook/redis-master-deployment.yaml -n production
kubectl apply -f guestbook/redis-master-service.yaml -n production
kubectl apply -f guestbook/redis-slave-deployment.yaml -n production
kubectl apply -f guestbook/redis-slave-service.yaml -n production
kubectl apply -f guestbook/frontend-deployment.yaml -n production

kubectl apply -f guestbook/frontend-production-service.yaml -n production
kubectl apply -f production-guestbook-ingress.yaml -n production

kubectl autoscale deployment frontend --cpu-percent=10 --min=1 --max=10 -n production

PROD_LB_PUB_IP=$(kubectl get svc -n production |grep LoadBalancer |awk '{print $4}')

sed -i "" "s/LB_IP/$PROD_LB_PUB_IP/g" load-generator/production-load-generator.yaml

kubectl apply -f load-generator/production-load-generator.yaml -n staging

echo "Waiting for pod scaling"

REPLICA=1
while [[ $REPLICA -le 3 ]]
do
  kubectl get hpa -n production
  kubectl get pods -n production

  if [[ $REPLICA -ge 2 ]]
  then
    echo "Pod auto scaled on production namespace"
    kubectl get hpa -n production

    echo "Pod scaled successfully. Terminating load generator to reduce load"
    kubectl delete -f load-generator/staging-load-generator.yaml -n production

    if [[ $? -eq 0 ]]
    then
      echo "Deleted load generator"
    else
      echo "Error while deleting pod/yaml"
    fi

    while [[ $REPLICA -ge 1 ]]
    do
      echo "Waiting for pod to scale down"
      kubectl get hpa -n production
      kubectl get pods -n production
      if [[ $REPLICA -eq 1  ]]
      then
        kubectl get hpa -n production
        echo "Terminated pods as load is normal. Exiting from scipt"
        exit 0
      fi
    echo "Next check after 10 sec"
    sleep 10
    REPLICA=$(kubectl get hpa -n production |grep frontend |awk '{print $6}')
   done

  fi
  echo "Next check after 10 sec"
  sleep 10
  REPLICA=$(kubectl get hpa -n production |grep frontend |awk '{print $6}')
done
```
