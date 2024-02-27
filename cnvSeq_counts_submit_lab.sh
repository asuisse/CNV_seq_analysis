#!/usr/bin/sh

#export PATH=$PATH:~/miniconda3/condabin/conda
#source activate R
#conda activate python2

folderpath=/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis/

#Tell the program what files to work from. A sample file must be created in the CNV_seq_analysis named "samples_DXXXX"
samples_file="${folderpath}/samples_D1632-D1612a"
path_pbs_scripts="${folderpath}/"
path_cnv_seq_custom="${folderpath}/cnv_seq_custom"
base_output_dir="/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis/CNV_files/"
path_bam_files="/data/users/asuisse/Analysis_DrosoWGS/nf-lohcator_nser/results/bam/"


#paths_for_nick_pipelines=/data/users/nrubanov/DrosoWGS/svn/analyse/data/scripts/#paths_for_nick_pipelines

#Declare Associative Arrays allowing to associate keys with values, in pairs.
#To set the keys and values, use code: samples_files["sample1"]="/path/to/sample1/file"
#Values can then be accessed using the keys: echo "File for sample1: ${samples_files["sample1"]}"
declare -A samples_files #DIFFERENT FROM samples_file variable made earlier
declare -A samples_outdir

# IFS="="
# while IFS="=" read -r p || [ -n "$p" ]
# do
#   read -a strarr <<< "$p"
#   paths_variables["${strarr[0]}"]=${strarr[1]}
# done < ${paths_for_nick_pipelines}

# Now, let's process the data from {samples_file} line by line

# Set the Internal Field Separator (IFS) to a tab character
IFS=$'\t'

# Start the while loop to read two lines at a time from the input file
while IFS=$'\t' read -r kdiidT nameT idT rglbT kdi_folderT sexT typeT bamfileidT rleangthT && \
      IFS=$'\t' read -r kdiidC nameC idC rglbC kdifolderC sexC typeC bamfileidC rleangthC
do
    # Skip the loop iteration if kdiidT or kdiidC are empty or equal to "kdi_id"
    if [[ -z "$kdiidT"  ||  "$kdiidT" == "kdi_id" || -z "$kdiidC"  ||  "$kdiidC" == "kdi_id" ]]; then
      continue
    fi

    # Construct the path to the output directory and the output file
    path_output_dir="${base_output_dir}${rglbT}/CNV-Seq"
    samples_cf="${path_output_dir}/samples.cnvSeq.counts.${rglbT}"

    # Remove the output file if it already exists
    if [[ -f "${samples_cf}" ]]; then
      rm -f "${samples_cf}"
    fi

    # Check the exit status of the rm command
    if [[ $? -ne 0 ]]; then
        echo "New file ${samples_file}, nothing to remove"
        exit 1
    else
      echo "Deleted existing output files from previous setup"
    fi

done < "${samples_file}"

# Check if the input file could be read successfully
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to read file ${samples_file}"
    exit 1
else
    echo "File ${samples_file} read successfully"
fi


# Set the field delimiter to a tab
IFS=$'\t'

# Loop through the lines in the input data
while IFS=$'\t' read -r kdiid name id rglb kdifolder sex type bamfileid rleangth; #Reads file line by line instead of by pair.
do

# Skip lines with empty or "kid_id" values in kdiid
    if [[ -z "$kdiid"  ||  $kdiid == "kdi_id" ]]; then
      continue 
    fi

# Construct the base output directory
    path_output_dir="${base_output_dir}${rglb}/CNV-Seq"

    mkdir -p ${path_output_dir}
    log=$path_output_dir

# Create subdirectories if they don't exist
    if [[ ! -d $path_output_dir/hits ]]; then
        mkdir -p $path_output_dir/hits;
    fi

    if [[ ! -d $path_output_dir/results/w_500 ]]; then
        mkdir -p $path_output_dir/results/w_500;
    fi

    if [[ ! -d $path_output_dir/results/w_10000 ]]; then
        mkdir -p $path_output_dir/results/w_10000;
    fi

    if [[ ! -d $path_output_dir/results/w_50000 ]]; then
        mkdir -p $path_output_dir/results/w_50000;
    fi

    if [[ ! -d $path_output_dir/log ]]; then
        mkdir -p $path_output_dir/log;
    fi

# Construct bam files directory
    bamfile="${path_bam_files}${bamfileid}.RG.bam"
    echo "bamfile = " + ${bamfile}

# Add bam file information to samples.cnvSeq.counts. file
# ?? is it even the right file format?
    echo -e ${bamfileid}'\t'${bamfile}'\t'${path_output_dir} >> ${path_output_dir}/"samples.cnvSeq.counts."$rglb

    samples_files[$rglb]=${path_output_dir}/"samples.cnvSeq.counts."$rglb
    samples_outdir[$rglb]=${path_output_dir}

done < ${samples_file}

echo "samples_files array and samples_outdir array"
echo "${samples_files[@]}"
echo "${samples_outdir[@]}"

for i in "${!samples_files[@]}"
do
  echo "i = ${i}"
  rglb="${i}"

  sample_file="${samples_files[$i]}"
  echo "sample file = ${sample_file}"
  output_dir="${samples_outdir[$i]}"
  echo "sample output dir = ${output_dir}"

  submit_log="${output_dir}/${rglb}.cnvSeq_counts.submit.log"

  if [[ -f $sample_file ]]; then
    nlines=$(wc -l < $sample_file)
  else
    echo "File not found: ${sample_file}"
    continue
  fi

  lines=$nlines

  if [[ $lines == 1 ]]; then
    echo "entering lines = 1"
    qsub_command="qsub -V -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o ${output_dir}/${rglb}.runlog -j oe -N ${rglb}.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs"
  else
    echo "entering else"
    qsub_command="qsub -V -t 1-$lines -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o ${output_dir}/${rglb}.runlog -j oe -N ${rglb}.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs"
  fi

  echo $qsub_command >> $submit_log
  CNVSEQ=$($qsub_command)
  echo "CNVSEQ = ${CNVSEQ}"
  echo "runlog = ${output_dir}/${rglb}.runlog"

done