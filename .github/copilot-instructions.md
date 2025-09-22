# Demultiplex.vsh

Demultiplex.vsh is a Viash-based workflow for demultiplexing raw RNA-seq sequencing data from Illumina and Element Biosciences sequencers. The workflow is built with modular components using Viash and executed with Nextflow.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites and Installation
- **CRITICAL**: Install the exact versions specified below. Version mismatches will cause build failures.
- Install Java 17+ (OpenJDK 17 is confirmed working)
- Install Docker for containerized execution
- Install Viash v0.9.4: Download from https://github.com/viash-io/viash/releases/tag/0.9.4
- Install Nextflow: Download from https://www.nextflow.io/docs/latest/install.html

### Environment Setup Commands (Run these first)
```bash
# Verify Java version (must be 17+)
java -version

# Install Viash v0.9.4 (try methods in order):
# Method 1: Try official JAR download
wget -O viash.jar https://github.com/viash-io/viash/releases/download/0.9.4/viash-0.9.4.jar && \
echo '#!/bin/bash\njava -jar "$(dirname "$0")/viash.jar" "$@"' > viash && chmod +x viash

# Method 2: If JAR not available, try Docker-based approach
# Note: Docker image name may vary - check https://hub.docker.com/r/viashio/viash
cat > viash << 'EOF'
#!/bin/bash
docker run --rm -v "$(pwd):/work" -w /work viashio/viash:0.9.4 "$@"
EOF
chmod +x viash

# Method 3: Build from source (requires SBT)
# git clone https://github.com/viash-io/viash.git /tmp/viash-build
# cd /tmp/viash-build && git checkout 0.9.4 && sbt assembly
# cp target/scala-*/viash-*.jar ./viash.jar

# Install Nextflow (try multiple methods)
# Method 1: Official installer
curl -s https://get.nextflow.io | bash && chmod +x nextflow

# Method 2: Direct download if official installer fails
# wget https://github.com/nextflow-io/nextflow/releases/download/v24.10.1/nextflow && chmod +x nextflow

# Verify installations
./viash --version  # Should show 0.9.4
./nextflow -version  # Should show 24.x+
docker --version  # Verify Docker is available

# Export to PATH for convenience
export PATH="$(pwd):$PATH"
```

### Build Process
- **CRITICAL**: The build process uses `viash ns build` which can take 15-45 minutes depending on your system. NEVER CANCEL these builds.
- **TIMEOUT WARNING**: Set timeouts to at least 60 minutes for build commands.
- **NETWORK DEPENDENCY**: Build requires internet access to download biobox components from viash-hub

```bash
# Navigate to repository root
cd /path/to/demultiplex

# Build all components (TAKES 15-45 MINUTES - NEVER CANCEL)
viash ns build --setup cb
# Alternative: Build specific component only (faster for development)
viash ns build --setup cb -q runner
viash ns build --setup cb -q demultiplex

# Verify build completed successfully
ls target/nextflow/  # Should show: demultiplex/ and runner/ directories
```

### Test Data Setup
```bash
# Create test data directory (required for local testing)
mkdir -p testData

# Note: Integration tests download test data automatically from:
# - gs://viash-hub-resources/demultiplex/v3/
# - https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/testdata/

# For offline testing, manually download test files:
# wget -O testData/200624_A00834_0183_BHMTFYDRXX.tar.gz <test_data_url>
```

### Testing Commands
- **CRITICAL**: Integration tests take 20-60 minutes per workflow. NEVER CANCEL test runs.
- **TIMEOUT WARNING**: Set timeouts to at least 90 minutes for test commands.

```bash
# Test runner workflow (TAKES 20-40 MINUTES - NEVER CANCEL)
./src/runner/integration_tests.sh

# Test demultiplex workflow (TAKES 40-60 MINUTES - NEVER CANCEL)  
./src/demultiplex/integration_tests.sh

# Test gather_fastqs_and_validate workflow (TAKES 30-50 MINUTES - NEVER CANCEL)
./src/dataflow/gather_fastqs_and_validate/integration_tests.sh
```

### Running Workflows

