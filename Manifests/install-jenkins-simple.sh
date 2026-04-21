cat > install-jenkins-simple.sh << 'EOF'
#!/bin/bash

# Simple Jenkins Installation for EKS
set -e

JENKINS_NAMESPACE="jenkins"
JENKINS_RELEASE_NAME="jenkins"

echo "🚀 Installing Jenkins with default configuration..."

# Create namespace
kubectl create namespace $JENKINS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repository
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins with minimal configuration
helm upgrade --install $JENKINS_RELEASE_NAME jenkins/jenkins \
  --namespace $JENKINS_NAMESPACE \
  --set controller.admin.username=admin \
  --set controller.admin.password=admin123 \
  --set controller.serviceType=LoadBalancer \
  --set controller.serviceAnnotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb \
  --set persistence.enabled=true \
  --set persistence.storageClass=gp2 \
  --set persistence.size=20Gi \
  --set rbac.create=true \
  --wait \
  --timeout 3m

echo "✅ Jenkins installed successfully!"
echo ""
echo "📋 Access Information:"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "🌐 Get Jenkins URL:"
echo "kubectl get svc $JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE"
echo ""
echo "🔧 Port forward (if LoadBalancer is not ready):"
echo "kubectl port-forward svc/$JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE 8080:8080"
EOF

