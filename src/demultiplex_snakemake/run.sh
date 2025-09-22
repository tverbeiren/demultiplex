#!/bin/bash

# Run script for demultiplex Snakemake workflow

set -e

# Default parameters
CONFIG_FILE="config/config.yaml"
CORES=8
DRYRUN=false
PROFILE=""
SCHEDULER=""
USE_CONTAINERS=true
CONTAINER_BACKEND="docker"
EXTRA_ARGS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --dryrun)
            DRYRUN=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --scheduler)
            SCHEDULER="$2"
            shift 2
            ;;
        --no-containers)
            USE_CONTAINERS=false
            shift
            ;;
        --use-docker)
            CONTAINER_BACKEND="docker"
            shift
            ;;
        --use-singularity)
            CONTAINER_BACKEND="singularity"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS] [-- EXTRA_SNAKEMAKE_OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config FILE      Configuration file (default: config/config.yaml)"
            echo "  --cores N          Number of cores to use (default: 8)"
            echo "  --dryrun           Perform a dry run"
            echo "  --profile NAME     Snakemake profile to use"
            echo "  --scheduler NAME     Scheduler to use (greedy, ilp)"
            echo "  --no-containers      Disable container usage (not recommended)"
            echo "  --use-docker         Use Docker for containers (default)"
            echo "  --use-singularity    Use Singularity/Apptainer for containers"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --config config/test_config.yaml --cores 4 --dryrun"
            echo "  $0 --config config/config.yaml --use-docker"
            echo "  $0 --config config/config.yaml --use-singularity --scheduler greedy"
            echo "  $0 --config config/config.yaml -- --verbose --keep-going"
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS="$@"
            break
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build Snakemake command
SNAKEMAKE_CMD="snakemake --configfile $CONFIG_FILE --cores $CORES"

if [[ "$DRYRUN" == true ]]; then
    SNAKEMAKE_CMD="$SNAKEMAKE_CMD --dryrun"
fi

if [[ -n "$PROFILE" ]]; then
    SNAKEMAKE_CMD="$SNAKEMAKE_CMD --profile $PROFILE"
fi

if [[ -n "$SCHEDULER" ]]; then
    SNAKEMAKE_CMD="$SNAKEMAKE_CMD --scheduler $SCHEDULER"
fi

# Add other useful options
SNAKEMAKE_CMD="$SNAKEMAKE_CMD --printshellcmds"

# Enable containers by default
if [[ "$USE_CONTAINERS" == true ]]; then
    # Auto-detect available container runtime
    if [[ "$CONTAINER_BACKEND" == "docker" ]]; then
        if command -v docker &> /dev/null; then
            # Check if we can use Singularity with Docker backend
            if command -v singularity &> /dev/null || command -v apptainer &> /dev/null; then
                echo "Using Singularity/Apptainer with Docker images"
                SNAKEMAKE_CMD="$SNAKEMAKE_CMD --use-singularity"
            else
                echo "Warning: Neither Singularity nor Apptainer found."
                echo "Snakemake requires Singularity/Apptainer to run Docker containers."
                echo "Please install one of the following:"
                echo "  - Singularity: https://docs.sylabs.io/guides/latest/user-guide/"
                echo "  - Apptainer: https://apptainer.org/docs/user/latest/"
                echo "Or run with --no-containers (not recommended)"
                exit 1
            fi
        else
            echo "Docker not found. Please install Docker or use --use-singularity"
            exit 1
        fi
    elif [[ "$CONTAINER_BACKEND" == "singularity" ]]; then
        if command -v singularity &> /dev/null || command -v apptainer &> /dev/null; then
            echo "Using Singularity/Apptainer directly"
            SNAKEMAKE_CMD="$SNAKEMAKE_CMD --use-singularity"
        else
            echo "Error: Neither Singularity nor Apptainer found."
            echo "Please install Singularity or Apptainer, or use --use-docker"
            exit 1
        fi
    fi
fi

# Add any extra arguments
if [[ -n "$EXTRA_ARGS" ]]; then
    SNAKEMAKE_CMD="$SNAKEMAKE_CMD $EXTRA_ARGS"
fi

echo "Running Snakemake with command:"
echo "$SNAKEMAKE_CMD"
echo ""

# Execute
eval $SNAKEMAKE_CMD