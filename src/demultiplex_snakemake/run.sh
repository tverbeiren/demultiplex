#!/bin/bash

# Run script for demultiplex Snakemake workflow

set -e

# Default parameters
CONFIG_FILE="config/config.yaml"
CORES=8
DRYRUN=false
PROFILE=""
SCHEDULER=""
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
        --help)
            echo "Usage: $0 [OPTIONS] [-- EXTRA_SNAKEMAKE_OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config FILE      Configuration file (default: config/config.yaml)"
            echo "  --cores N          Number of cores to use (default: 8)"
            echo "  --dryrun           Perform a dry run"
            echo "  --profile NAME     Snakemake profile to use"
            echo "  --scheduler NAME   Scheduler to use (greedy, ilp)"
            echo "  --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --config config/test_config.yaml --cores 4 --dryrun"
            echo "  $0 --config config/config.yaml --scheduler greedy"
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

# Add any extra arguments
if [[ -n "$EXTRA_ARGS" ]]; then
    SNAKEMAKE_CMD="$SNAKEMAKE_CMD $EXTRA_ARGS"
fi

echo "Running Snakemake with command:"
echo "$SNAKEMAKE_CMD"
echo ""

# Execute
eval $SNAKEMAKE_CMD