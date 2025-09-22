#!/usr/bin/env python3
"""
Gather FASTQ files and validate them

This script finds all FASTQ files in the output directory and organizes them
into forward and reverse reads.
"""

import os
import glob
from pathlib import Path

def main():
    # Get parameters from snakemake
    output_dir = Path(snakemake.input.output_dir)
    run_information = Path(snakemake.input.run_information)
    
    fastq_forward_file = snakemake.output.fastq_forward
    fastq_reverse_file = snakemake.output.fastq_reverse
    
    print(f"Gathering FASTQ files from {output_dir}")
    
    # Find all FASTQ files
    fastq_patterns = ["*.fastq.gz", "*.fq.gz", "*.fastq", "*.fq"]
    all_fastqs = []
    
    for pattern in fastq_patterns:
        all_fastqs.extend(glob.glob(str(output_dir / pattern)))
    
    if not all_fastqs:
        raise FileNotFoundError(f"No FASTQ files found in {output_dir}")
    
    print(f"Found {len(all_fastqs)} FASTQ files")
    
    # Separate forward and reverse reads
    forward_reads = []
    reverse_reads = []
    
    for fastq in sorted(all_fastqs):
        fastq_name = os.path.basename(fastq)
        
        # Determine if this is forward or reverse read
        # Common patterns: R1/R2, _1/_2, .1/.2
        if any(pattern in fastq_name for pattern in ['_R1_', '_R1.', '_1.', '_1_']):
            forward_reads.append(fastq)
        elif any(pattern in fastq_name for pattern in ['_R2_', '_R2.', '_2.', '_2_']):
            reverse_reads.append(fastq)
        else:
            # If we can't determine, assume it's forward read
            print(f"Warning: Could not determine read direction for {fastq_name}, assuming forward read")
            forward_reads.append(fastq)
    
    print(f"Forward reads: {len(forward_reads)}")
    print(f"Reverse reads: {len(reverse_reads)}")
    
    # Write lists to output files
    with open(fastq_forward_file, 'w') as f:
        for fastq in forward_reads:
            f.write(f"{fastq}\n")
    
    with open(fastq_reverse_file, 'w') as f:
        for fastq in reverse_reads:
            f.write(f"{fastq}\n")
    
    # Validation
    if not forward_reads:
        raise ValueError("No forward reads found")
    
    print("FASTQ gathering completed successfully")

if __name__ == "__main__":
    main()