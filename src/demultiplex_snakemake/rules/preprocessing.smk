"""
Preprocessing rules for demultiplex workflow
Handles untar and demultiplexer detection
"""

rule untar_input:
    """Unpack a .tar file if input is compressed"""
    input:
        tarball = lambda wc: config["input"] if is_tarball(config["input"]) else []
    output:
        directory = directory(f"{SAMPLE_ID}/unpacked_input")
    container:
        config["containers"]["untar"]
    resources:
        cpus = config["resources"]["lowcpu"],
        mem_mb = lambda wc, attempt: int(config["resources"]["lowmem"].rstrip("GB")) * 1024 * attempt
    shell:
        """
        mkdir -p {output.directory}
        
        # Extract tarball
        if [[ "{input.tarball}" == *.tar.gz ]] || [[ "{input.tarball}" == *.tgz ]]; then
            tar -xzf {input.tarball} -C {output.directory}
        elif [[ "{input.tarball}" == *.tar ]]; then
            tar -xf {input.tarball} -C {output.directory}
        fi
        
        # If there's only one directory in the output, move its contents up
        cd {output.directory}
        items=(*)
        if [[ ${{#items[@]}} -eq 1 ]] && [[ -d "${{items[0]}}" ]]; then
            mv "${{items[0]}}"/* .
            rmdir "${{items[0]}}"
        fi
        """

rule detect_demultiplexer:
    """Detect the demultiplexer type and run information file"""
    input:
        input_dir = lambda wc: f"{SAMPLE_ID}/unpacked_input" if needs_untar else (config["input"] if Path(config["input"]).exists() else [])
    output:
        demultiplexer_output = f"{SAMPLE_ID}/detected_demultiplexer.txt",
        run_information_output = f"{SAMPLE_ID}/run_information.csv"
    container:
        config["containers"]["default"]
    params:
        user_demultiplexer = config.get("demultiplexer", ""),
        user_run_information = config.get("run_information", ""),
        skip_copycomplete_check = config.get("skip_copycomplete_check", False),
        input_path = config["input"]
    script:
        "../scripts/detect_demultiplexer.py"

checkpoint get_detected_values:
    """Checkpoint to read detected demultiplexer and run information"""
    input:
        demultiplexer_file = f"{SAMPLE_ID}/detected_demultiplexer.txt",
        run_info_file = f"{SAMPLE_ID}/run_information.csv"
    output:
        flag = f"{SAMPLE_ID}/detection_complete.flag"
    run:
        # Read detected values
        with open(input.demultiplexer_file, 'r') as f:
            detected_demultiplexer = f.read().strip()
        
        # Store in workflow global variables for use by other rules
        workflow.globals["DETECTED_DEMULTIPLEXER"] = detected_demultiplexer
        workflow.globals["RUN_INFORMATION"] = input.run_info_file
        
        # Create flag file
        with open(output.flag, 'w') as f:
            f.write(f"demultiplexer={detected_demultiplexer}\n")
            f.write(f"run_information={input.run_info_file}\n")