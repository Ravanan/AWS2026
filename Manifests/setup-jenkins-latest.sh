#!/bin/bash
ACTION=$1
set -e

# Variables
NAMESPACE=jenkins
RELEASE_NAME=jenkins
CHART_VERSION=5.3.2   # Adjust to latest stable Jenkins chart version
STORAGE_CLASS=gp3     # Auto Mode supports gp3, not gp2
NODEPOOL_LABEL_KEY=karpenter.sh/nodepool
NODEPOOL_LABEL_VALUE=general-purpose

if [ "$ACTION" == "deploy" ]; then
# 1. Create namespace
kubectl create namespace $NAMESPACE || echo "Namespace $NAMESPACE already exists"

# 2. Add Jenkins Helm repo
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 3. Install Jenkins with persistence enabled and affinity to general-purpose nodepool
helm upgrade --install $RELEASE_NAME jenkins/jenkins \
  --namespace $NAMESPACE \
  --version $CHART_VERSION \
  --set controller.admin.username=admin \
  --set controller.admin.password=admin123 \
  --set persistence.enabled=true \
  --set persistence.storageClass=$STORAGE_CLASS \
  --set persistence.size=20Gi \
  --set controller.serviceType=LoadBalancer \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=$NODEPOOL_LABEL_KEY \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=In \
  --set controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]=$NODEPOOL_LABEL_VALUE \
  --set controller.tolerations[0].key=$NODEPOOL_LABEL_KEY \
  --set controller.tolerations[0].operator=Equal \
  --set controller.tolerations[0].value=$NODEPOOL_LABEL_VALUE \
  --set controller.tolerations[0].effect=NoSchedule
# 4. Wait for Jenkins pod to be ready
echo "Waiting for Jenkins pod to be ready..."
kubectl rollout status deployment/$RELEASE_NAME -n $NAMESPACE

# 5. Get LoadBalancer URL
echo "Jenkins URL:"
kubectl get svc $RELEASE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo
echo "Login with username 'admin' and password 'admin123'"
elif [ "$ACTION" == "delete" ]; then
    helm uninstall jenkins -n $NAMESPACE
    kubectl delete namespace $NAMESPACE
else
    echo "Usage: $0 {deploy|delete}"
fi

