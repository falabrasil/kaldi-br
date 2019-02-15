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

if test $# -ne 1
then
	echo "A script that creates the language files inside the data/local/dict/ dir"
	echo "(lexicon, nonsilence_phones, silence_phones and optional_silence)"
	echo
	echo "Usage: $0 <kaldi_project_dir>"
	echo -e "\t<kaldi_project_dir> is the folder where you previously hosted your project on kaldi/egs."
	echo -e "\t                    e.g.: /home/cassio/kaldi/egs/MEUPROJETO"
	exit 1
elif [ ! -d $1 ] 
then
	echo "Error: '$1' must be a dir"
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
}

# a.) lexicon.txt
# !SIL sil
# <UNK> spn
# eight ey t
# five f ay v
# four f ao r
function create_lexicon() {
	echo -n "creating lexicon.txt file... "

#	[[ -z "$(which lapsg2p)" ]] && echo "error: g2p must be installed" && exit 1
#	lapsg2p -w wordlist.tmp -d dict.tmp >/dev/null 2>&1
	java -jar falalib.jar -f wordlist.tmp teste.tmp -g >/dev/null 2>&1
	paste wordlist.tmp teste.tmp > dict.tmp


	echo "!SIL sil"   > ${1}/lexicon.txt
	echo "<UNK> spn" >> ${1}/lexicon.txt
	cat dict.tmp     >> ${1}/lexicon.txt
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
mkdir -p $basedir
create_wordlist $1
create_lexicon $basedir
create_nonsilence_phones $basedir
create_silence_phones $basedir
create_optional_silence $basedir

echo "Done!"
rm *.tmp
### EOF ###
