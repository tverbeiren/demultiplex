# Snakemake Integration for Demultiplex Project

This document describes the integration of the Snakemake workflow into the existing demultiplex project structure.

## Overview

The Snakemake workflow (`src/demultiplex_snakemake/`) provides a complete alternative implementation of the demultiplexing pipeline originally implemented in Nextflow/Viash. Both implementations offer the same functionality but use different workflow management systems.

## Workflow Comparison

| Aspect | Nextflow/Viash | Snakemake |
|--------|----------------|-----------|
| **Location** | `src/demultiplex/main.nf` | `src/demultiplex_snakemake/Snakefile` |
| **Configuration** | `src/demultiplex/config.vsh.yaml` | `src/demultiplex_snakemake/config/config.yaml` |
| **Dependencies** | Viash + biobox components | Python scripts + containers |
| **Execution** | `nextflow run ...` | `snakemake ...` or `./run.sh` |
| **Resource Labels** | `src/config/labels.config` | `config/config.yaml` resources section |
| **Testing** | `src/demultiplex/test.nf` | `src/demultiplex_snakemake/test.sh` |

## Functional Equivalence

Both workflows implement the same logical steps:

### 1. Preprocessing
- **Nextflow**: `untar.run()` + `detect_demultiplexer.run()`
- **Snakemake**: `untar_input` + `detect_demultiplexer` rules

### 2. Demultiplexing
- **Nextflow**: `bcl_convert.run()` / `bases2fastq.run()` (conditional)
- **Snakemake**: `bcl_convert` / `bases2fastq` rules (conditional)

### 3. Quality Control
- **Nextflow**: `fastqc.run()` + `multiqc.run()`
- **Snakemake**: `run_fastqc_all` + `multiqc` rules

### 4. Output Organization
- **Nextflow**: `publish.run()` (via `src/io/publish`)
- **Snakemake**: `publish_outputs` rule

## Configuration Mapping

### Nextflow Arguments → Snakemake Config

```yaml
# Nextflow CLI                    # Snakemake config.yaml
--input /path/to/data       →     input: "/path/to/data"
--id my_run                 →     sample_id: "my_run"
--demultiplexer bclconvert  →     demultiplexer: "bclconvert"
--publish_dir output/       →     publish_dir: "output"
--skip_copycomplete_check   →     skip_copycomplete_check: true
```

### Resource Labels Mapping

```yaml
# Nextflow labels.config          # Snakemake config.yaml
withLabel: lowcpu { cpus = 8 }  →  resources.lowcpu: 8
withLabel: highmem { mem = 64GB} →  resources.highmem: "64GB"
```

## Usage Examples

### Running Equivalent Workflows

#### Nextflow Version
```bash
nextflow run src/demultiplex/main.nf \
  --input /path/to/data \
  --id my_run \
  --publish_dir output/ \
  -profile docker
```

#### Snakemake Version
```bash
cd src/demultiplex_snakemake
# Edit config/config.yaml:
# input: "/path/to/data"
# sample_id: "my_run"
# publish_dir: "output"

./run.sh --config config/config.yaml --cores 8
```

## Container Strategy

### Nextflow/Viash
- Uses Viash dependencies from biobox repository
- Containers managed by Viash configuration
- Profiles define container execution (docker, singularity)

### Snakemake
- Direct container specification in configuration
- Same underlying tools (bclconvert, bases2fastq, fastqc, multiqc)
- Native Snakemake container integration

## Integration with Existing Project

The Snakemake workflow is designed to coexist with the existing Nextflow implementation:

1. **Independent Operation**: Can be used standalone without affecting Nextflow components
2. **Shared Resources**: Uses same test data structure (when available)
3. **Compatible Outputs**: Produces equivalent output structure
4. **Common Configuration Patterns**: Follows similar parameter naming conventions

## Migration Guide

### For Users
1. **Familiar Interface**: Use `./run.sh` instead of `nextflow run`
2. **YAML Configuration**: Edit `config/config.yaml` instead of CLI arguments
3. **Same Outputs**: Results have identical structure and content

### For Developers
1. **Rule-based Development**: Add new rules in `rules/` directory
2. **Python Scripts**: Implement logic in `scripts/` directory
3. **Container Integration**: Update container specifications in config
4. **Testing**: Use `test.sh` for validation

## Advantages of Each Approach

### Nextflow/Viash Benefits
- **Mature Ecosystem**: Established bioinformatics workflow framework
- **Viash Integration**: Powerful component management
- **Channel-based**: Excellent for complex data flow patterns
- **Cloud Native**: Built-in support for cloud execution

### Snakemake Benefits
- **Python Integration**: Native Python ecosystem support
- **Dependency Resolution**: Sophisticated file-based dependency tracking
- **Resource Optimization**: Fine-grained resource management
- **Academic Adoption**: Widely used in computational biology research

## Maintenance Strategy

Both implementations should be maintained in parallel:

1. **Feature Parity**: Keep both versions functionally equivalent
2. **Bug Fixes**: Apply fixes to both implementations
3. **Testing**: Validate both workflows with same test data
4. **Documentation**: Maintain usage examples for both approaches

This dual-implementation strategy allows users to choose the workflow management system that best fits their infrastructure and preferences while maintaining the same core demultiplexing functionality.