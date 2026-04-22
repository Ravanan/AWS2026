#!/bin/bash
set -e

NAMESPACE=jenkins
RELEASE_NAME=jenkins
CHART_VERSION=5.3.2
STORAGE_CLASS=gp3

# Create namespace if not exists
kubectl create namespace $NAMESPACE || echo "Namespace $NAMESPACE already exists"

# Add Jenkins Helm repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins with affinity + tolerations
helm upgrade --install $RELEASE_NAME jenkins/jenkins \
  --namespace $NAMESPACE \
  --version $CHART_VERSION \
  --create-namespace \
  --set controller.admin.username=admin \
  --set controller.admin.password=admin123 \
  --set persistence.enabled=true \
  --set persistence.storageClass=$STORAGE_CLASS \
  --set persistence.size=20Gi \
  --set controller.serviceType=LoadBalancer \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=karpenter.sh/nodepool \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=In \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]=general-purpose \
  --set controller.tolerations[0].key=karpenter.sh/nodepool \
  --set controller.tolerations[0].operator=Equal \
  --set controller.tolerations[0].value=general-purpose \
  --set controller.tolerations[0].effect=NoSchedule

# Wait for Jenkins pod to be ready
echo "Waiting for Jenkins pod to be ready..."
kubectl rollout status statefulset/$RELEASE_NAME -n $NAMESPACE

# Get LoadBalancer URL
echo "Jenkins URL:"
kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo
echo "Login with username 'admin' and password 'admin123'"
