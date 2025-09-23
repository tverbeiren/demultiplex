# Integration with Existing Infrastructure

This document provides guidance on integrating the Argo Workflows version of the demultiplex pipeline with existing CI/CD and infrastructure setups.

## Adding to CI/CD Pipelines

### GitHub Actions Integration

Add workflow validation to your GitHub Actions:

```yaml
name: Validate Argo Workflows
on: [push, pull_request]

jobs:
  validate-argo:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Install yq
      run: |
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /usr/local/bin/yq
    
    - name: Validate Argo Workflows
      run: |
        cd src/argo-workflows
        ./validate.sh
```

### GitLab CI Integration

```yaml
validate-argo:
  stage: test
  image: alpine:latest
  before_script:
    - apk add --no-cache wget python3 py3-yaml
    - wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    - chmod +x /usr/local/bin/yq
  script:
    - cd src/argo-workflows
    - ./validate.sh
```

## Kubernetes Integration

### Namespace Setup

Create dedicated namespace for demultiplex workflows:

```bash
kubectl create namespace demultiplex
kubectl label namespace demultiplex purpose=bioinformatics
```

### RBAC Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demultiplex-workflow-sa
  namespace: demultiplex
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: demultiplex-workflow-role
  namespace: demultiplex
rules:
- apiGroups: [""]
  resources: ["pods", "persistentvolumeclaims"]
  verbs: ["create", "get", "list", "watch", "delete"]
- apiGroups: ["argoproj.io"]
  resources: ["workflows", "workflowtemplates"]
  verbs: ["create", "get", "list", "watch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: demultiplex-workflow-binding
  namespace: demultiplex
subjects:
- kind: ServiceAccount
  name: demultiplex-workflow-sa
  namespace: demultiplex
roleRef:
  kind: Role
  name: demultiplex-workflow-role
  apiGroup: rbac.authorization.k8s.io
```

### Storage Classes

Configure appropriate storage classes for different performance needs:

```yaml
# High-performance storage for active workflows
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: demultiplex-fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Long-term storage for archival
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: demultiplex-archive
provisioner: kubernetes.io/aws-ebs
parameters:
  type: sc1
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

## Monitoring and Observability

### Prometheus Metrics

Argo Workflows exposes metrics that can be scraped by Prometheus:

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: argo-workflows-metrics
  namespace: demultiplex
spec:
  selector:
    matchLabels:
      app: workflow-controller
  endpoints:
  - port: metrics
```

### Grafana Dashboard

Example Grafana queries for monitoring demultiplex workflows:

```promql
# Number of running workflows
sum(argo_workflows_count{namespace="demultiplex",status="Running"})

# Workflow success rate
rate(argo_workflows_count{namespace="demultiplex",status="Succeeded"}[5m]) / 
rate(argo_workflows_count{namespace="demultiplex"}[5m])

# Average workflow duration
avg(argo_workflow_info{namespace="demultiplex"} * on(namespace, name) 
    group_right(phase) argo_workflow_status_phase{phase="Succeeded"})
```

## Cost Optimization

### Node Selectors and Taints

Use node selectors to run workflows on cost-optimized instances:

```yaml
# Add to workflow template
nodeSelector:
  node-type: compute-optimized
  spot-instance: "true"

tolerations:
- key: "spot-instance"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

### Resource Requests Tuning

Optimize resource requests based on actual usage patterns:

```yaml
# Example resource optimization
resources:
  requests:
    memory: "8Gi"    # Start conservative
    cpu: "2"         # Actual usage often lower
  limits:
    memory: "16Gi"   # Allow bursting
    cpu: "8"         # Prevent noisy neighbors
```

### Horizontal Pod Autoscaling

Enable HPA for concurrent workflow processing:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: argo-server-hpa
  namespace: demultiplex
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: argo-server
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Data Management

### Input Data Access

Configure access to common data sources:

```yaml
# S3 access via IRSA (AWS)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: demultiplex
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/DemultiplexS3Role

# Google Cloud Storage access
apiVersion: v1
kind: Secret
metadata:
  name: gcs-credentials
  namespace: demultiplex
type: Opaque
data:
  service-account.json: <base64-encoded-service-account>
```

### Output Data Lifecycle

Implement data lifecycle policies:

```yaml
# Backup completed workflows
apiVersion: batch/v1
kind: CronJob
metadata:
  name: workflow-backup
  namespace: demultiplex
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: rclone/rclone:latest
            command:
            - rclone
            - sync
            - /workspace/completed
            - s3:backup-bucket/demultiplex/
            volumeMounts:
            - name: workspace
              mountPath: /workspace
          restartPolicy: OnFailure
```

## Security Considerations

### Network Policies

Restrict network access between workflow components:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demultiplex-network-policy
  namespace: demultiplex
spec:
  podSelector:
    matchLabels:
      app: demultiplex-workflow
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argo
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS for image pulls
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
```

### Pod Security Standards

Enforce security standards:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demultiplex
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Disaster Recovery

### Backup Strategy

```bash
#!/bin/bash
# Backup workflow definitions and data

# Backup workflow templates
kubectl get workflowtemplates -n demultiplex -o yaml > workflowtemplates-backup.yaml

# Backup persistent data
velero backup create demultiplex-backup \
  --include-namespaces demultiplex \
  --storage-location default

# Archive completed workflows
argo archive list -n demultiplex | \
  awk '{print $1}' | \
  xargs -I {} argo archive get {} -o yaml > archived-workflows.yaml
```

### Recovery Procedures

```bash
#!/bin/bash
# Restore from backup

# Restore namespace and RBAC
kubectl apply -f namespace-backup.yaml

# Restore workflow templates
kubectl apply -f workflowtemplates-backup.yaml

# Restore persistent data
velero restore create --from-backup demultiplex-backup
```

## Migration from Nextflow

### Parallel Operation

Run both systems in parallel during migration:

1. **Phase 1**: Deploy Argo alongside existing Nextflow
2. **Phase 2**: Migrate test workflows to Argo
3. **Phase 3**: Gradually migrate production workflows
4. **Phase 4**: Decommission Nextflow infrastructure

### Data Compatibility

Ensure output compatibility between systems:

```bash
# Validation script for output compatibility
#!/bin/bash
diff -r nextflow_output/ argo_output/ \
  --exclude="*.log" --exclude="work/" \
  || echo "Outputs differ - investigate"
```

## Performance Tuning

### Workflow Optimization

```yaml
# Optimize for throughput
parallelism: 10  # Max concurrent steps
activeDeadlineSeconds: 86400  # 24 hour timeout
ttlStrategy:
  secondsAfterCompletion: 3600  # Clean up after 1 hour
  secondsAfterSuccess: 1800     # Clean up successful workflows faster
```

### Cluster Autoscaling

Configure cluster autoscaling for burst workloads:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-autoscaler-status
  namespace: kube-system
data:
  nodes.max: "100"
  scale-down-delay-after-add: "10m"
  scale-down-unneeded-time: "5m"
```

This integration guide should help teams adopt the Argo Workflows version while maintaining operational excellence and cost efficiency.