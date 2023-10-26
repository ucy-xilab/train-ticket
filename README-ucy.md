# Train Ticket Setup guide
## Introduction
Only the commands in the "Deployment using git script" section need to be executed to deploy the benchmark. The rest are installation guidelines and useful commands to manage the pods and containers of the trainticket benchmark.

Note that the benchmark is currently deployed on 11 nodes. 
- Node1 ($kbnode1) is used as Master where only the kubernetes master is executing, the openEBS and other services needed to run kubernetes. Also the workload generator can be run on this node
- Node2-4 ($kbnode2-$kbnode4) are used for the stateful services of trainticket. The nodes are tainted with statefulKey:statefulValue taint and the related services (nacos, mysql and rabbitmq) are set to use this toleration from the following deployment templates:
  - Nacos: deployment/kubernetes-manifests/quickstart-k8s/charts/nacos/templates/statefulset.yaml
  - Mysql: deployment/kubernetes-manifests/quickstart-k8s/charts/mysql/templates/statefulset.yaml
  - Rabbitmq: deployment/kubernetes-manifests/quickstart-k8s/charts/rabbitmq/templates/deployment.yaml
- Node5-6 ($kbnode5,$kbnode6) are reserved for high load services with taint highloadKey:highloadValue. Currently none of the services is set with toleration of highloadKey:highloadValue as this should be done after profiling and based on the workload that will be executed. This can be done either by editing the deployment/kubernetes-manifests/quickstart-k8s/yamls/deploy.yaml.sample file or dynamically using the instructions in section "Taint examples"
- Node7-11 ($kbnode7-$kbnode11) are reserved for load load services with taint lowloadKey:lowloadValue. Currently all the services are set with toleration of lowloadKey:lowloadValue and should be changed to highloadKey:highloadValue after profiling and based on the workload that will be executed
  
## Deployment using git script
### Clone Train-Ticket repo
mkdir trainticket
cd trainticket
git clone --depth=1 https://github.com/ucy-xilab/train-ticket.git
cd train-ticket

### Deploy benchmark
bash deploy-ucy.sh

## Installation guidelines (what's included in the deploy-ucy.sh script)

### Install Helm (Required to install openEBS PV)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

### Install openEBS PV (Required to support Persistent Volume Claims for stateful workloads)

#### Get the node names of the Kubernetes Cluster and save it to kbnodei variable
for i in {1..11}; do export kbnode$i=`kubectl get nodes -A| grep kube$i\\\. | awk '{print \$1}'`;export nodename=kbnode$i; echo ${!nodename}; done

#### Install package repo
helm repo add openebs-localpv https://openebs.github.io/dynamic-localpv-provisioner
helm repo update

#### Remove NoSchedule taint from master
kubectl taint nodes $kbnode1 noderole.kubernetes.io/master:NoSchedule-

#### Install package
helm install openebs openebs-localpv/localpv-provisioner --namespace openebs --create-namespace

#### Set default folder for openEBS
sudo mkdir -p /var/openebs/local

#### Start openEBS
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

#### Aplly NoSchedule taint to master
kubectl taint nodes $kbnode1 noderole.kubernetes.io/master:NoSchedule

#### Set default storageclass so Ticket-Train pods will be able to claim the PVs
kubectl patch storageclass openebs-hostpath -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

#### Confirm storageClasses and that at least one is set as (default)
kubectl get pvc -A

kubectl get storageclass -A

### Setting up taints

kubectl taint nodes $kbnode2 statefulKey=statefulValue:NoExecute
kubectl taint nodes $kbnode3 statefulKey=statefulValue:NoExecute
kubectl taint nodes $kbnode4 statefulKey=statefulValue:NoExecute
kubectl taint nodes $kbnode5 highloadKey=highloadValue:NoExecute
kubectl taint nodes $kbnode6 highloadKey=highloadValue:NoExecute
kubectl taint nodes $kbnode7 lowloadKey=lowloadValue:NoExecute
kubectl taint nodes $kbnode8 lowloadKey=lowloadValue:NoExecute
kubectl taint nodes $kbnode9 lowloadKey=lowloadValue:NoExecute
kubectl taint nodes $kbnode10 lowloadKey=lowloadValue:NoExecute
kubectl taint nodes $kbnode11 lowloadKey=lowloadValue:NoExecute

