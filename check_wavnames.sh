#!/bin/bash
#
# A script that check if .wav files are somehow duplicate, which can occur when
# you have two audios with the very same name but think it is ok just because
# they are inside different folders. For Kaldi, they are not ok.
#
# Copyleft Grupo FalaBrasil (2018)
#
# Author: March 2018
# Cassio Batista - cassio.batista.13@gmail.com
# Federal University of Pará (UFPA)
#
# Reference:
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

if test $# -ne 1
then
	echo "usage: bash ${0} <audio_dataset_dir>"
	echo -e "\t<audio_dataset_dir> is the folder that contains all your audio base (wav + transcript.)."
	exit 1
fi

find $1 -name "*.wav" > wavlist.orig
cat wavlist.orig | sed 's/\// /g' | awk '{print $NF}' | sort | uniq > wavlist.uniq

o=$(wc -l wavlist.orig | awk '{print $1}')
u=$(wc -l wavlist.uniq | awk '{print $1}')

if [[ $o == $u ]] ; then
	echo "your audio corpora do not appear to have common filenames"
	echo "original wavlist: ${o} files"
	echo "unique wavlist:   ${u} files"
else
	echo "WE HAVE A PROBLEM WITH THESE FILES: "
	cat wavlist.orig | sed 's/\// /g' | awk '{print $NF}' | sort | uniq -cd 
fi

rm -f wavlist.*
