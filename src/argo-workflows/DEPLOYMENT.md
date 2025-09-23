# Argo Workflows Deployment Guide

This document provides instructions for deploying and using the Argo Workflows version of the demultiplex pipeline.

## Prerequisites

1. **Kubernetes cluster** with sufficient resources
2. **Argo Workflows** installed on the cluster
3. **Persistent storage** with ReadWriteMany access mode
4. **Container images** available (internet access for public registries)

## Installation

### 1. Install Argo Workflows

Follow the [official Argo Workflows installation guide](https://argoproj.github.io/argo-workflows/quick-start/):

```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.4/install.yaml
```

### 2. Create Persistent Volume Claim

The workflow requires shared storage for data exchange between steps:

```bash
kubectl apply -f templates/persistent-volume-claim.yaml
```

### 3. Deploy Workflow Template

```bash
kubectl apply -f templates/demultiplex-workflow-template.yaml
```

## Usage

### Running a Workflow

#### Option 1: Using Argo CLI

```bash
# Illumina example
argo submit examples/illumina-example.yaml \
  --parameter input="gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2" \
  --parameter skip_copycomplete_check="true"

# Element Biosciences example
argo submit examples/element-example.yaml \
  --parameter input="http://element-public-data.s3.amazonaws.com/bases2fastq-share/bases2fastq-v2/20230404-bases2fastq-sim-151-151-9-9.tar.gz"
```

#### Option 2: Using kubectl

```bash
kubectl create -f examples/illumina-example.yaml
```

#### Option 3: Custom parameters

Create a custom workflow file:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: my-demultiplex-
  namespace: argo
spec:
  entrypoint: demultiplex-main
  workflowTemplateRef:
    name: demultiplex-workflow-template
  arguments:
    parameters:
    - name: id
      value: "my-run-id"
    - name: input
      value: "/path/to/my/sequencing/data"
    - name: demultiplexer
      value: "bclconvert"  # or "bases2fastq"
    - name: skip_copycomplete_check
      value: "false"
```

### Monitoring Workflows

```bash
# List workflows
argo list

# Get workflow status
argo get <workflow-name>

# View workflow logs
argo logs <workflow-name>

# Watch workflow progress
argo watch <workflow-name>
```

## Parameters

The workflow accepts the following parameters:

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `id` | Unique identifier for the run | No | `"run"` |
| `input` | Path to sequencing data directory or archive | Yes | - |
| `run_information` | Path to sample sheet (auto-detected if empty) | No | `""` |
| `demultiplexer` | Demultiplexer to use (`bclconvert` or `bases2fastq`) | No | Auto-detected |
| `output` | Output directory for FASTQ files | No | `{id}/fastq` |
| `output_sample_qc` | Output directory for QC files | No | `{id}/qc/fastqc` |
| `multiqc_output` | Path for MultiQC report | No | `{id}/qc/multiqc_report.html` |
| `output_run_information` | Output path for run information | No | `{id}/run_information.csv` |
| `demultiplexer_logs` | Output directory for demultiplexer logs | No | `{id}/demultiplexer_logs` |
| `skip_copycomplete_check` | Skip CopyComplete.txt check | No | `"false"` |

## Workflow Steps

The Argo workflow mirrors the Nextflow workflow with these steps:

1. **untar-input** (conditional): Extract compressed input archives
2. **detect-demultiplexer**: Auto-detect demultiplexer and sample sheet
3. **interop-summary-csv** (conditional): Convert Illumina InterOp data to CSV
4. **bcl-convert** (conditional): Run Illumina BCL Convert
5. **bases2fastq** (conditional): Run Element Biosciences bases2fastq
6. **gather-fastqs-validate**: Collect and validate FASTQ files
7. **fastqc**: Run FastQC quality control
8. **combine-samples**: Prepare data for MultiQC
9. **multiqc**: Generate comprehensive QC report

## Resource Requirements

The workflow uses the following resource tiers:

- **Low**: 2 CPU, 4GB RAM
- **Medium**: 4-8 CPU, 8-16GB RAM  
- **High**: 8-16 CPU, 16-64GB RAM

Most intensive steps (bcl-convert, bases2fastq) use high resources.

## Storage Requirements

- **Input data**: Typically 50-500GB for sequencing runs
- **Output data**: Similar size to input
- **Working space**: 2-3x input size recommended
- **Total PVC size**: 1TB+ recommended for most runs

## Container Images

The workflow uses these container images:

- `debian:stable-slim` - For untar operations
- `nextflow/bash:latest` - For bash scripting tasks
- `nfcore/bclconvert:3.9.3` - Illumina BCL Convert
- `elementbiosciences/bases2fastq:0.1.2` - Element Biosciences demultiplexer
- `biocontainers/fastqc:v0.11.9_cv8` - FastQC quality control
- `multiqc/multiqc:v1.11` - MultiQC reporting
- `biocontainers/interop:v1.1.8dfsg-1-deb_cv1` - Illumina InterOp tools

## Troubleshooting

### Common Issues

1. **PVC Access Issues**: Ensure your storage class supports ReadWriteMany
2. **Container Pull Errors**: Check internet connectivity and image availability
3. **Resource Limits**: Increase node resources or adjust workflow resource requests
4. **Input Data Access**: Ensure containers can access input data locations

### Debugging

```bash
# View workflow logs
argo logs <workflow-name>

# Describe workflow for detailed status
kubectl describe workflow <workflow-name>

# Check pod logs for specific steps
kubectl logs <pod-name>
```

### Resource Adjustment

Modify resource requirements in the workflow template:

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4"
  limits:
    memory: "16Gi"
    cpu: "8"
```

## Comparison with Nextflow Version

| Feature | Nextflow | Argo Workflows |
|---------|----------|----------------|
| **Language** | DSL2 | YAML |
| **Execution** | Nextflow engine | Kubernetes native |
| **Scaling** | Single node or cluster | Kubernetes cluster |
| **Resource Management** | Nextflow profiles | Kubernetes resources |
| **State Management** | Work directories | Persistent volumes |
| **Conditional Logic** | Native DSL | YAML expressions |
| **Monitoring** | Nextflow Tower | Argo UI |

## Migration Notes

When migrating from Nextflow to Argo Workflows:

1. **Data Paths**: Nextflow uses relative paths; Argo uses absolute paths in persistent volumes
2. **State Management**: Nextflow passes state objects; Argo passes individual parameters
3. **Conditional Execution**: Argo uses `when` conditions instead of `runIf`
4. **Resource Labels**: Nextflow labels become Argo resource specifications
5. **File Handling**: Consider persistent volume mount points for file operations

## Security Considerations

1. **Service Accounts**: Use dedicated service accounts for workflows
2. **RBAC**: Apply appropriate role-based access controls
3. **Network Policies**: Restrict network access as needed
4. **Image Security**: Use trusted container registries
5. **Secrets**: Store sensitive data in Kubernetes secrets