#### Runner Workflow (Simplified, Opinionated)
```bash
# Using Viash Hub (recommended - requires SCM setup)
nextflow run vsh/demultiplex \
  -r v0.3.11 \
  -main-script target/nextflow/runner/main.nf \
  --input "gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2" \
  --demultiplexer bclconvert \
  --skip_copycomplete_check \
  --publish_dir example_output/ \
  -profile docker \
  -c src/config/labels.config

# Using local build (after viash ns build)
nextflow run . \
  -main-script target/nextflow/runner/main.nf \
  --input "gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2" \
  --demultiplexer bclconvert \
  --skip_copycomplete_check \
  --publish_dir example_output/ \
  -profile docker,local \
  -c src/config/labels.config

# Using local test data (if available)
nextflow run . \
  -main-script target/nextflow/runner/main.nf \
  --input testData/200624_A00834_0183_BHMTFYDRXX.tar.gz \
  --demultiplexer bclconvert \
  --skip_copycomplete_check \
  --publish_dir example_output/ \
  -profile docker,local \
  -c src/config/labels.config
```

#### Demultiplex Workflow (Full-Featured)
```bash
# Full workflow with custom ID and parameters
nextflow run . \
  -main-script target/nextflow/demultiplex/main.nf \
  --id test_run \
  --input "gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2" \
  --demultiplexer bclconvert \
  --skip_copycomplete_check \
  -profile docker,local \
  -c src/config/labels.config

# With local test data
nextflow run . \
  -main-script target/nextflow/demultiplex/main.nf \
  --id test_run \
  --input testData/200624_A00834_0183_BHMTFYDRXX.tar.gz \
  --demultiplexer bclconvert \
  --skip_copycomplete_check \
  -profile docker,local \
  -c src/config/labels.config
```

## Validation Requirements

### Manual Testing Scenarios
After making changes, ALWAYS test these complete user scenarios:

1. **Basic Runner Test**:
   ```bash
   # This should complete successfully and produce FASTQ files
   nextflow run . \
     -main-script src/runner/test.nf \
     -entry test \
     -profile docker,local \
     -c src/config/labels.config
   ```

2. **Demultiplex Illumina Test**:
   ```bash
   # This tests Illumina data processing
   nextflow run . \
     -main-script src/demultiplex/test.nf \
     -profile docker,no_publish,local \
     -entry test_illumina \
     -c src/config/labels.config \
     --resources_test https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/testdata/NovaSeq6000/
   ```

3. **Element Biosciences Test**:
   ```bash
   # This tests bases2fastq processing
   nextflow run . \
     -main-script src/demultiplex/test.nf \
     -profile docker,no_publish,local \
     -entry test_bases2fastq \
     -c src/config/labels.config
   ```

### Expected Outputs
- FASTQ files in the output directory
- MultiQC report with quality metrics
- Demultiplexer logs
- Sample QC outputs from FastQC

## Build and Test Time Expectations

- **viash ns build**: 15-45 minutes (depends on network and system)
- **Runner integration test**: 20-40 minutes
- **Demultiplex integration test**: 40-60 minutes  
- **Individual test entries**: 10-30 minutes each
- **NEVER CANCEL**: These operations can appear to hang but are processing Docker images and large datasets

## Project Structure

### Repository Layout
```
.
├── README.md                    # Main documentation
├── _viash.yaml                  # Main Viash configuration
├── main.nf                      # Top-level Nextflow entry point  
├── nextflow.config              # Main Nextflow configuration
├── src/                         # Source components
│   ├── config/
│   │   └── labels.config        # Resource allocation settings
│   ├── runner/                  # Simplified workflow
│   │   ├── config.vsh.yaml     # Component configuration
│   │   ├── main.nf              # Workflow implementation
│   │   ├── test.nf              # Unit tests
│   │   └── integration_tests.sh # Integration tests
│   ├── demultiplex/            # Full-featured workflow
│   │   ├── config.vsh.yaml     # Component configuration
│   │   ├── main.nf              # Workflow implementation
│   │   ├── test.nf              # Unit tests
│   │   └── integration_tests.sh # Integration tests
│   ├── dataflow/               # Data processing components
│   └── io/                     # I/O utility components
└── target/                     # Generated artifacts (after build)
    └── nextflow/
        ├── runner/             # Built runner workflow
        │   └── main.nf         # Executable Nextflow workflow
        └── demultiplex/        # Built demultiplex workflow
            └── main.nf         # Executable Nextflow workflow
```

