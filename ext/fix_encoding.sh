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
