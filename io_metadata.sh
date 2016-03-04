#!/bin/bash


#==================================================================================================
# Created on: 2016-02-05
# Usage: ./update_metadata.sh <mode> <sample_id>
# Author: javier.quilez@crg.eu
# Goal: add/get metadata from a database
#==================================================================================================

# workflow:
# variables are passed through the script parameters --depending on the mode, 'sample_id' is not required
# the 'main' function executes the different functions depending on the selected mode
# (note that 'main' is only executed at the end of the script)
# the different functions basically do:
# (1) parse files generated by other tools (e.g. FastQC) to extract metadata
# (2) add to or get from the metadata database through  python script



#==================================================================================================
# CONFIGURATION VARIABLES AND PATHS
#==================================================================================================

# get variables
while getopts ":m:s:p:t:a:v:u:" opt; do
	case $opt in
		m) mode="$OPTARG"
		;;
		s) sample_id="$OPTARG"
		;;
		p) sequencing_type="$OPTARG"
		;;
		t) table="$OPTARG"
		;;
		a) attribute="$OPTARG"
		;;
		v) value="$OPTARG"
		;;
		u) time_stamp="$OPTARG"
		;;
		\?) echo "invalid option -$OPTARG" >&2
		;;
	esac
done

# paths 
db=/users/GR/mb/jquilez/data/beato_lab_metadata.db
io_metadata=/users/GR/mb/jquilez/utils/io_metadata.py



#==================================================================================================
# CODE EXECUTION
#==================================================================================================

main() {

	# check that at least mode is passes as script parameter
	if ! [[ -n "$mode" ]]; then
		message_info "mode (-m <mode>) is not provided; exiting..."
		exit
	fi

 	if [[ $mode == "download_input_metadata" ]]; then
 		download_input_metadata
	
 	elif [[ $mode == "quality_control_raw_reads" ]]; then
 		if [[ -n $sample_id && $sequencing_type == 'PE' ]]; then
 			#echo "sample_id=$sample_id sequencing_type=$sequencing_type"
 			quality_control_raw_reads read1
 			quality_control_raw_reads read2
 		elif [[ -n $sample_id && $sequencing_type == 'SE' ]]; then
 			echo "sample_id=$sample_id sequencing_type=$sequencing_type"
 			quality_control_raw_reads read1
		else
			message_info "-s <sample_id> and/or -p <sequencing_type> are not provided; exiting..."
			exit
		fi

	elif [[ $mode == "get_from_metadata" ]]; then
 		if [[ -n $sample_id && -n $table && -n $attribute ]]; then
			python $io_metadata $db 'get_from_metadata' $table $sample_id $attribute
		else
			message_info "-s <sample_id>, -t <table> and/or -a <attribute> are not provided; exiting..."
			exit
		fi
	
	elif [[ $mode == "add_to_metadata" ]]; then
		if [[ -n $table && -n $sample_id && -n $time_stamp && -n $attribute && -n $value ]]; then
			python $io_metadata $db 'add_to_metadata' $table $sample_id $time_stamp $attribute $value
		else
			message_info "-t <table>, -s <sample_id>, -u <time_stamp> -a <attribute> and or -v <value> are not provided; exiting..."
			message_info "t=$table s=$sample_id u=$time_stamp a=$attribute v=$value"
			exit
		fi

	fi

}



#==================================================================================================
# FUNCTIONS
#==================================================================================================

message_info() {

	message=$1
	echo -e "INFO \t`date +"%Y-%m-%d %T"` \t[$mode] \t$message"

}


download_input_metadata() {

	# download input metadata from an online Google spreadsheet

	url="goo.gl/vjQ5sf"
	spreadsheet=/users/GR/mb/jquilez/data/tmp_downloaded_metadata.txt

	# Get spreadsheet --make sure to:
	# (1) publish the spreadsheet as shown here: http://onetipperday.blogspot.com.es/2014/01/access-google-spreadsheet-directly-in.html
	# (2) this is the link to the most updated spreadsheet
	wget --no-check-certificate -q -O - $url > $spreadsheet

	# update metada and delete intermediate file
	python $io_metadata $db download_input_metadata $spreadsheet
	rm $spreadsheet
}

quality_control_raw_reads() {

	which_read=$1

	# FastQC report
	fastqc_data=/users/GR/mb/jquilez/data/*/raw/*/fastqc/$sample_id*${which_read}_fastqc/fastqc_data.txt
	python $io_metadata $db quality_control_raw_reads $sample_id "${which_read^^}_PATH_FASTQC_REPORT" $fastqc_data
	
	# FastQC version
	fastqc_version=`grep "##FastQC" $fastqc_data | cut -f2`
	python $io_metadata $db quality_control_raw_reads $sample_id 'FASTQC_VERSION' $fastqc_version

	# Basic statistics module
	# (1) total sequences
	total_sequences=`grep "Total Sequences" $fastqc_data | cut -f2`
	python $io_metadata $db quality_control_raw_reads $sample_id "${which_read^^}_N_READS_SEQUENCED" $total_sequences
	# (2) read length
	# check that both read length from the input metadata agrees with the actual read length
	# or update otherwise
	read_length_from_fastqc=`grep "Sequence length" $fastqc_data | cut -f2`
	read_length_from_metadata=`get_from_metadata input_metadata 'SEQUENCING_READ_LENGTH'`
	python $io_metadata $db quality_control_raw_reads $sample_id "${which_read^^}_SEQUENCING_READ_LENGTH" $read_length_from_fastqc
	if [[ $read_length_from_fastqc != $read_length_from_metadata ]]; then
		message_info "read length from the input metadata does not agrees with the actual read length for $which_read"
	fi
	# (3) GC-content
	gc_content=`grep "%GC" $fastqc_data | cut -f2`
	python $io_metadata $db quality_control_raw_reads $sample_id "${which_read^^}_GC" $gc_content

	# Per base sequence quality
	module='Per base sequence quality'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Per tile sequence quality
	module='Per tile sequence quality'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Per base sequence content
	module='Per base sequence content'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Per sequence GC content
	module='Per sequence GC content'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Per base N content
	module='Per base N content'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Sequence Duplication Levels
	# (1) module flag
	module='Sequence Duplication Levels'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag
	# (2) Total deduplicated percentage
	deduplicated_percentage=`grep "Total Deduplicated Percentage" $fastqc_data | cut -f2`
	python $io_metadata $db quality_control_raw_reads $sample_id "${which_read^^}_DEDUPLICATED_PERCENTAGE" $deduplicated_percentage

	# Overrepresented sequences
	module='Overrepresented sequences'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Adapter Content
	module='Adapter Content'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

	# Kmer Content
	module='Kmer Content'
	flag=`cat $fastqc_data | grep "$module" | cut -f2`
	module_renamed=`echo ${module^^} | sed 's/ /_/g'`
	python $io_metadata $db quality_control_raw_reads $sample_id ${which_read^^}_${module_renamed} $flag

}



# execute main function
main
