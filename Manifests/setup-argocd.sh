
#!/bin/bash

# Variables
ACTION=$1
NAMESPACE="argocd"

if [ "$ACTION" == "deploy" ]; then
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

elif [ "$ACTION" == "delete" ]; then
    helm uninstall argocd -n $NAMESPACE
    kubectl delete namespace $NAMESPACE
else
    echo "Usage: $0 {deploy|delete}"
fi
