
#!/bin/bash

# Usage: ./deploy-jenkins.sh <CLUSTER_NAME> <REGION> <NAMESPACE>
# Example: ./deploy-jenkins.sh my-cluster us-east-1 jenkins

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
helm install jenkins jenkinsci/jenkins --namespace $NAMESPACE

# Step 6: Wait for Jenkins pod
kubectl get pods -n $NAMESPACE

# Step 7: Get Jenkins admin password
kubectl exec --namespace $NAMESPACE -it svc/jenkins -c jenkins \
  -- cat /run/secrets/additional/chart-admin-password

# Step 8: Port forward Jenkins service
kubectl port-forward svc/jenkins 9090:8080 -n $NAMESPACE
