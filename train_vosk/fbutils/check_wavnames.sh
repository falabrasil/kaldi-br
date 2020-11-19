#!/bin/bash
#
# A script that check if .wav files are somehow duplicate, which can occur when
# you have two audios with the very same name but think it is ok just because
# they are inside different folders. For Kaldi, they are not ok.
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
