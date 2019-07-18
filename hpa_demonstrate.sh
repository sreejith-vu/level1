## For Staging
##### !/bin/bash

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


## For Production
##### !/bin/bash

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
