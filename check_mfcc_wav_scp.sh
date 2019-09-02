#!/bin/bash
#
# A script that check whether the number of .wav files in the dataset matches
# the number of .mfc files generated after feature extraction. If not, the
# script tells which audio files are causing Kaldi to fail to compute MFCCs, but
# it does not say why: it is up to you figure out :)
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
	echo "Usage: $0 <proj_dir>"
	echo -e "\t<proj_dir> must be the path for your project folder *within* kaldi/egs parent dirs."
	echo -e "\te.g.: /home/cassio/kaldi/egs/MEUPROJETO"
	exit 1
fi

echo "checking on train folder..."
awk '{print $1}' ${1}/data/train/wav.scp    > train.scp
awk '{print $1}' ${1}/data/train/feats.scp >> train.scp
if [[ $(sort train.scp | uniq -u | wc -l) == 0  ]] ; then
	echo "no problems in train folder."
else
	echo "problems occured with these files below: "
	sort train.scp | uniq -u 
fi

echo "checking on test folder..."
awk '{print $1}' ${1}/data/test/wav.scp    > test.scp
awk '{print $1}' ${1}/data/test/feats.scp >> test.scp
if [[ $(sort test.scp | uniq -u | wc -l) == 0  ]] ; then
	echo "no problems in test folder."
else
	echo "problems occured with these files below: "
	sort test.scp | uniq -u 
fi

rm -f {train,test}.scp
echo "done"
### EOF ###
