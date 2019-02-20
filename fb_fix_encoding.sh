#!/bin/bash
#
# Create environment tree for training acoustic models with Kaldi
#
# Copyleft Grupo FalaBrasil (2018)
#
# Authors: Feb 2019
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Federal University of Pará (UFPA)
#
# Reference: 
# http://kaldi-asr.org/doc/kaldi_for_dummies.html
# https://www.eleanorchodroff.com/tutorial/kaldi/kaldi-training.html

if test $# -ne 1
then
	echo "A script to fix encoding of text files to UTF-8"
	echo
	echo "Usage: $0 <audio_dataset_dir>"
	echo -e "\t<audio_dataset_dir> is the folder that contains all your audio base (wav + transcript.)."
	exit 1
elif [ ! -d $1 ]
then
	echo "dir '${1}' does not exist."
	exit 1
fi

echo "checking encoding..."
for txt in $(find $1 -name "*.txt")
do
	encoding=$(file -b --mime-encoding $txt)
	if [[ "$encoding" != "utf-8" ]] ; then
		echo "[$encoding] creating backup at ${txt}~"
		cp ${txt} "${txt}~"
		iconv -f $encoding -t utf-8 $txt > out
		mv out $txt
	fi
done
echo "done"

### EOF ###
