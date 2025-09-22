# Demultiplex Snakemake Workflow

This directory contains a Snakemake version of the demultiplexing workflow, translated from the original Nextflow/Viash implementation.

## Overview

The workflow performs the following steps:

1. **Preprocessing**: Optional untar of input data and demultiplexer detection
2. **Demultiplexing**: Runs either `bclconvert` (Illumina) or `bases2fastq` (Element Biosciences)
3. **Quality Control**: FastQC analysis on generated FASTQ files
4. **Reporting**: MultiQC report generation
5. **Publishing**: Organization of final outputs

## Features

- **Automatic detection** of demultiplexer type and run information files
- **Conditional execution** based on detected/specified demultiplexer
- **Resource management** with configurable CPU/memory settings
- **Container support** for reproducible execution
- **Modular design** with separate rule files for different workflow stages

## Quick Start

### Basic Usage

#### Option 1: Using the run script (Recommended)
```bash
# Run with default configuration
./run.sh --config config/config.yaml --cores 8

# Dry run to check workflow
./run.sh --config config/config.yaml --dryrun

# Test with reduced resources
./run.sh --config config/test_config.yaml --cores 4
```

#### Option 2: Running Snakemake directly
```bash
# Run with default configuration (note: use --configfile, not --config)
snakemake --configfile config/config.yaml --cores 8

# Dry run to check workflow  
snakemake --configfile config/config.yaml --cores 8 --dryrun

# Test with reduced resources
snakemake --configfile config/test_config.yaml --cores 4
```

> **⚠️ Important**: When running Snakemake directly, use `--configfile` to specify the config file, **not** `--config`. The `--config` option is for setting individual config values as key=value pairs.

### Configuration

Edit `config/config.yaml` to specify:

- `input`: Path to input directory or tarball
- `sample_id`: Unique identifier for the run
- `publish_dir`: Output directory for final results
- `demultiplexer`: Optional, will auto-detect if not specified
- `run_information`: Optional, will auto-detect if not specified

Example configuration:
```yaml
sample_id: "my_run"
input: "/path/to/sequencing/data"
publish_dir: "results/"
demultiplexer: "bclconvert"  # or "bases2fastq", or "" for auto-detect
skip_copycomplete_check: false
```

## Directory Structure

```
src/demultiplex_snakemake/
├── Snakefile              # Main workflow file
├── config/
│   ├── config.yaml        # Main configuration
│   └── test_config.yaml   # Test configuration
├── rules/
│   ├── preprocessing.smk  # Untar and detection rules
│   ├── demultiplexing.smk # Demultiplexing rules
│   ├── quality_control.smk # FastQC and MultiQC rules
│   └── postprocessing.smk # Output organization rules
├── scripts/
│   ├── detect_demultiplexer.py
│   ├── gather_fastqs_and_validate.py
│   ├── run_fastqc.py
│   ├── combine_samples.py
│   └── publish_outputs.py
├── run.sh                 # Execution script
└── README.md             # This file
```

## Rule Dependencies

The workflow follows this dependency chain:

```
Input → untar_input → detect_demultiplexer → get_detected_values
   ↓
interop_summary_to_csv → bcl_convert/bases2fastq → gather_fastqs_and_validate
   ↓
run_fastqc_all → combine_samples → multiqc → organize_outputs → publish_outputs
```

## Container Requirements

The workflow uses the following containers:
- `nfcore/bclconvert:4.2.7` - For Illumina demultiplexing
- `elementbiosciences/bases2fastq:1.3.1` - For Element Biosciences demultiplexing  
- `biocontainers/fastqc:v0.12.1_cv1` - For FASTQ quality control
- `multiqc/multiqc:1.23` - For report generation
- `illumina/interop:1.3.1` - For InterOp summary generation
- `debian:stable-slim` - For file extraction
- `ubuntu:22.04` - Default container for scripts

## Resource Configuration

Resources can be configured in the config file:

```yaml
resources:
  verylowcpu: 2    # Cores for low-intensity tasks
  lowcpu: 8        # Cores for moderate tasks  
  midcpu: 16       # Cores for high-intensity tasks
  highcpu: 32      # Cores for very high-intensity tasks
  
  verylowmem: "4GB"  # Memory for low-memory tasks
  lowmem: "8GB"      # Memory for moderate tasks
  midmem: "16GB"     # Memory for high-memory tasks
  highmem: "64GB"    # Memory for very high-memory tasks
```

## Execution Profiles

### Local Execution
```bash
./run.sh --config config/config.yaml --cores 8
```

### Cluster Execution
```bash
# Using SLURM
snakemake --configfile config/config.yaml --profile slurm --jobs 100

# Using other cluster systems - configure appropriate profile
```

### Container Execution
The workflow automatically uses containers when available. To disable:
```bash
snakemake --configfile config/config.yaml --cores 8 --use-singularity false
```

## Outputs

The workflow generates the following outputs in the `publish_dir`:

- `fastq/` - Demultiplexed FASTQ files
- `qc/multiqc_report.html` - Quality control report
- `qc/sample_qc/` - Individual FastQC results
- `run_information.csv` - Sample sheet used for demultiplexing
- `demultiplexer_logs/` - Logs from the demultiplexing process

## Troubleshooting

### Common Issues

1. **Wrong config option**: If you get "Invalid config definition: Config entries have to be defined as name=value pairs", you're using `--config` instead of `--configfile`. Use `--configfile config/config.yaml` to specify the config file.
2. **Missing input files**: Ensure input path exists and is accessible
3. **Container not found**: Check container availability or disable container usage
4. **Resource limits**: Adjust resource settings in configuration
5. **Permission errors**: Ensure write permissions for output directories

### Debug Mode
```bash
# Run with verbose output
./run.sh --config config/config.yaml --dryrun -v

# Check workflow graph
snakemake --configfile config/config.yaml --dag | dot -Tpdf > workflow.pdf
```

## Comparison with Nextflow Version

This Snakemake implementation maintains the same functionality as the original Nextflow workflow:

| Feature | Nextflow | Snakemake | Notes |
|---------|----------|-----------|-------|
| Demultiplexer detection | ✅ | ✅ | Auto-detection logic preserved |
| Conditional execution | ✅ | ✅ | Based on detected demultiplexer |
| Resource management | ✅ | ✅ | Configurable CPU/memory settings |
| Container support | ✅ | ✅ | Docker/Singularity support |
| Quality control | ✅ | ✅ | FastQC + MultiQC reporting |
| Output publishing | ✅ | ✅ | Organized final outputs |

The main differences:
- **Configuration**: YAML-based instead of Nextflow config
- **Execution**: Different command-line interface
- **Dependency management**: Snakemake-native instead of Viash
- **Parallelization**: Snakemake-managed instead of Nextflow channels