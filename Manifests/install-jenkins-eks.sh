cat > install-jenkins-eks.sh << 'EOF'
#!/bin/bash

# Jenkins Installation Script for EKS Cluster (Updated for latest Helm chart)
# Make sure you have kubectl configured for your EKS cluster and Helm installed

set -e

# Configuration variables
JENKINS_NAMESPACE="jenkins"
JENKINS_RELEASE_NAME="jenkins"
STORAGE_CLASS="gp2"
STORAGE_SIZE="20Gi"
JENKINS_ADMIN_PASSWORD="admin123"

echo "🚀 Starting Jenkins installation on EKS cluster..."

# Check if kubectl is configured
echo "📋 Checking kubectl configuration..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    exit 1
fi

echo "✅ kubectl is configured and cluster is accessible"

# Check if Helm is installed
echo "📋 Checking Helm installation..."
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed. Please install Helm first."
    exit 1
fi

echo "✅ Helm is installed"

# Create namespace for Jenkins
echo "📦 Creating Jenkins namespace..."
kubectl create namespace $JENKINS_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Jenkins Helm repository
echo "📥 Adding Jenkins Helm repository..."
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Create Jenkins values file with updated parameters
echo "📝 Creating Jenkins configuration..."
cat > jenkins-values.yaml << VALUESEOF
controller:
  # Updated admin configuration
  admin:
    username: "admin"
    password: "$JENKINS_ADMIN_PASSWORD"
  
  # Resource configuration
  resources:
    requests:
      cpu: "50m"
      memory: "256Mi"
    limits:
      cpu: "2000m"
      memory: "4096Mi"

  # JVM options
  javaOpts: "-Xms512m -Xmx2048m"

  # Service configuration
  serviceType: LoadBalancer
  serviceAnnotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

  # Plugin installation
  additionalPlugins:
    - kubernetes:4246.v5a_12b_1fe120e
    - workflow-aggregator:596.v8c21c963d92d
    - git:5.2.2
    - configuration-as-code:1810.v9b_c30a_249a_4c
    - blueocean:1.27.14
    - pipeline-stage-view:2.34
    - docker-workflow:580.vc0c340686b_54
    - aws-credentials:191.vcb_f183ce58b_9

  # JCasC configuration
  JCasC:
    defaultConfig: true
    configScripts:
      welcome-message: |
        jenkins:
          systemMessage: "Jenkins configured automatically by Jenkins Configuration as Code plugin\n\n"
      kubernetes-config: |
        jenkins:
          clouds:
            - kubernetes:
                name: "kubernetes"
                serverUrl: "https://kubernetes.default"
                namespace: "$JENKINS_NAMESPACE"
                jenkinsUrl: "http://jenkins:8080"
                jenkinsTunnel: "jenkins-agent:50000"
                connectTimeout: 0
                readTimeout: 0
                retentionTimeout: 5
                maxRequestsPerHost: 32
                templates:
                  - name: "default"
                    namespace: "$JENKINS_NAMESPACE"
                    label: "jenkins-agent"
                    nodeUsageMode: "NORMAL"
                    containers:
                      - name: "jnlp"
                        image: "jenkins/inbound-agent:latest"
                        workingDir: "/home/jenkins/agent"
                        resourceRequestCpu: "100m"
                        resourceRequestMemory: "256Mi"
                        resourceLimitCpu: "500m"
                        resourceLimitMemory: "512Mi"

# Persistence configuration
persistence:
  enabled: true
  storageClass: "$STORAGE_CLASS"
  size: "$STORAGE_SIZE"
  accessMode: "ReadWriteOnce"

# Agent configuration
agent:
  enabled: true
  resources:
    requests:
      cpu: "512m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1024Mi"

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

# Get Jenkins service information
echo "🔍 Getting Jenkins service information..."
JENKINS_URL=$(kubectl get svc $JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$JENKINS_URL" ]; then
    JENKINS_URL=$(kubectl get svc $JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

# Create additional RBAC for Jenkins agents
echo "🔐 Creating additional RBAC for Jenkins agents..."
cat > jenkins-agent-rbac.yaml << RBACEOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-agent
  namespace: $JENKINS_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $JENKINS_NAMESPACE
  name: jenkins-agent
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jenkins-agent
  namespace: $JENKINS_NAMESPACE
subjects:
- kind: ServiceAccount
  name: jenkins-agent
  namespace: $JENKINS_NAMESPACE
roleRef:
  kind: Role
  name: jenkins-agent
  apiGroup: rbac.authorization.k8s.io
RBACEOF

kubectl apply -f jenkins-agent-rbac.yaml

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
    echo "🌐 Jenkins URL: http://$JENKINS_URL:8080"
    echo "   Note: It may take a few minutes for the LoadBalancer to be ready"
else
    echo "🌐 Jenkins URL: Use port-forward to access Jenkins"
    echo "   kubectl port-forward svc/$JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE 8080:8080"
    echo "   Then access: http://localhost:8080"
fi

echo ""
echo "📝 Useful Commands:"
echo "==================="
echo "Check Jenkins status:"
echo "  kubectl get pods -n $JENKINS_NAMESPACE"
echo ""
echo "Get Jenkins logs:"
echo "  kubectl logs -f deployment/$JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE"
echo ""
echo "Port forward to access Jenkins locally:"
echo "  kubectl port-forward svc/$JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE 8080:8080"
echo ""
echo "Check LoadBalancer status:"
echo "  kubectl get svc $JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE"
echo ""
echo "Uninstall Jenkins:"
echo "  helm uninstall $JENKINS_RELEASE_NAME -n $JENKINS_NAMESPACE"
echo "  kubectl delete namespace $JENKINS_NAMESPACE"
echo ""

# Clean up temporary files
rm -f jenkins-values.yaml jenkins-agent-rbac.yaml

echo "✅ Script completed successfully!"
echo ""
echo "🔧 Next Steps:"
echo "=============="
echo "1. Wait for the LoadBalancer to get an external IP (may take 2-5 minutes)"
echo "2. Access Jenkins using the URL above"
echo "3. Login with username 'admin' and password '$JENKINS_ADMIN_PASSWORD'"
echo "4. Configure your first pipeline!"
EOF

