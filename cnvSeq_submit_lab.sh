#!/usr/bin/sh

#export PATH=$PATH:/data/users/nrubanov/tools/anaconda2/bin

#Launch environment "main", with packages python 2.7, R, perl

folderpath=/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis

samples_file="${folderpath}/samples_D1632-D1612a"
path_pbs_scripts="${folderpath}/"
path_cnv_seq_custom="${folderpath}/cnv_seq_custom"
base_output_dir="/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis/CNV_files"
path_bam_files="/data/users/asuisse/Analysis_DrosoWGS/nf-lohcator_nser/results/bam"
path_cnv_seq="${folderpath}/cnv-seq"

#declare -A paths_variables
declare -A samples_files
declare -A samples_outdir
# IFS="="
# while IFS="=" read -r p || [ -n "$p" ]
# do
#   read -a strarr <<< "$p"
#   paths_variables["${strarr[0]}"]=${strarr[1]}
# done < ${paths_for_nick_pipelines}

#group=${paths_variables["group"]}
#path_output_dir=${paths_variables["path_output_dir"]}/${group}/CNV-Seq
#path_pbs_scripts=${paths_variables["path_pbs_scripts"]}
#path_bam_files=${paths_variables["path_bam_files"]}/${group}
#path_cnv_seq_custom=${paths_variables["path_cnv_seq_custom"]}
#path_cnv_seq=${paths_variables["path_cnv_seq"]}
#file_name_conversion=${paths_variables["file_name_conversion"]}
#log=$path_output_dir

echo "Entering IFS"
while IFS=$'\t' read -r kdiidT nameT idT rglbT kdi_folderT sexT typeT bamfileidT rleangthT && \
      IFS=$'\t' read -r kdiidC nameC idC rglbC kdifolderC sexC typeC bamfileidC rleangthC
do    
    # Skip the loop iteration if kdiidT or kdiidC are empty or equal to "kdi_id"
    if [[ -z "$kdiidT"  ||  $kdiidT == "kdi_id" || -z "$kdiidC"  ||  $kdiidC == "kdi_id" ]]; then
      continue
    fi

    path_output_dir=${base_output_dir}/${rglbT}/CNV-Seq
    samples_cf=${path_output_dir}/"samples.cnvSeq."$rglbT

    # if file exists, remove it
    if [ -f ${samples_cf} ]; then
      rm -f ${samples_cf}
      if [ $? -ne 0 ]; then
        echo "${samples_cf} non-existant"
        exit 1
      fi
    fi

    tumour_id=$bamfileidT
    normal_id=$bamfileidC
    tumour_hitfile=$path_output_dir/hits/${tumour_id}.hits.filt
    normal_hitfile=$path_output_dir/hits/${normal_id}.hits.filt

    # Check if hitfiles exist
    if [ ! -f ${tumour_hitfile} ]; then
      echo "Tumour hitfile ${tumour_hitfile} does not exist"
      exit 1
    fi
    if [ ! -f ${normal_hitfile} ]; then
      echo "Normal hitfile ${normal_hitfile} does not exist"
      exit 1
    fi

    echo -e ${tumour_hitfile}'\t'${normal_hitfile}'\t'"${tumour_id}"'\t'"${path_output_dir}" >> ${samples_cf}
    if [ $? -ne 0 ]; then
      echo "Failed to write to file ${samples_cf}"
      exit 1
    fi

    samples_files[$rglbT]=${samples_cf}
    samples_outdir[$rglbT]=$path_output_dir

done < ${samples_file}

# Check if the input file could be read successfully
if [ $? -ne 0 ]; then
  echo "Failed to read from file ${samples_file}"
  exit 1
fi
echo "Set up fits files OK"


echo "Entering processing"

# Loop through all sample files
for i in "${!samples_files[@]}"
do
  rglb="$i"
  sample_file="${samples_files[$i]}"
  path_output_dir="${samples_outdir[$i]}"

  # Count number of lines in sample file
  nlines=$(wc -l < "$sample_file")
  lines=$((nlines + 0))

  submit_log="${path_output_dir}/log/${rglb}_cnvSeq_submit.log"
  
  # Clear the log file
  > "$submit_log"

  echo "Processing log : $submit_log"
  echo "Processing :" >> "$submit_log"
  echo "${rglb}" >> "$submit_log"

  # Check if lines is 1, if not run the command for each line in the sample file
  echo $lines
  if [[ $lines == 1 ]]; then
    CNVSEQ_big=$( qsub -V -v SAMPLES_FILE="${sample_file}",WINDOW=50000,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_big.runlog" -j oe -N "${rglb}.cnvSeq_big" "$path_pbs_scripts/run_cnvSeq_big.pbs" ) || { echo "qsub command run_cnvSeq_big.pbs failed"; exit 1; }
    echo "$CNVSEQ_big"
    CNVSEQ_med=$( qsub -V -v SAMPLES_FILE="${sample_file}",WINDOW=10000,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_med.runlog" -j oe -N "${rglb}.cnvSeq_med" "$path_pbs_scripts/run_cnvSeq_med.pbs" ) || { echo "qsub command run_cnvSeq_med.pbs failed"; exit 1; }
    echo "$CNVSEQ_med"
    CNVSEQ_small=$( qsub -V -v SAMPLES_FILE="${sample_file}",WINDOW=500,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_small.runlog" -j oe -N "${rglb}.cnvSeq_small" "$path_pbs_scripts/run_cnvSeq_small.pbs" ) || { echo "qsub command run_cnvSeq_small.pbs failed"; exit 1; }
    echo "$CNVSEQ_small"
  else
    CNVSEQ_big=$( qsub -t 1-"$lines" -V -v SAMPLES_FILE="${sample_file}",WINDOW=50000,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_big.runlog" -j oe -N "${rglb}.cnvSeq_big" "$path_pbs_scripts/run_cnvSeq_big.pbs" ) || { echo "qsub command run_cnvSeq_big.pbs failed"; exit 1; }
    echo "$CNVSEQ_big"
    CNVSEQ_med=$( qsub -t 1-"$lines" -V -v SAMPLES_FILE="${sample_file}",WINDOW=10000,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_med.runlog" -j oe -N "${rglb}.cnvSeq_med" "$path_pbs_scripts/run_cnvSeq_med.pbs" ) || { echo "qsub command run_cnvSeq_med.pbs failed"; exit 1; }
    echo "$CNVSEQ_med"
    CNVSEQ_small=$( qsub -t 1-"$lines" -V -v SAMPLES_FILE="${sample_file}",WINDOW=500,PATH_CNV_SEQ="${path_cnv_seq}",PATH_CNV_SEQ_CUSTOM="${path_cnv_seq_custom}",PATH_OUTPUT_DIR="${path_output_dir}" -o "${path_output_dir}/log/${rglb}_cnvSeq_small.runlog" -j oe -N "${rglb}.cnvSeq_small" "$path_pbs_scripts/run_cnvSeq_small.pbs" ) || { echo "qsub command run_cnvSeq_small.pbs failed"; exit 1; }
    echo "$CNVSEQ_small"
  fi

done