### Key Workflows
- `src/runner/`: Simplified workflow with predefined output structure
- `src/demultiplex/`: Full-featured workflow with fine-grained control
- `src/dataflow/gather_fastqs_and_validate/`: Validation and gathering component
- `src/dataflow/combine_samples/`: Sample combination component

### Generated Artifacts (post-build)
- `target/nextflow/runner/main.nf`: Executable runner workflow
- `target/nextflow/demultiplex/main.nf`: Executable demultiplex workflow
- These are created by `viash ns build` and required for execution

### Configuration Files
- `src/config/labels.config`: Resource allocation settings (CPU/memory)
- `nextflow.config`: Main Nextflow configuration
- `_viash.yaml`: Viash project configuration

### Test Data
- Test data location: `gs://viash-hub-resources/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2`
- Local test data downloaded automatically during test runs

## Dependencies and External Tools

### Required for Building
- **Viash v0.9.4**: Component framework (exact version critical)
- **Nextflow**: Workflow management system  
- **Docker**: Container runtime for component execution
- **Java 17+**: Required by both Viash and Nextflow

### External Components (Auto-downloaded)
- biobox components: bcl_convert, bases2fastq, fastqc, multiqc
- These are automatically pulled from viash-hub during build

## Common Issues and Solutions

### Installation Issues
- **"viash command not found"**: Ensure Viash is installed and in PATH, or use full path ./viash
- **"Java version incompatible"**: Use Java 17 or higher (verify with `java -version`)
- **"Docker permission denied"**: Add user to docker group (`sudo usermod -aG docker $USER`) or use sudo
- **Viash installation fails**: Try alternative installation methods in order (JAR, Docker, source build)

### Build Issues
- **"viash command not found"**: Ensure Viash is installed and in PATH
- **"Java version incompatible"**: Use Java 17 or higher
- **Network timeouts during build**: Be patient, builds download many Docker images and biobox components
- **"Cannot resolve dependencies"**: Ensure internet access to viash-hub.com and biobox repositories
- **Docker image pull failures**: Check Docker Hub access and try `docker pull viashio/viash:0.9.4` manually

### Test Issues  
- **Tests fail with "resources not found"**: Ensure internet connectivity for test data download from gs:// URLs
- **"No such file testData/..."**: Tests expect `testData/` directory with specific files - may auto-download
- **Memory errors**: Reduce CPU/memory settings in `src/config/labels.config`
- **Nextflow work directory full**: Clean with `nextflow clean -f` or `rm -rf work/`

### Runtime Issues
- **"Cannot download test data"**: Check network connectivity to gs:// URLs and raw.githubusercontent.com
- **Missing Docker images**: Run `viash ns build --setup cb` to rebuild
- **"target/nextflow not found"**: Must run `viash ns build` first to generate Nextflow workflows
- **Permission denied on output**: Ensure write permissions to output directory

## Troubleshooting Commands

```bash
# Check component status
viash ns list

# Rebuild specific component
viash ns build --setup cb -q runner

# Check Docker images
docker images | grep viash

# Check Nextflow work directory
ls -la work/

# Clean Nextflow cache
nextflow clean -f
```

## SCM Configuration for Viash Hub

To use workflows from Viash Hub, create `$HOME/.nextflow/scm` with:
```
providers {
   vsh {
    platform = 'gitlab'
    server = "packages.viash-hub.com"
  }
}
```

## Resource Tuning

Edit `src/config/labels.config` to adjust resource allocation:
```nextflow
withLabel: verylowcpu { cpus = 2 }
withLabel: lowcpu { cpus = 8 }  
withLabel: midcpu { cpus = 16 }
withLabel: highcpu { cpus = 32 }

withLabel: verylowmem { memory = { get_memory( 4.GB * task.attempt ) } }
withLabel: lowmem { memory = { get_memory( 8.GB * task.attempt ) } }
withLabel: midmem { memory = { get_memory( 16.GB * task.attempt ) } }
withLabel: highmem { memory = { get_memory( 64.GB * task.attempt ) } }
```

Use with: `nextflow run -c your_custom.config`