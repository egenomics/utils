#!/bin/bash
#$ -N 
#$ -q short-sl65
#$ -l virtual_free=50G
#$ -l h_rt=06:00:00
#$ -M javier.quilez@crg.eu
#$ -m abe
#$ -o /users/GR/mb/jquilez/utils/job_out/_$JOB_ID.out
#$ -e /users/GR/mb/jquilez/utils/job_out/_$JOB_ID.err
#$ -pe smp 8
/software/mb/bin/STAR --version
/software/mb/bin/STAR --runMode genomeGenerate --genomeDir /users/GR/mb/jquilez/assemblies/homo_sapiens/hg19/star_genome_index/read_length_50bp --genomeFastaFiles /users/GR/mb/jquilez/assemblies/homo_sapiens/hg19/ucsc/hg19.fa --runThreadN 8 --sjdbOverhang 50 --sjdbGTFfile /users/GR/mb/jquilez/assemblies/homo_sapiens/hg19/gencode/gencode.v19.annotation.gtf --outFileNamePrefix /users/GR/mb/jquilez/assemblies/homo_sapiens/hg19/star_genome_index/read_length_50bp/
