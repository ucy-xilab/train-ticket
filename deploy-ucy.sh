# Train Ticket Setup guide

## Install Helm (Required to install openEBS PV)
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

## Install openEBS PV (Required to support Persistent Volume Claims for stateful workloads)

### Get the first node of the Kubernetes Cluster and save it to kbnode1 variable
export kbnode1=`kubectl get nodes -A| grep kube1\\\. | awk '{print \$1}'`;echo $kbnode1

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

## Deploy benchmark

make deploy DeployArgs="--with-monitoring --with-tracing"
