#!/bin/bash
#
# A script that creates the language files inside the data/local/dict/ dir
# (lexicon, nonsilence_phones, silence_phones and optional_silence)
#
# Copyleft Grupo FalaBrasil (2018)
#
# Author: March 2018
# Cassio Batista - cassio.batista.13@gmail.com
# Federal University of Pará (UFPA)
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


if test $# -ne 2
then
    print_fb_ascii
	echo "A script that creates the language files inside the data/local/dict/ dir"
	echo "(lexicon, nonsilence_phones, silence_phones and optional_silence)"
	echo
	echo "Usage: $0 <kaldi_project_dir> <G2P_dir>"
	echo -e "\t<kaldi_project_dir> is the folder where you previously hosted your project on kaldi/egs."
	echo -e "\t                    e.g.: ${HOME}/kaldi/egs/MEUPROJETO"
	echo -e "\t<G2P_dir> is the folder where the G2P software is located."
	echo -e "\t                    e.g.: ${HOME}/fb-nlp/nlp-generator"
	exit 1
elif [ ! -d $1 ] || [ ! -d $2 ]
then
	echo "Error: both '$1' and '$2' must be dirs"
	exit 1
fi


# 0) create wordlist
# eight
# five
# four
# nine
# one
function create_wordlist() {
	echo "creating wordlist..."
	for corpus in $(find ${1}/data/ -name corpus.txt)
	do
		echo "scanning ${corpus}..."
		for word in $(cat $corpus | tr '[A-Z]' '[a-z]' | tr "\'" " " | sed 's/[,.;<>:?!1234"567890()@%]/ /g')
		do
			echo $word >> wlist.tmp 
		done 
	done
	cat wlist.tmp | sort | uniq > wordlist.tmp

	## NOTE: avoiding infinite loop on the next G2P step when generating lexicon
	## G2P only accepts UTF-8 encoded files. ISO-8859-1 then becomes a problem -- CB
	#charset=$(file -b --mime-encoding wordlist.tmp)
	#if [[ "$charset" != "utf-8" ]]
	#then
	#	echo "WARNING: converting file from ${charset} to UTF-8 ..."
	#	iconv -f $charset -t utf-8 wordlist.tmp > out.tmp
	#	mv out.tmp wordlist.tmp
	#fi
}

# a.) lexicon.txt
# !SIL sil
# <UNK> spn
# eight ey t
# five f ay v
# four f ao r
function create_lexicon() {
	echo -n "creating lexicon.txt file... "
	
	java -jar "${2}" -gio wordlist.tmp teste.tmp >/dev/null 2>&1
	mv teste.tmp dict.tmp # FIXME G2P must return grapheme -- CB

	echo -e "!SIL\tsil"   > ${1}/lexicon.txt
	echo -e "<UNK>\tspn" >> ${1}/lexicon.txt
	cat dict.tmp         >> ${1}/lexicon.txt
	echo
}

# b.) create nonsilence_phones.txt
# ah
# ao
# ay
# eh
function create_nonsilence_phones() {
	echo -n "creating nonsilence_phones.txt file... "

	tail -n +3 ${1}/lexicon.txt | awk '{$1="" ; print}' > plist.tmp
	for phone in $(cat plist.tmp)
	do
		echo $phone >> phonelist.tmp
	done
	cat phonelist.tmp | sort | uniq > ${1}/nonsilence_phones.txt
	echo
}

# c.) create silence_phones.txt
# sil
# spn
function create_silence_phones() {
	echo -n "creating silence_phones.txt file... "
	echo "sil"  > ${1}/silence_phones.txt
	echo "spn" >> ${1}/silence_phones.txt
	echo
}

# d.) create optional_silence.txt
# sil
function create_optional_silence() {
	echo -n "creating optional_silence.txt file... "
	echo "sil"  > ${1}/optional_silence.txt
	echo
}

### MAIN ###
basedir=${1}/data/local/dict
g2p_dir=${2}/fb_nlplib.jar
mkdir -p $basedir
create_wordlist $1
create_lexicon $basedir $g2p_dir
create_nonsilence_phones $basedir
create_silence_phones $basedir
create_optional_silence $basedir

echo "Done!"
rm -f *.tmp *.slice
### EOF ###
