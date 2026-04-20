
#!/bin/bash

# Usage: ./deploy-jenkins.sh <CLUSTER_NAME> <REGION> <NAMESPACE>
# Example: ./deploy-jenkins.sh my-cluster us-east-1 jenkins

if ! command -v helm &> /dev/null; then
    echo "Helm not found. Please install Helm before running this script."
    exit 1
fi

# Step 1: Connecting to EKS cluster
NAMESPACE="jenkins"
CLUSTER_NAME=$(kubectl config current-context)

echo "Connecting to EKS cluster: $CLUSTER_NAME"

# Ensure namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -


# Step 2: Verify cluster connection
kubectl get nodes

# Step 3: Add Jenkins Helm repo
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Step 5: Deploy Jenkins
helm install jenkins jenkinsci/jenkins --namespace $NAMESPACE \
  --set persistence.enabled=true \
  --set persistence.existingClaim=jenkins-pvc \
  --set controller.startupProbe.httpGet.path=/ \
  --set controller.startupProbe.httpGet.port=8080 \
  --set controller.startupProbe.initialDelaySeconds=480 \
  --set controller.startupProbe.periodSeconds=30 \
  --set controller.startupProbe.failureThreshold=20

echo "waiting for startup probe to initiate after 480 seconds for Jenkins: $CLUSTER_NAME"

# Step 6: Wait for Jenkins pod
kubectl get pods -n $NAMESPACE

# Step 7: Get Jenkins admin password
kubectl get secret jenkins -n $NAMESPACE -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode

# Step 8: Port forward Jenkins service
kubectl port-forward svc/jenkins 8080:8080 -n $NAMESPACE
