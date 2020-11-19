#!/bin/bash
#
# A script that check whether the number of .wav files in the dataset matches
# the number of .mfc files generated after feature extraction. If not, the
# script tells which audio files are causing Kaldi to fail to compute MFCCs, but
# it does not say why: it is up to you figure out :)
#
# Grupo FalaBrasil (2018)
# Federal University of Pará (UFPA)
#
# Author: March 2018
# Cassio Batista - cassio.batista.13@gmail.com
#
# Reference:
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

function print_fb_ascii() {
	echo -e "\033[94m  ____                         \033[93m _____     _           \033[0m"
	echo -e "\033[94m / ___| _ __ _   _ _ __   ___  \033[93m|  ___|_ _| | __ _     \033[0m"
	echo -e "\033[94m| |  _ | '__| | | | '_ \ / _ \ \033[93m| |_ / _\` | |/ _\` |  \033[0m"
	echo -e "\033[94m| |_| \| |  | |_| | |_) | (_) |\033[93m|  _| (_| | | (_| |    \033[0m"
	echo -e "\033[94m \____||_|   \__,_| .__/ \___/ \033[93m|_|  \__,_|_|\__,_|    \033[0m"
	echo -e "                  \033[94m|_|      \033[32m ____                _ _\033[0m\033[91m  _   _ _____ ____    _   \033[0m"
	echo -e "                           \033[32m| __ ) _ __ __ _ ___(_) |\033[0m\033[91m| | | |  ___|  _ \  / \          \033[0m"
	echo -e "                           \033[32m|  _ \| '_ / _\` / __| | |\033[0m\033[91m| | | | |_  | |_) |/ ∆ \        \033[0m"
	echo -e "                           \033[32m| |_) | | | (_| \__ \ | |\033[0m\033[91m| |_| |  _| |  __// ___ \        \033[0m"
	echo -e "                           \033[32m|____/|_|  \__,_|___/_|_|\033[0m\033[91m \___/|_|   |_|  /_/   \_\       \033[0m"
	echo -e ""
}

if test $# -ne 1
then
    print_fb_ascii
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
