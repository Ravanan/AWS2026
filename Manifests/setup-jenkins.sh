
#!/bin/bash

# Usage: ./setup-jenkins.sh deploy|delete
# Example: ./setup-jenkins.sh deploy

#$0 → the script name (setup-jenkins.sh)
#$1 → the first argument (deploy)

ACTION=$1
NAMESPACE="jenkins"

if ! command -v helm &> /dev/null; then
    echo "Helm not found. Please install Helm before running this script."
    exit 1
fi

# Step 1: Connecting to EKS cluster
if [ "$ACTION" == "deploy" ]; then
echo "Connecting to EKS cluster: $(kubectl config current-context)"

# Ensure namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create PVC inline
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: gp2
EOF


# Step 3: Add Jenkins Helm repo
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Deploy Jenkins using values.yaml
helm install jenkins jenkinsci/jenkins -n $NAMESPACE -f values.yaml
    
echo "Waiting for Jenkins pod to start..."
kubectl get pods -n $NAMESPACE

# Step 7: Get Jenkins admin password
kubectl get secret jenkins -n $NAMESPACE -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# Step 8: Port forward Jenkins service
kubectl port-forward svc/jenkins 8080:8080 -n $NAMESPACE

elif [ "$ACTION" == "delete" ]; then
    helm uninstall jenkins -n $NAMESPACE
    kubectl delete namespace $NAMESPACE
else
    echo "Usage: $0 {deploy|delete}"
fi
