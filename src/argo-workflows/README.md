# Argo Workflows Implementation

This directory contains Argo Workflows versions of the demultiplex pipeline, converted from the original Nextflow/Viash implementation.

## Overview

The demultiplex pipeline processes raw sequencing data from Illumina and Element Biosciences sequencers, performing demultiplexing, quality control, and reporting. This Argo Workflows version maintains the same functionality while leveraging Kubernetes-native orchestration.

## Quick Start

1. Install Argo Workflows in your cluster
2. Create the persistent volume claim: `kubectl apply -f templates/persistent-volume-claim.yaml`
3. Deploy the workflow template: `kubectl apply -f templates/demultiplex-workflow-template.yaml`
4. Run an example: `argo submit examples/illumina-example.yaml`

## Files Structure

- `demultiplex-workflow.yaml` - Standalone workflow (legacy)
- `templates/demultiplex-workflow-template.yaml` - Reusable WorkflowTemplate
- `templates/persistent-volume-claim.yaml` - Required storage configuration
- `examples/illumina-example.yaml` - Example for Illumina data
- `examples/element-example.yaml` - Example for Element Biosciences data
- `DEPLOYMENT.md` - Detailed deployment and usage guide
- `README.md` - This file

## Workflow Steps

The Argo workflow implements these main steps:

1. **untar** (conditional) - Extract compressed input archives
2. **detect-demultiplexer** - Auto-detect demultiplexer type and sample sheet
3. **interop-summary-csv** (Illumina only) - Convert InterOp data to CSV
4. **bcl-convert** (Illumina) or **bases2fastq** (Element) - Demultiplexing
5. **gather-fastqs-validate** - Collect and validate FASTQ files
6. **fastqc** - Quality control analysis
7. **combine-samples** - Prepare data for reporting
8. **multiqc** - Generate comprehensive QC report

## Key Features

- **Auto-detection**: Automatically detects demultiplexer type from input data
- **Conditional execution**: Only runs steps relevant to the detected platform
- **Resource optimization**: Appropriate CPU/memory allocation for each step
- **Persistent storage**: Uses Kubernetes persistent volumes for data exchange
- **Container-based**: All steps run in purpose-built containers
- **Monitoring**: Full integration with Argo UI for workflow monitoring

## Resource Requirements

- **CPU**: 2-16 cores per step depending on complexity
- **Memory**: 4GB-64GB per step depending on data size
- **Storage**: 1TB+ persistent volume recommended
- **Network**: Internet access for container images and public test data

## Parameters

Key workflow parameters:

- `input` - Path to sequencing data (required)
- `id` - Unique run identifier (default: "run")
- `demultiplexer` - Force specific demultiplexer ("bclconvert" or "bases2fastq")
- `skip_copycomplete_check` - Skip Illumina CopyComplete.txt validation
- Output paths for FASTQ files, QC reports, and logs

## Container Images

Uses validated bioinformatics containers:

- Illumina BCL Convert: `nfcore/bclconvert:3.9.3`
- Element bases2fastq: `elementbiosciences/bases2fastq:0.1.2`
- FastQC: `biocontainers/fastqc:v0.11.9_cv8`
- MultiQC: `multiqc/multiqc:v1.11`
- InterOp tools: `biocontainers/interop:v1.1.8dfsg-1-deb_cv1`

## Migration from Nextflow

This Argo implementation preserves the logic and functionality of the original Nextflow workflow while adapting to Kubernetes-native execution:

- **Same workflow steps**: Identical processing pipeline
- **Same containers**: Uses the same bioinformatics tools
- **Same resource requirements**: Equivalent CPU/memory specifications
- **Same conditional logic**: Platform-specific step execution
- **Same outputs**: Compatible FASTQ files and QC reports

## Getting Help

See `DEPLOYMENT.md` for detailed setup and usage instructions, including troubleshooting common issues and resource tuning guidance.