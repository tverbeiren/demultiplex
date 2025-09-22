"""
Simple test Snakefile for validation
"""

import os
from pathlib import Path

# Configuration
configfile: "config/test_config.yaml"

# Default wildcards
SAMPLE_ID = config.get("sample_id", "test_run")

# Target rule
rule all:
    input:
        f"{SAMPLE_ID}/test_complete.flag"

rule test_detection:
    """Test the detection logic"""
    output:
        demultiplexer_output = f"{SAMPLE_ID}/detected_demultiplexer.txt",
        run_information_output = f"{SAMPLE_ID}/run_information.csv"
    params:
        user_demultiplexer = config.get("demultiplexer", ""),
        user_run_information = config.get("run_information", ""),
        skip_copycomplete_check = config.get("skip_copycomplete_check", False),
        input_path = config["input"]
    shell:
        """
        # Create test outputs
        mkdir -p $(dirname {output.demultiplexer_output})
        
        # Write test demultiplexer
        if [[ -n "{params.user_demultiplexer}" ]]; then
            echo "{params.user_demultiplexer}" > {output.demultiplexer_output}
        else
            echo "bclconvert" > {output.demultiplexer_output}
        fi
        
        # Write test run information
        if [[ -n "{params.user_run_information}" ]]; then
            cp "{params.user_run_information}" {output.run_information_output}
        else
            echo "# Test sample sheet" > {output.run_information_output}
            echo "[Data]" >> {output.run_information_output}
            echo "Sample_ID,Sample_Name" >> {output.run_information_output}
            echo "Test1,Test Sample 1" >> {output.run_information_output}
        fi
        """

rule test_complete:
    """Mark test as complete"""
    input:
        demultiplexer_output = f"{SAMPLE_ID}/detected_demultiplexer.txt",
        run_information_output = f"{SAMPLE_ID}/run_information.csv"
    output:
        f"{SAMPLE_ID}/test_complete.flag"
    shell:
        """
        echo "Test completed successfully" > {output}
        echo "Demultiplexer: $(cat {input.demultiplexer_output})" >> {output}
        echo "Run information: {input.run_information_output}" >> {output}
        """