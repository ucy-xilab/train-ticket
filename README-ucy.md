# Train Ticket Setup guide
## Deployment using git script
### Clone Train-Ticket repo
mkdir trainticket
cd trainticket
git clone --depth=1 https://github.com/ucy-xilab/train-ticket.git
cd train-ticket

### Deploy benchmark
sh deploy-ucy.sh

## Installation guidelines (what's included in the deploy-ucy.sh script)

### Install Helm (Required to install openEBS PV)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

### Install openEBS PV (Required to support Persistent Volume Claims for stateful workloads)

#### Get the first node of the Kubernetes Cluster and save it to kbnode1 variable
export kbnode1=`kubectl get nodes -A| grep kube1\\\. | awk '{print \$1}'`;echo $kbnode1

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
### Check Pod details
kubectl describe pod ts-auth-service-654d66695d-mjdp4 --namespace=default

### Login to a pod
kubectl exec --namespace=default --stdin --tty ts-auth-service-654d66695d-mjdp4 -- /bin/bash
kubectl exec --namespace=default --stdin --tty ts-auth-service-654d66695d-mjdp4 -- /bin/bash

### Clean up
kubectl delete replicasets,deployments,jobs,services,pods --all -n default
kubectl delete statefulset.apps --all -n default

### Find listening ports
kubectl get svc --all-namespaces -o go-template='{{range .items}}{{range.spec.ports}}{{if .nodePort}}{{.name}}{{.nodePort}}{{"\n"}}{{end}}{{end}}{{end}}'
kubectl get svc --all-namespaces
