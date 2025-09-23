#!/bin/bash

# Basic YAML syntax validation for Argo Workflows

set -euo pipefail

echo "Validating Argo Workflows YAML files..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGO_DIR="$SCRIPT_DIR"

# Check if yq is available for YAML validation
if ! command -v yq &> /dev/null; then
    echo "Installing yq for YAML validation..."
    # Try to install yq
    if command -v wget &> /dev/null; then
        wget -qO /tmp/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /tmp/yq
        YQ_CMD="/tmp/yq"
    else
        echo "Warning: yq not available. Skipping YAML validation."
        YQ_CMD=""
    fi
else
    YQ_CMD="yq"
fi

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    echo "Validating $file..."
    
    if [ -n "$YQ_CMD" ]; then
        if $YQ_CMD eval '.' "$file" > /dev/null; then
            echo "✓ $file: Valid YAML syntax"
        else
            echo "✗ $file: Invalid YAML syntax"
            return 1
        fi
    else
        # Basic validation with python if yq not available
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "✓ $file: Valid YAML syntax"
        else
            echo "✗ $file: Invalid YAML syntax"
            return 1
        fi
    fi
}

# Function to validate Argo-specific fields
validate_argo_fields() {
    local file="$1"
    echo "Checking Argo Workflows structure in $file..."
    
    if [ -n "$YQ_CMD" ]; then
        # Check for required Argo fields
        if $YQ_CMD eval '.apiVersion' "$file" | grep -qE "(argoproj.io|v1)"; then
            echo "✓ $file: Valid apiVersion"
        else
            echo "✗ $file: Missing or invalid apiVersion"
            return 1
        fi
        
        local kind=$($YQ_CMD eval '.kind' "$file")
        if [[ "$kind" == "Workflow" || "$kind" == "WorkflowTemplate" || "$kind" == "PersistentVolumeClaim" ]]; then
            echo "✓ $file: Valid kind: $kind"
        else
            echo "✗ $file: Invalid kind: $kind"
            return 1
        fi
    fi
}

# Validate all YAML files
VALIDATION_FAILED=0

for yaml_file in \
    "$ARGO_DIR/demultiplex-workflow.yaml" \
    "$ARGO_DIR/templates/demultiplex-workflow-template.yaml" \
    "$ARGO_DIR/templates/persistent-volume-claim.yaml" \
    "$ARGO_DIR/examples/illumina-example.yaml" \
    "$ARGO_DIR/examples/element-example.yaml"; do
    
    if [ -f "$yaml_file" ]; then
        if ! validate_yaml "$yaml_file"; then
            VALIDATION_FAILED=1
        fi
        
        if ! validate_argo_fields "$yaml_file"; then
            VALIDATION_FAILED=1
        fi
    else
        echo "✗ Missing file: $yaml_file"
        VALIDATION_FAILED=1
    fi
    echo ""
done

# Check for required documentation
echo "Checking documentation..."
for doc_file in \
    "$ARGO_DIR/README.md" \
    "$ARGO_DIR/DEPLOYMENT.md"; do
    
    if [ -f "$doc_file" ]; then
        echo "✓ Found: $doc_file"
    else
        echo "✗ Missing: $doc_file"
        VALIDATION_FAILED=1
    fi
done

# Summary
echo ""
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo "🎉 All validations passed!"
    exit 0
else
    echo "❌ Some validations failed!"
    exit 1
fi