"""
Demultiplexing rules for bcl_convert and bases2fastq
Uses ruleorder and conditional outputs to handle ambiguous rules
"""

def get_demultiplexer_input_dir():
    """Get the input directory for demultiplexing"""
    if needs_untar:
        return f"{SAMPLE_ID}/unpacked_input"
    else:
        return config["input"]

# Use ruleorder to resolve ambiguity - bcl_convert takes priority
ruleorder: bcl_convert > bases2fastq

rule interop_summary_to_csv:
    """Generate InterOp summaries for Illumina data"""
    input:
        input_dir = get_demultiplexer_input_dir(),
        detection_flag = f"{SAMPLE_ID}/detection_complete.flag"
    output:
        run_summary = f"{SAMPLE_ID}/interop/run_summary.csv",
        index_summary = f"{SAMPLE_ID}/interop/index_summary.csv"
    container:
        config["containers"]["interop_summary"]
    resources:
        cpus = config["resources"]["verylowcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["lowmem"].rstrip("GB")) * 1024 * attempt
    shell:
        """
        # Check if this should run (only for bclconvert)
        DEMULTIPLEXER=$(grep "demultiplexer=" {input.detection_flag} | cut -d= -f2)
        if [[ "$DEMULTIPLEXER" != "bclconvert" ]]; then
            echo "Skipping InterOp summary - not using bclconvert"
            mkdir -p $(dirname {output.run_summary})
            touch {output.run_summary}
            touch {output.index_summary}
            exit 0
        fi
        
        mkdir -p $(dirname {output.run_summary})
        
        # Generate InterOp summaries
        interop_summary {input.input_dir} > {output.run_summary}
        interop_index-summary {input.input_dir} > {output.index_summary}
        """

rule bcl_convert:
    """Run bcl_convert for Illumina demultiplexing"""
    input:
        input_dir = get_demultiplexer_input_dir(),
        run_information = f"{SAMPLE_ID}/run_information.csv",
        detection_flag = f"{SAMPLE_ID}/detection_complete.flag"
    output:
        output_dir = directory(f"{SAMPLE_ID}/fastq"),
        reports_dir = directory(f"{SAMPLE_ID}/demultiplexer_logs")
    container:
        config["containers"]["bcl_convert"]
    resources:
        cpus = config["resources"]["midcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["highmem"].rstrip("GB")) * 1024 * attempt
    shell:
        """
        # Check if this should run (only for bclconvert)
        DEMULTIPLEXER=$(grep "demultiplexer=" {input.detection_flag} | cut -d= -f2)
        if [[ "$DEMULTIPLEXER" != "bclconvert" ]]; then
            echo "Skipping bcl_convert - using different demultiplexer: $DEMULTIPLEXER"
            mkdir -p {output.output_dir}
            mkdir -p {output.reports_dir}
            # Create a marker file to indicate this was skipped
            touch {output.reports_dir}/SKIPPED_BCL_CONVERT
            exit 0
        fi
        
        mkdir -p {output.output_dir}
        mkdir -p {output.reports_dir}
        
        # Run bcl_convert
        bcl-convert \\
            --bcl-input-directory {input.input_dir} \\
            --sample-sheet {input.run_information} \\
            --output-directory {output.output_dir} \\
            --reports-directory {output.reports_dir} \\
            --no-lane-splitting \\
            --force
        """

rule bases2fastq:
    """Run bases2fastq for Element Biosciences demultiplexing"""
    input:
        input_dir = get_demultiplexer_input_dir(),
        run_information = f"{SAMPLE_ID}/run_information.csv", 
        detection_flag = f"{SAMPLE_ID}/detection_complete.flag"
    output:
        output_dir = directory(f"{SAMPLE_ID}/fastq"),
        logs_dir = directory(f"{SAMPLE_ID}/demultiplexer_logs"),
        report = f"{SAMPLE_ID}/demultiplexer_logs/report.html"
    container:
        config["containers"]["bases2fastq"]
    resources:
        cpus = config["resources"]["midcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["highmem"].rstrip("GB")) * 1024 * attempt
    shell:
        """
        # Check if this should run (only for bases2fastq)
        DEMULTIPLEXER=$(grep "demultiplexer=" {input.detection_flag} | cut -d= -f2)
        if [[ "$DEMULTIPLEXER" != "bases2fastq" ]]; then
            echo "Skipping bases2fastq - using different demultiplexer: $DEMULTIPLEXER"
            mkdir -p {output.output_dir}
            mkdir -p {output.logs_dir}
            # Create marker files to indicate this was skipped
            touch {output.report}
            touch {output.logs_dir}/SKIPPED_BASES2FASTQ
            exit 0
        fi
        
        mkdir -p {output.output_dir}
        mkdir -p {output.logs_dir}
        
        # Run bases2fastq
        bases2fastq \\
            --analysis-directory {input.input_dir} \\
            --run-manifest {input.run_information} \\
            --output-directory {output.output_dir} \\
            --report {output.report} \\
            --logs {output.logs_dir} \\
            --no-projects \\
            --legacy-fastq \\
            --group-fastq \\
            --skip-multi-qc
        """

rule gather_fastqs_and_validate:
    """Gather FASTQ files and validate them"""
    input:
        output_dir = f"{SAMPLE_ID}/fastq",
        run_information = f"{SAMPLE_ID}/run_information.csv"
    output:
        fastq_forward = f"{SAMPLE_ID}/fastqs_forward.txt",
        fastq_reverse = f"{SAMPLE_ID}/fastqs_reverse.txt"
    container:
        config["containers"]["default"]
    script:
        "../scripts/gather_fastqs_and_validate.py"