"""
Postprocessing rules for organizing final outputs
"""

rule organize_outputs:
    """Organize final outputs with proper structure"""
    input:
        fastq_dir = f"{SAMPLE_ID}/fastq",
        qc_report = f"{SAMPLE_ID}/qc/multiqc_report.html",
        qc_dir = f"{SAMPLE_ID}/qc/combined",
        run_info = f"{SAMPLE_ID}/run_information.csv",
        logs_dir = f"{SAMPLE_ID}/demultiplexer_logs",
        detection_flag = f"{SAMPLE_ID}/detection_complete.flag"
    output:
        flag = f"{SAMPLE_ID}/outputs_organized.flag"
    run:
        # Read the demultiplexer type
        with open(input.detection_flag, 'r') as f:
            for line in f:
                if line.startswith('demultiplexer='):
                    demultiplexer = line.split('=')[1].strip()
                    break
        
        # Create flag file with output information
        with open(output.flag, 'w') as f:
            f.write(f"fastq_dir={input.fastq_dir}\n")
            f.write(f"qc_report={input.qc_report}\n")
            f.write(f"qc_dir={input.qc_dir}\n")
            f.write(f"run_info={input.run_info}\n")
            f.write(f"demultiplexer={demultiplexer}\n")
            f.write(f"logs_dir={input.logs_dir}\n")

rule publish_outputs:
    """Publish outputs to final directory structure"""
    input:
        flag = f"{SAMPLE_ID}/outputs_organized.flag"
    output:
        published_flag = Path(config['publish_dir']) / f"{SAMPLE_ID}_published.flag"
    params:
        publish_dir = config["publish_dir"],
        sample_id = SAMPLE_ID
    container:
        config["containers"]["default"]
    script:
        "../scripts/publish_outputs.py"