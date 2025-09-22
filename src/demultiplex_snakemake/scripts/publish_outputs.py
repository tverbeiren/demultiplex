#!/usr/bin/env python3
"""
Publish outputs to final directory structure

This script is similar to the io/publish component in the original workflow.
"""

import os
import shutil
from pathlib import Path

def main():
    # Get parameters from snakemake
    flag_file = snakemake.input.flag
    published_flag = snakemake.output.published_flag
    publish_dir = Path(snakemake.params.publish_dir)
    sample_id = snakemake.params.sample_id
    
    # Read the organized outputs information
    outputs_info = {}
    with open(flag_file, 'r') as f:
        for line in f:
            if '=' in line:
                key, value = line.strip().split('=', 1)
                outputs_info[key] = value
    
    # Create publish directory
    publish_dir.mkdir(parents=True, exist_ok=True)
    
    # Define output mapping
    output_mapping = {
        "fastq_dir": publish_dir / "fastq",
        "qc_report": publish_dir / "qc" / "multiqc_report.html", 
        "qc_dir": publish_dir / "qc" / "sample_qc",
        "run_info": publish_dir / "run_information.csv"
    }
    
    # Add logs directory if it exists
    if "logs_dir" in outputs_info:
        output_mapping["logs_dir"] = publish_dir / "demultiplexer_logs"
    
    # Copy outputs to publish directory
    for input_key, output_path in output_mapping.items():
        if input_key in outputs_info:
            input_path = Path(outputs_info[input_key])
            
            if input_path.exists():
                print(f"Publishing {input_path} -> {output_path}")
                
                # Create parent directory
                output_path.parent.mkdir(parents=True, exist_ok=True)
                
                # Copy files or directories
                if input_path.is_file():
                    shutil.copy2(input_path, output_path)
                elif input_path.is_dir():
                    if output_path.exists():
                        shutil.rmtree(output_path)
                    shutil.copytree(input_path, output_path)
                
                print(f"Published to {output_path}")
            else:
                print(f"Warning: Input path {input_path} does not exist, skipping")
    
    # List output files
    print("\nFinal outputs:")
    for output_path in output_mapping.values():
        if output_path.exists():
            if output_path.is_file():
                print(f"  File: {output_path}")
            elif output_path.is_dir():
                print(f"  Directory: {output_path}")
                # List contents
                try:
                    contents = list(output_path.iterdir())
                    for item in contents[:10]:  # Show first 10 items
                        print(f"    {item.name}")
                    if len(contents) > 10:
                        print(f"    ... and {len(contents) - 10} more items")
                except:
                    pass
    
    # Create published flag
    with open(published_flag, 'w') as f:
        f.write(f"Published outputs for sample {sample_id}\n")
        f.write(f"Demultiplexer: {outputs_info.get('demultiplexer', 'unknown')}\n")
        f.write(f"Publish directory: {publish_dir}\n")
    
    print(f"\nOutput publishing completed. Results available in {publish_dir}")

if __name__ == "__main__":
    main()