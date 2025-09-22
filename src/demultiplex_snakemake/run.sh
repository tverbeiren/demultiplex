#!/bin/bash

# Run script for demultiplex Snakemake workflow

set -e

# Default parameters
CONFIG_FILE="config/config.yaml"
CORES=8
DRYRUN=false
PROFILE=""

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
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config FILE    Configuration file (default: config/config.yaml)"
            echo "  --cores N        Number of cores to use (default: 8)"
            echo "  --dryrun         Perform a dry run"
            echo "  --profile NAME   Snakemake profile to use"
            echo "  --help           Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --config config/test_config.yaml --cores 4 --dryrun"
            exit 0
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

# Add other useful options
SNAKEMAKE_CMD="$SNAKEMAKE_CMD --printshellcmds --reason"

echo "Running Snakemake with command:"
echo "$SNAKEMAKE_CMD"
echo ""

# Execute
eval $SNAKEMAKE_CMD