### Clone Train-Ticket repo
mkdir trainticket

cd trainticket

git clone --depth=1 https://github.com/ucy-xilab/train-ticket.git

cd train-ticket

### Deploy benchmark

make deploy DeployArgs="--with-monitoring --with-tracing"

### make deploy DeployArgs="--with-monitoring --with-tracing" Namespace=mklean # Deploy with Skywalker and Prometheous on mklean namespace

### make deploy DeployArgs="--all" # Deploy with all options --with-monitoring --with-tracing and --independed-db

### make deploy # Simple deployment on default namespace

## Install k9s for easy monitoring and managing pods

### Enable Metric server and CLI to view pods load

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
### kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
### kubectl replace -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 

### Enable enable-aggregator-routing: 'true' in kube-apiserver to allow metric server to collect cpu load and memory
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml .

sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml

### Find section commands. Add the following
- --enable-aggregator-routing=true

### Add kubelet-insecure-tls command
kubectl edit deploy -n kube-system metrics-server

### Find the section args. Add the following
- --kubelet-insecure-tls

### Confirm that metrics server is running
kubectl get pod -n kube-system

kubectl top nodes

#### K9s - Kubernetes CLI To Manage Your Clusters In Style!
curl -sS https://webinstall.dev/k9s | bash

source ~/.config/envman/PATH.env

k9s

#### Press 2 to show the default namespace where train ticket pods are running

## Usefull commands

### Get pods on specific node
```
for i in {1..11}; do export kbnode$i=`kubectl get nodes -A| grep kube$i\\\. | awk '{print \$1}'`;export nodename=kbnode$i; echo ${!nodename}; done
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode1
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode2
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode3
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode4
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode5
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode6
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode7
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode8
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode9
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode10
kubectl get pods -n default -o wide --field-selector spec.nodeName=$kbnode11
```

### Reset installation
```
make reset-deploy
helm uninstall tsdb -n default
make deploy
```

### Mysql cluster is not uninstalling correctly in case of reset. To do it manually execute the following
helm uninstall tsdb -n default

### Delete all instances manually
kubectl delete pods,service,deployments --all -A -n default

### Check Pod details
kubectl describe pod ts-auth-service-654d66695d-mjdp4 --namespace=default

### Check Pod's full details. Useful to check the state and error when not booting
kubectl get pod nacosdb-mysql-0 -n default --output=yaml

### Login to a pod
kubectl exec --namespace=default --stdin --tty ts-auth-service-654d66695d-mjdp4 -- /bin/bash

kubectl exec --namespace=default --stdin --tty ts-auth-service-654d66695d-mjdp4 -- /bin/bash

### Clean up
kubectl delete replicasets,deployments,jobs,services,pods --all -n default

kubectl delete statefulset.apps --all -n default

### Find listening ports
kubectl get svc --all-namespaces -o go-template='{{range .items}}{{range.spec.ports}}{{if .nodePort}}{{.name}}{{.nodePort}}{{"\n"}}{{end}}{{end}}{{end}}'

kubectl get svc --all-namespaces

### Update resources
kubectl edit deploy ts-auth-service -o yaml -n default

### Get services on all nodes
kubectl get nodes

kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node>

## Taint examples
### Add a taint to a node to prevent any pods to map to the node unless they match. The below example is for auth service assuming that is running on $kbnode5 node
kubectl taint nodes $kbnode5 highloadKey=highloadValue:NoExecute

kubectl edit deploy ts-auth-service -o yaml -n default
#### Add the following code
spec:
   tolerations:
   - key: "highloadKey"
     operator: "Equal"
     value: "highloadValue"
     effect: "NoExecute"

### To remove a taint and allow all pods to map
kubectl taint nodes $kbnode5 highloadKey=highloadValue:NoExecute-

## Workload Generator
The instructions for deploying and running the workload generator are in a separate github repository(ts-locust-load-generator). 
