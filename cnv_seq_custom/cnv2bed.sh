#!/bin/bash

folderpath=/data/users/asuisse/Analysis_DrosoWGS/CNV_seq_analysis

cn2bed="${folderpath}/cnv_seq_custom/CN2bed.py"
bed_sort="${folderpath}/cnv_seq_custom/bed_sort.py"
cnv2gff="${folderpath}/cnv_seq_custom/cnv2gff.pl"


for file in $@; do
  stem=$(basename "${file}" )
  id=$(echo $stem | cut -d '_' -f 1,2)

  echo "Converting CNVs to bedpe for $file"

  python $cn2bed -c $file -o ${id}.bedpe
  python $bed_sort -b ${id}.bedpe > ${id}_cnvs.bedpe

  rm ${id}.bedpe

  echo "Creating gff track"
  perl $cnv2gff $file

done
