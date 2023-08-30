#!/bin/bash
# Train Ticket Setup guide

## Install Helm (Required to install openEBS PV)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

## Install openEBS PV (Required to support Persistent Volume Claims for stateful workloads)

### Get the node names of the Kubernetes Cluster and save it to kbnodei variable
for i in {1..11}; do export kbnode$i=`kubectl get nodes -A| grep kube$i\\\. | awk '{print \$1}'`;export nodename=kbnode$i; echo ${!nodename}; done

### Install package repo
helm repo add openebs-localpv https://openebs.github.io/dynamic-localpv-provisioner
helm repo update

### Remove NoSchedule taint from master
kubectl taint nodes $kbnode1 noderole.kubernetes.io/master:NoSchedule-

### Install package
helm install openebs openebs-localpv/localpv-provisioner --namespace openebs --create-namespace

### Set default folder for openEBS
sudo mkdir -p /var/openebs/local

### Start openEBS
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml

### Aplly NoSchedule taint to master
kubectl taint nodes $kbnode1 noderole.kubernetes.io/master:NoSchedule

### Set default storageclass so Ticket-Train pods will be able to claim the PVs
kubectl patch storageclass openebs-hostpath -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

### Confirm storageClasses and that at least one is set as (default)
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


## Deploy benchmark

make deploy
## make deploy DeployArgs="--with-monitoring --with-tracing"
