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
# Run with default configuration (uses containers automatically)
./run.sh --config config/config.yaml --cores 8

# Dry run to check workflow
./run.sh --config config/config.yaml --dryrun

# Test with reduced resources
./run.sh --config config/test_config.yaml --cores 4

# Disable containers (not recommended - tools may not be available)
./run.sh --config config/config.yaml --cores 8 --no-containers
```

#### Option 2: Running Snakemake directly
```bash
# Run with containers (recommended)
snakemake --configfile config/config.yaml --cores 8 --use-singularity

# Dry run to check workflow  
snakemake --configfile config/config.yaml --cores 8 --use-singularity --dryrun

# Without containers (not recommended)
snakemake --configfile config/config.yaml --cores 8
```

> **⚠️ Important**: When running Snakemake directly, use `--configfile` to specify the config file, **not** `--config`. The `--config` option is for setting individual config values as key=value pairs.

> **🐳 Container Support**: The workflow uses Docker/Singularity containers for reproducibility. Use `--use-singularity` flag or the run script which enables containers by default.

### Configuration

**Before running the workflow**, you must edit `config/config.yaml` to specify your input data:

#### Required Settings:
- `input`: **REQUIRED** - Path to input directory containing sequencing data or tarball
- `sample_id`: Unique identifier for the run (default: "run")

#### Optional Settings:
- `publish_dir`: Output directory for final results (default: "output")
- `demultiplexer`: Demultiplexer to use - will auto-detect if not specified
- `run_information`: Sample sheet path - will auto-detect if not specified

#### Example configuration:
```yaml
sample_id: "my_run"
input: "/path/to/sequencing/data"           # ⚠️  MUST BE SET!
publish_dir: "results"                      # No trailing slash needed
demultiplexer: "bclconvert"                 # or "bases2fastq", or "" for auto-detect
skip_copycomplete_check: false
```

> **⚠️ Important**: The workflow will fail if no `input` path is specified. Make sure to set this before running!

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

## Conditional Demultiplexing

The workflow automatically handles two different demultiplexing tools:

- **Illumina data**: Uses `bcl_convert` with `SampleSheet.csv`
- **Element Biosciences data**: Uses `bases2fastq` with `RunManifest.csv`

### How It Works:
1. **Auto-detection**: The `detect_demultiplexer` rule examines the input directory for `SampleSheet.csv` or `RunManifest.csv`
2. **Conditional execution**: Both `bcl_convert` and `bases2fastq` rules are defined, but only the appropriate one runs based on detection
3. **Rule resolution**: The `ruleorder: bcl_convert > bases2fastq` directive resolves any ambiguity in Snakemake's DAG building
4. **Runtime checking**: Each rule checks the detected demultiplexer type and skips execution if it's not the right tool

This approach ensures that:
- ✅ Only the correct demultiplexer runs for your data
- ✅ No manual specification required (though you can override with `demultiplexer` config)
- ✅ The workflow handles both data types seamlessly

## Container Requirements

The workflow uses the following containers:
- `nfcore/bclconvert:4.2.7` - For Illumina demultiplexing
- `elementbiosciences/bases2fastq:1.3.1` - For Element Biosciences demultiplexing  
- `biocontainers/fastqc:v0.12.1_cv1` - For FASTQ quality control
- `multiqc/multiqc:1.23` - For report generation
- `quay.io/biocontainers/illumina-interop:1.3.1--h9f5acd7_1` - For InterOp summary generation
- `debian:stable-slim` - For file extraction
- `python:3.11-slim` - For Python scripts and default operations

**Container Support Required**: This workflow requires Docker or Singularity to be installed and available. The containers are automatically pulled when needed.
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
The workflow requires containers for reproducible execution. Enable container support:
```bash
# Using Docker (recommended)
snakemake --configfile config/config.yaml --cores 8 --use-singularity

# Using Conda environments (alternative)
snakemake --configfile config/config.yaml --cores 8 --use-conda

# Disable containers (not recommended - tools may not be available)
snakemake --configfile config/config.yaml --cores 8
```

### Scheduler Options
If you encounter ILP solver issues, you can force the greedy scheduler:
```bash
# Force greedy scheduler (avoids ILP solver issues)
snakemake --configfile config/config.yaml --cores 8 --scheduler greedy

# Or using the run script
./run.sh --config config/config.yaml --cores 8 --scheduler greedy
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
2. **Missing input path**: If you get "No input path specified" or "Missing input files", you need to set the `input` field in your config file to point to your sequencing data.
3. **Double slash warnings**: If you see warnings about double slashes in file paths, remove trailing slashes from directory paths in your config (e.g., use `"output"` instead of `"output/"`).
4. **Ambiguous rules error**: If you get "AmbiguousRuleException" about `bcl_convert` and `bases2fastq`, this should be resolved by the `ruleorder` directive. The workflow automatically uses the appropriate demultiplexer based on auto-detection.
5. **ILP solver warnings**: If you see "Failed to solve scheduling problem with ILP solver, falling back to greedy scheduler", this is non-critical. Snakemake will use the greedy scheduler instead. To fix: install CBC solver with `conda install coincbc` or ignore the warning as it doesn't affect workflow execution.
6. **Container/tool not found**: The workflow requires Docker/Singularity containers for reproducibility. Ensure containers are enabled with `--use-singularity` flag or use the run script which enables them by default.
7. **Missing input files**: Ensure input path exists and is accessible
8. **Resource limits**: Adjust resource settings in configuration
9. **Permission errors**: Ensure write permissions for output directories

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