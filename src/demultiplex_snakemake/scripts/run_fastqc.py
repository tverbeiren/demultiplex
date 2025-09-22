#!/usr/bin/env python3
"""
Run FastQC on all FASTQ files
"""

import os
import subprocess
from pathlib import Path

def main():
    # Get parameters from snakemake
    fastq_forward_file = snakemake.input.fastq_forward
    fastq_reverse_file = snakemake.input.fastq_reverse
    qc_dir = Path(snakemake.output.qc_dir)
    
    # Create output directory
    qc_dir.mkdir(parents=True, exist_ok=True)
    
    # Collect all FASTQ files
    all_fastqs = []
    
    # Read forward reads
    if os.path.exists(fastq_forward_file):
        with open(fastq_forward_file, 'r') as f:
            for line in f:
                fastq_path = line.strip()
                if fastq_path and os.path.exists(fastq_path):
                    all_fastqs.append(fastq_path)
    
    # Read reverse reads
    if os.path.exists(fastq_reverse_file):
        with open(fastq_reverse_file, 'r') as f:
            for line in f:
                fastq_path = line.strip()
                if fastq_path and os.path.exists(fastq_path):
                    all_fastqs.append(fastq_path)
    
    if not all_fastqs:
        raise FileNotFoundError("No FASTQ files found to process")
    
    print(f"Running FastQC on {len(all_fastqs)} FASTQ files")
    
    # Run FastQC on all files
    for fastq in all_fastqs:
        print(f"Processing {fastq}")
        
        cmd = [
            "fastqc",
            fastq,
            "--outdir", str(qc_dir),
            "--threads", str(snakemake.resources.cpus)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"FastQC failed for {fastq}")
            print(f"STDOUT: {result.stdout}")
            print(f"STDERR: {result.stderr}")
            raise subprocess.CalledProcessError(result.returncode, cmd)
    
    # Extract zip files to get individual report components
    for fastq in all_fastqs:
        fastq_base = os.path.basename(fastq)
        # Remove extensions
        for ext in ['.fastq.gz', '.fq.gz', '.fastq', '.fq']:
            if fastq_base.endswith(ext):
                fastq_base = fastq_base[:-len(ext)]
                break
        
        zip_file = qc_dir / f"{fastq_base}_fastqc.zip"
        if zip_file.exists():
            subprocess.run(["unzip", "-o", str(zip_file)], cwd=qc_dir)
    
    print("FastQC completed successfully")

if __name__ == "__main__":
    main()