#!/usr/bin/sh
# HUM
# A512
# A558
# A572
# A370
# B241
# A785
# D050

#export PATH=$PATH:~/miniconda3/condabin/conda

#source activate R
#conda activate python2

folderpath=/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis/

#Tell the program what files to work from. A sample file must be created in the CNV_seq_analysis named "samples_DXXXX"
samples_file="${folderpath}/samples_D1389a"
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

echo "entering IFS" #Makes sure the program makes it to this step
IFS=$'\t' #IFS = Internal Fields Separator. Uses tab as a separator.
while IFS=$'\t' read -r kdiidT nameT idT rglbT kdi_folderT sexT typeT bamfileidT rleangthT; IFS=$'\t' read -r kdiidC nameC idC rglbC kdifolderC sexC typeC bamfileidC rleangthC;
#This line sets up a while loop that reads lines from the ${samples_file} file and splits each line into fields using the tab character as a delimiter. 
#It assigns the values in each field to variables like kdiidT, nameT, idT, and so on for both kdiidT and kdiidC. 
#This line essentially reads two lines at a time, assuming that ${samples_file} contains pairs of tab-delimited lines.
do
    echo "IFS parameters = " + ${kdiidT} + " #### " + ${kdiidC} #debugging line
    if [[ -z "$kdiidT"  ||  $kdiidT == "kdi_id" || -z "$kdiidC"  ||  $kdiidC == "kdi_id" ]]; then
      continue #checks kidiid for each line
    fi

    path_output_dir="${base_output_dir}${rglbT}/CNV-Seq"
    samples_cf="${path_output_dir}/samples.cnvSeq.counts.${rglbT}"

    if [[ -f ${samples_cf} ]]; then
      rm -f ${samples_cf}
    fi

done < ${samples_file}

echo "Deleted existing output files from previous setup"

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

# Add bam file information to samples.cnvSeq.counts.D1389 file
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
  echo "i = " + ${i}
  rglb="${i}"

  sample_file="${samples_files[$i]}"
  echo "sample file = . ${samples_file[$i]}"
  #echo ${rglb} ${sample_file}
  output_dir="${samples_outdir[$i]}"
  echo "sample output dir =  ${output_dir}"

  submit_log="${output_dir}"/${rglb}.cnvSeq_counts.submit.log

# Count lines in sample_file and store in nlines
  nlines=`wc -l < $sample_file`

# Convert the value of nlines to an integer and store it in the lines variable
  lines=`expr $nlines + 0`


  if [[ $lines == 1 ]]; then
    echo "entering lines = 1"
    echo " qsub -V -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o $path_output_dir/${rglb}.runlog -j oe -N ${rglb}.cnvSeq.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs " >> $submit_log
    CNVSEQ=$( qsub -V -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o $path_output_dir/${rglb}.runlog -j oe -N ${rglb}.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs )
    echo $CNVSEQ
  else
    echo "entering else"
    echo " qsub -V -t 1-$lines -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o $path_output_dir/${rglb}.runlog -j oe -N ${rglb}.cnvSeq.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs " >> $submit_log
    echo ${submit_log}
    CNVSEQ=$( qsub -V -t 1-$lines -v SAMPLES_FILE=${sample_file},PATH_CNV_SEQ_CUSTOM=${path_cnv_seq_custom} -o $path_output_dir/${rglb}.runlog -j oe -N ${rglb}.getCounts $path_pbs_scripts/run_cnvSeq_counts.pbs )
    echo "CVNSEQ = " + $CNVSEQ
    echo "runlog = " + $path_output_dir/${rglb}.runlog
  fi

done
