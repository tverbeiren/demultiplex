#!/bin/bash

set -e

echo "Testing Snakemake demultiplex workflow..."

# Test 1: Dry run with test configuration
echo "Test 1: Dry run with test configuration"
snakemake -s test_simple.smk --configfile config/test_config.yaml --dryrun

# Test 2: Execute simple test
echo "Test 2: Execute simple test"
snakemake -s test_simple.smk --configfile config/test_config.yaml --cores 1

# Verify outputs
if [[ -f "test_run/test_complete.flag" ]]; then
    echo "✅ Simple test completed successfully"
    cat test_run/test_complete.flag
else
    echo "❌ Simple test failed - no completion flag found"
    exit 1
fi

# Test 3: Dry run of full workflow (should show structure)
echo "Test 3: Dry run of full workflow"
if snakemake --configfile config/test_config.yaml --dryrun 2>&1 | grep -q "MissingInputException"; then
    echo "✅ Full workflow dry run shows expected structure (missing inputs as expected)"
else
    echo "⚠️  Full workflow dry run completed (unexpected but not necessarily wrong)"
fi

# Cleanup
rm -rf test_run/
rm -rf .snakemake/

echo "All tests passed! ✅"