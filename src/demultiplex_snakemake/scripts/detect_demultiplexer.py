#!/usr/bin/env python3
"""
Detect demultiplexer type and run information file

This script is a Python translation of the detect_demultiplexer Nextflow workflow.
"""

import os
import sys
from pathlib import Path

def main():
    # Get parameters from snakemake
    input_dir_param = getattr(snakemake.input, 'input_dir', None)
    if input_dir_param:
        input_dir = Path(input_dir_param)
    else:
        input_dir = Path(snakemake.params.input_path)
    
    user_demultiplexer = snakemake.params.user_demultiplexer
    user_run_information = snakemake.params.user_run_information
    skip_copycomplete_check = snakemake.params.skip_copycomplete_check
    
    demultiplexer_output_file = snakemake.output.demultiplexer_output
    run_information_output_file = snakemake.output.run_information_output
    
    # Check if input directory exists (skip check in dry run mode)
    if not input_dir.exists():
        import sys
        if "--dryrun" in sys.argv or "-n" in sys.argv:
            # In dry run mode, create dummy outputs
            print("Dry run mode: creating dummy outputs")
            demultiplexer = user_demultiplexer or "bclconvert"
            run_information = input_dir / "SampleSheet.csv"
            
            # Write outputs
            with open(demultiplexer_output_file, 'w') as f:
                f.write(demultiplexer)
            
            # Create dummy run information
            with open(run_information_output_file, 'w') as f:
                f.write("# Dummy sample sheet for dry run\n")
            
            print(f"Dry run detection complete. Demultiplexer: {demultiplexer}")
            return
        else:
            raise FileNotFoundError(f"Input directory {input_dir} does not exist")
    
    print(f"Provided run information: {user_run_information} and demultiplexer: {user_demultiplexer}")
    
    # Validation: if run_information is provided, demultiplexer must also be specified
    if user_run_information and not user_demultiplexer:
        raise ValueError("When setting run_information, you must also provide a demultiplexer")
    
    demultiplexer = None
    run_information = None
    
    if user_run_information:
        # User provided run information, use it
        run_information = Path(user_run_information)
        demultiplexer = user_demultiplexer
        print(f"Using user-provided run information: {run_information}")
        print(f"Using user-provided demultiplexer: {demultiplexer}")
    else:
        print("Run information was not specified, auto-detecting...")
        
        # Supported platforms mapping
        supported_platforms = {
            "bclconvert": "SampleSheet.csv",  # Illumina
            "bases2fastq": "RunManifest.csv"  # Element Biosciences
        }
        
        found_sample_information = {}
        for demultiplexer_candidate, filename in supported_platforms.items():
            print(f"Checking if {filename} can be found in input folder {input_dir}")
            resolved_filename = input_dir / filename
            if resolved_filename.is_file():
                found_sample_information[demultiplexer_candidate] = resolved_filename
                print(f"Result after looking for run information for {demultiplexer_candidate}: {resolved_filename}")
            else:
                found_sample_information[demultiplexer_candidate] = None
                print(f"Result after looking for run information for {demultiplexer_candidate}: None")
        
        # Find the demultiplexer and run information
        found_files = [(k, v) for k, v in found_sample_information.items() if v is not None]
        
        if len(found_files) == 0:
            raise FileNotFoundError(
                "Autodetection of run information (SampleSheet, RunManifest) failed: "
                "no candidate files found in input folder. "
                f"Please specify a run information file manually with --run_information."
            )
        elif len(found_files) > 1:
            found_file_names = [str(v) for k, v in found_files]
            raise FileNotFoundError(
                "Autodetection of run information (SampleSheet, RunManifest) failed: "
                f"multiple candidate files found in input folder: {', '.join(found_file_names)}. "
                "Please specify a run information file manually with --run_information."
            )
        else:
            demultiplexer, run_information = found_files[0]
            print(f"Auto-detected demultiplexer: {demultiplexer}")
            print(f"Auto-detected run information: {run_information}")
    
    # For Illumina data, check for CopyComplete.txt
    if demultiplexer == "bclconvert" and not skip_copycomplete_check:
        copycomplete_file = input_dir / "CopyComplete.txt"
        if not copycomplete_file.is_file():
            raise FileNotFoundError("'CopyComplete.txt' file was not found!")
        print("Found CopyComplete.txt file")
    
    # Ensure run_information exists
    if not run_information.is_file():
        raise FileNotFoundError(f"Run information file {run_information} does not exist")
    
    # Write outputs
    with open(demultiplexer_output_file, 'w') as f:
        f.write(demultiplexer)
    
    # Copy run information to output location
    import shutil
    shutil.copy2(run_information, run_information_output_file)
    
    print(f"Detection complete. Demultiplexer: {demultiplexer}, Run information: {run_information_output_file}")

if __name__ == "__main__":
    main()