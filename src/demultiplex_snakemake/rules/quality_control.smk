"""
Quality control rules for FastQC and MultiQC
"""

rule fastqc:
    """Run FastQC on individual FASTQ files"""
    input:
        fastq = "{sample}/fastq/{fastq_file}.fastq.gz"
    output:
        html = "{sample}/qc/fastqc/{fastq_file}_fastqc.html",
        zip = "{sample}/qc/fastqc/{fastq_file}_fastqc.zip",
        summary = "{sample}/qc/fastqc/{fastq_file}_fastqc/summary.txt",
        data = "{sample}/qc/fastqc/{fastq_file}_fastqc/fastqc_data.txt"
    container:
        config["containers"]["fastqc"]
    resources:
        cpus = config["resources"]["verylowcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["lowmem"].rstrip("GB")) * 1024 * attempt
    shell:
        """
        mkdir -p $(dirname {output.html})
        
        # Run FastQC
        fastqc {input.fastq} --outdir $(dirname {output.html}) --threads {resources.cpus}
        
        # Extract zip file to get individual files
        cd $(dirname {output.html})
        unzip -o $(basename {output.zip})
        """

def get_all_fastqc_outputs(wildcards):
    """Get all FastQC outputs for the sample"""
    import glob
    
    # Read the FASTQ file lists
    fastq_forward_file = f"{wildcards.sample}/fastqs_forward.txt"
    fastq_reverse_file = f"{wildcards.sample}/fastqs_reverse.txt"
    
    outputs = []
    
    # Check if files exist (they may not exist yet during dry run)
    try:
        if os.path.exists(fastq_forward_file):
            with open(fastq_forward_file, 'r') as f:
                for line in f:
                    fastq_path = line.strip()
                    if fastq_path:
                        fastq_name = os.path.basename(fastq_path).replace('.fastq.gz', '').replace('.fq.gz', '')
                        outputs.extend([
                            f"{wildcards.sample}/qc/fastqc/{fastq_name}_fastqc.html",
                            f"{wildcards.sample}/qc/fastqc/{fastq_name}_fastqc.zip"
                        ])
        
        if os.path.exists(fastq_reverse_file):
            with open(fastq_reverse_file, 'r') as f:
                for line in f:
                    fastq_path = line.strip()
                    if fastq_path:
                        fastq_name = os.path.basename(fastq_path).replace('.fastq.gz', '').replace('.fq.gz', '')
                        outputs.extend([
                            f"{wildcards.sample}/qc/fastqc/{fastq_name}_fastqc.html",
                            f"{wildcards.sample}/qc/fastqc/{fastq_name}_fastqc.zip"
                        ])
    except:
        # During dry run, these files may not exist yet
        pass
    
    return outputs

rule run_fastqc_all:
    """Run FastQC on all FASTQ files"""
    input:
        fastq_forward = f"{SAMPLE_ID}/fastqs_forward.txt",
        fastq_reverse = f"{SAMPLE_ID}/fastqs_reverse.txt"
    output:
        qc_dir = directory(f"{SAMPLE_ID}/qc/fastqc")
    container:
        config["containers"]["fastqc"]
    resources:
        cpus = config["resources"]["verylowcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["lowmem"].rstrip("GB")) * 1024 * attempt
    script:
        "../scripts/run_fastqc.py"

rule combine_samples:
    """Combine sample information for MultiQC"""
    input:
        fastq_forward = f"{SAMPLE_ID}/fastqs_forward.txt",
        fastq_reverse = f"{SAMPLE_ID}/fastqs_reverse.txt",
        qc_dir = f"{SAMPLE_ID}/qc/fastqc"
    output:
        combined_qc = directory(f"{SAMPLE_ID}/qc/combined"),
        forward_fastqs = f"{SAMPLE_ID}/combined_forward_fastqs.txt",
        reverse_fastqs = f"{SAMPLE_ID}/combined_reverse_fastqs.txt"
    container:
        config["containers"]["default"]
    script:
        "../scripts/combine_samples.py"

rule multiqc:
    """Generate MultiQC report"""
    input:
        qc_dir = f"{SAMPLE_ID}/qc/combined",
        interop_run_summary = f"{SAMPLE_ID}/interop/run_summary.csv",
        interop_index_summary = f"{SAMPLE_ID}/interop/index_summary.csv",
        detection_flag = f"{SAMPLE_ID}/detection_complete.flag"
    output:
        report = f"{SAMPLE_ID}/qc/multiqc_report.html"
    container:
        config["containers"]["multiqc"]
    resources:
        cpus = config["resources"]["midcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["midmem"].rstrip("GB")) * 1024 * attempt
    params:
        cl_config = config["multiqc"]["cl_config"]
    shell:
        """
        mkdir -p $(dirname {output.report})
        
        # Check demultiplexer type to determine input sources
        DEMULTIPLEXER=$(grep "demultiplexer=" {input.detection_flag} | cut -d= -f2)
        
        INPUT_DIRS="{input.qc_dir}"
        
        # Add InterOp directories for bclconvert
        if [[ "$DEMULTIPLEXER" == "bclconvert" ]]; then
            INPUT_DIRS="$INPUT_DIRS $(dirname {input.interop_run_summary}) $(dirname {input.interop_index_summary})"
        fi
        
        # Run MultiQC
        multiqc $INPUT_DIRS \\
            --filename $(basename {output.report}) \\
            --outdir $(dirname {output.report}) \\
            --cl-config '{params.cl_config}' \\
            --force
        """