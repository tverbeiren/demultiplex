#!/usr/bin/env python3
"""
Combine samples for MultiQC processing

This script organizes QC outputs for MultiQC processing.
"""

import os
import shutil
from pathlib import Path

def main():
    # Get parameters from snakemake
    fastq_forward_file = snakemake.input.fastq_forward
    fastq_reverse_file = snakemake.input.fastq_reverse
    qc_dir = Path(snakemake.input.qc_dir)
    
    combined_qc_dir = Path(snakemake.output.combined_qc)
    forward_fastqs_file = snakemake.output.forward_fastqs
    reverse_fastqs_file = snakemake.output.reverse_fastqs
    
    # Create output directory
    combined_qc_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy all FastQC outputs to combined directory
    if qc_dir.exists():
        for item in qc_dir.iterdir():
            if item.is_file():
                shutil.copy2(item, combined_qc_dir / item.name)
            elif item.is_dir():
                shutil.copytree(item, combined_qc_dir / item.name, dirs_exist_ok=True)
    
    # Copy the FASTQ lists to output
    if os.path.exists(fastq_forward_file):
        shutil.copy2(fastq_forward_file, forward_fastqs_file)
    else:
        with open(forward_fastqs_file, 'w') as f:
            pass  # Create empty file
    
    if os.path.exists(fastq_reverse_file):
        shutil.copy2(fastq_reverse_file, reverse_fastqs_file)
    else:
        with open(reverse_fastqs_file, 'w') as f:
            pass  # Create empty file
    
    print("Sample combination completed successfully")

if __name__ == "__main__":
    main()