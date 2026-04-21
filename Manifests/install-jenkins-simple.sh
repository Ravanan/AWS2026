cat > install-jenkins-eks-automode.sh << 'EOF'
#!/bin/bash

# Jenkins Installation Script for EKS Auto Mode Cluster
set -e

JENKINS_NAMESPACE="jenkins"
JENKINS_RELEASE_NAME="jenkins"
JENKINS_ADMIN_PASSWORD="admin123"

echo "🚀 Installing Jenkins on EKS Auto Mode cluster..."

# Check kubectl configuration
echo "📋 Checking kubectl configuration..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    exit 1
fi

echo "✅ kubectl is configured and cluster is accessible"

# Check available storage classes
echo "📋 Checking available storage classes..."
kubectl get storageclass

# Create namespace
echo "📦 Creating Jenkins namespace..."
kubectl create namespace $JENKINS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Jenkins Helm repository
echo "📥 Adding Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create Jenkins values file optimized for EKS Auto Mode
echo "📝 Creating Jenkins configuration for EKS Auto Mode..."
cat > jenkins-values.yaml << VALUESEOF
controller:
  # Admin configuration
  admin:
    username: "admin"
    password: "$JENKINS_ADMIN_PASSWORD"
  
  # Resource configuration
  resources:
    requests:
      cpu: "100m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "2048Mi"

  # JVM options
  javaOpts: "-Xms512m -Xmx1536m"

  # Node selector for EKS Auto Mode
  nodeSelector:
    eks.amazonaws.com/compute-type: auto

  # Tolerations for EKS Auto Mode
  tolerations:
    - key: "eks.amazonaws.com/compute-type"
      operator: "Equal"
      value: "auto"
      effect: "NoSchedule"

  # Service configuration - using ClusterIP initially
  serviceType: ClusterIP
  
  # Disable default plugins to avoid conflicts
  installPlugins: []

# Persistence configuration for EKS Auto Mode
persistence:
  enabled: true
  # Use the default storage class for EKS Auto Mode
  storageClass: ""
  size: "10Gi"
  accessMode: "ReadWriteOnce"

# Agent configuration
agent:
  enabled: true
  
  # Node selector for agents
  nodeSelector:
    eks.amazonaws.com/compute-type: auto
    
  # Tolerations for agents
  tolerations:
    - key: "eks.amazonaws.com/compute-type"
      operator: "Equal"
      value: "auto"
      effect: "NoSchedule"
  
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"

# Service account
serviceAccount:
  create: true
  name: jenkins

# RBAC
rbac:
  create: true
  readSecrets: false

# Network policy
networkPolicy:
  enabled: false
VALUESEOF

# Install Jenkins using Helm
echo "🔧 Installing Jenkins..."
helm upgrade --install $JENKINS_RELEASE_NAME jenkins/jenkins \
  --namespace $JENKINS_NAMESPACE \
  --values jenkins-values.yaml \
  --wait \
  --timeout 15m

# Wait for Jenkins to be ready
echo "⏳ Waiting for Jenkins to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n $JENKINS_NAMESPACE --timeout=600s

# Create LoadBalancer service separately
echo "🌐 Creating LoadBalancer service..."
cat > jenkins-loadbalancer.yaml << LBEOF
apiVersion: v1
kind: Service
metadata:
  name: jenkins-lb
  namespace: $JENKINS_NAMESPACE
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/component: jenkins-controller
    app.kubernetes.io/instance: jenkins
LBEOF

kubectl apply -f jenkins-loadbalancer.yaml

# Get Jenkins service information
echo "🔍 Getting Jenkins service information..."
sleep 10  # Wait a bit for the service to be created

JENKINS_URL=$(kubectl get svc jenkins-lb -n $JENKINS_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$JENKINS_URL" ]; then
    JENKINS_URL=$(kubectl get svc jenkins-lb -n $JENKINS_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

# Display installation summary
echo ""
echo "🎉 Jenkins installation completed successfully!"
echo ""
echo "📋 Installation Summary:"
echo "========================"
echo "Namespace: $JENKINS_NAMESPACE"
echo "Release Name: $JENKINS_RELEASE_NAME"
echo "Admin Username: admin"
echo "Admin Password: $JENKINS_ADMIN_PASSWORD"
echo ""

if [ ! -z "$JENKINS_URL" ]; then
    echo "🌐 Jenkins URL: http://$JENKINS_URL"
    echo "   Note: It may take a few minutes for the LoadBalancer to be ready"
else
    echo "🌐 Jenkins URL: LoadBalancer is being provisioned..."
    echo "   Check status: kubectl get svc jenkins-lb -n $JENKINS_NAMESPACE"
    echo ""
    echo "   Or use port-forward: kubectl port-forward svc/jenkins -n $JENKINS_NAMESPACE 8080:8080"
    echo "   Then access: http://localhost:8080"
fi

echo ""
echo "📝 Useful Commands:"
echo "==================="
echo "Check Jenkins status:"
echo "  kubectl get pods -n $JENKINS_NAMESPACE"
echo ""
echo "Check nodes and taints:"
echo "  kubectl get nodes -o wide"
echo "  kubectl describe nodes"
echo ""
echo "Check storage classes:"
echo "  kubectl get storageclass"
echo ""
echo "Get Jenkins logs:"
echo "  kubectl logs -f deployment/$JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE"
echo ""
echo "Check LoadBalancer status:"
echo "  kubectl get svc jenkins-lb -n $JENKINS_NAMESPACE"
echo ""

# Clean up temporary files
rm -f jenkins-values.yaml jenkins-loadbalancer.yaml

echo "✅ Script completed successfully!"
EOF
