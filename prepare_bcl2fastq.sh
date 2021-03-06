#!/bin/bash


#==================================================================================================
# Created on: 2017-11-16
# Usage: ./prepare_bcl2fastq.sh
# Author: Javier Quilez (GitHub: jaquol)
# Goal: prepares the SampleSheet.csv file required by bcl2fastq using the metadata
#==================================================================================================




#==================================================================================================
# CONFIGURATION VARIABLES AND PATHS
#==================================================================================================

# variables
samples="CAR_25 CAR_26 CAR_27 MMD_3 PFM_7 PFM_8 PFM_9 55205cae2_8d134038b f5082f94c_8d134038b"
run_id=180116_NS500645_0125_AHCFHWBGX5_RUN120_4DG8
project=4DGenome

# paths
if [[ $project == "4DGenome" ]]; then
	UTILS=/users/project/4DGenome/utils
else
	UTILS=$HOME/utils
fi
io_metadata=$UTILS/io_metadata.sh
ofile=SampleSheet.csv



#==================================================================================================
# COMMANDS
#==================================================================================================

# download metadata and update database
$io_metadata -m download_input_metadata

# header
echo '[Data]' > $ofile
echo 'Lane,Sample_ID,Sample_Name,index,index2,' >> $ofile

# add content
i=0
for s in $samples; do

	# get index
	index=`$io_metadata -m get_from_metadata -s $s -t input_metadata -a SEQUENCING_INDEX`

	# get numeric sample name required by bcl2fastq
	i=`expr $i + 1`
	
	# make an entry for each of the 4 lanes of the NextGen sequencer
	for j in `seq 4`; do

		echo "$j,$i,$s,$index," >> $ofile

	done

done

# copy to the corresponding run directory in the 4DGenome workstation
ODIR=four-d@172.17.133.110:/home/four-d/Desktop
scp -v $ofile $ODIR/${run_id}/SampleSheet.csv

rm -f $ofile

