
#!/bin/bash

# Variables
NAMESPACE="argocd"
CLUSTER_NAME=$(kubectl config current-context)

echo "Connecting to EKS cluster: $CLUSTER_NAME"

# Ensure namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Argo CD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo CD using Helm
helm upgrade --install argocd argo/argo-cd \
  --namespace $NAMESPACE \
  --set server.service.type=LoadBalancer

echo "Argo CD deployed in namespace $NAMESPACE"
echo "Run 'kubectl get svc -n $NAMESPACE' to get the LoadBalancer URL."
