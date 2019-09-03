#!/bin/bash
#
# A script that fills the files inside data/train and data/test folders
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

SPLIT_RANDOM=true
#dir_test="frases16k"

if test $# -ne 2
then
    print_fb_ascii
	echo "A script that fills the files inside data/train and data/test folders"
	echo
	echo "Usage: $0 <audio_dataset_dir> <kaldi_project_dir>"
	echo -e "\t<audio_dataset_dir> is the folder that contains all your audio base (wav + transcript.)."
	echo -e "\t<kaldi_project_dir> is the folder where you previously hosted your project on kaldi/egs."
	echo -e "\t                    e.g.: /home/cassio/kaldi/egs/MEUPROJETO"
	exit 1
elif [ ! -d $1 ] || [ ! -d $2 ]
then
	echo "Error: both '$1' and '$2' must be dirs"
	exit 1
fi

function check_data_finish_test() {
	brk_test=false
	files=("corpus.txt" "text" "utt2spk" "wav.scp") # XXX: spk2gender left out
	while [[ $brk_test == false ]] ; do
		brk_test=false
		for f in ${files[@]} ; do
			lines=$(wc -l "${1}/data/test/${f}" | awk '{print $1}')
			if [[ $lines -eq $2 ]] ; then
				brk_test=true
			else
				brk_test=false
				sleep 30
				break
			fi
		done
	done
}

function check_data_finish_train() {
	brk_train=false
	files=("corpus.txt" "text" "utt2spk" "wav.scp") # XXX spk2gender left out
	while [[ $brk_train == false ]] ; do
		brk_train=false
		for f in ${files[@]} ; do
			lines=$(wc -l "${1}/data/train/${f}" | awk '{print $1}')
			if [[ $lines -eq $2 ]] ; then
				brk_train=true
			else
				brk_train=false
				sleep 30
				break
			fi
		done
	done
}

function split_dataset_bg() {
	spkrID=$(echo $1 | sed 's/\// /g' | awk '{print $(NF-1)}')
	mkdir -p ${2}/${spkrID}
	ln -s ${1}.wav ${2}/${spkrID}
	ln -s ${1}.txt ${2}/${spkrID}
}

# 0.) split train 
function split_dataset() {
	echo "defining $2 set: ($3) "
	basedir="${1}/data/${2}"
	while read line ; do
		(split_dataset_bg $line $basedir)&
	done < $3
	echo ; sleep 1
}

# a.) spk2gender (spkrID = folder name) XXX: SORTED!
# <speakerID> <gender>
#  cristine    f
#  dad         m
#  josh        m
#  july        f
function create_spk2gender() {
	rm -f s2g.tmp
	while read line ; do
		# unix.stackexchange - bash-string-replace-multiple-chars-with-one
		# stackoverflow - extracting-first-two-characters-of-a-string-shell-scripting
		spkrID=$(sed 's/\// /g' <<< $line | awk '{print $(NF-1)}')
		aux=$(tr -cs 'A-Za-z0-9' ' ' <<< $spkrID | awk '{print substr ($NF,0,1)}' | tr '[FM]' '[fm]')
		gender=$(grep 'f' <<< $aux || echo "m")
		echo "$spkrID $gender" >> s2g.tmp
	done < ${2}.${3}.list
	sort s2g.tmp | uniq > ${1}/data/${2}/spk2gender
}

# b.) wav.scp (uttID = spkrID + audio filename with no extension .wav)
# <utteranceID> <full_path_to_audio_file>
#  dad_4_4_2     /home/{user}/kaldi-trunk/egs/digits/digits_audio/train/dad/4_4_2.wav
#  july_1_2_5    /home/{user}/kaldi-trunk/egs/digits/digits_audio/train/july/1_2_5.wav
#  july_6_8_3    /home/{user}/kaldi-trunk/egs/digits/digits_audio/train/july/6_8_3.wav
function create_wav_scp() {
	rm -f ${1}/data/${2}/wav.scp
	while read line
	do
		spkrID=$(echo $line | sed 's/\// /g' | awk '{print $(NF-1)}')
		filename=$(echo $line | sed 's/\// /g' | awk '{print $NF}').wav
		filepath="${1}/data/${2}/${spkrID}/${filename}"
		uttID="${spkrID}_$(basename $line)"
		
		# FIXME: readlink doesn't work on symlinks, it gets the original abs path
		#echo "$uttID ${filepath}/${filename}" >> ${1}/data/${2}/wav.scp
		echo "$uttID ${filepath}" >> ${1}/data/${2}/wav.scp
	done < ${2}.${3}.list
}

# c.) text (uttID = spkrID + audio filename with no extension .wav)
# <utteranceID> <text_transcription>
#  dad_4_4_2     four four two
#  july_1_2_5    one two five
#  july_6_8_3    six eight three
function create_text() {
	rm -f ${1}/data/${2}/text
	while read line
	do
		spkrID=$(echo $line | sed 's/\// /g' | awk '{print $(NF-1)}')
		uttID="${spkrID}_$(basename $line | sed 's/.wav//g')"
		echo "$uttID $(cat ${line}.txt)" >> ${1}/data/${2}/text
	done < ${2}.${3}.list
}

# d.) utt2spk (uttID = spkrID + audio filename with no extension .wav)
# <utteranceID> <speakerID>
#  dad_4_4_2     dad
#  july_1_2_5    july
#  july_6_8_3    july
function create_utt2spk() {
	rm -f ${1}/data/${2}/utt2spk
	while read line; do
		spkrID=$(echo $line | sed 's/\// /g' | awk '{print $(NF-1)}')
		uttID="${spkrID}_$(basename $line | sed 's/.wav//g')"
		echo "$uttID ${spkrID}" >> ${1}/data/${2}/utt2spk
	done < ${2}.${3}.list
}
 
# e.) corpus.txt 
# <text_transcription>
#  one two five
#  six eight three
#  four four two
function create_corpus() {
	rm -f ${1}/data/${2}/corpus.txt
	while read line
	do
		cat ${line}.txt | grep -avE '^$'  >> ${1}/data/${2}/corpus.txt
	done < ${2}.${3}.list
}

### main ###
# sort -R would have solved this crap (while read line)
if [[ $SPLIT_RANDOM == true ]]
then
	echo -n "let there be random splitting then. this might take a bit longer... "
	find $1 -name '*.wav' |\
			while read line; do echo "$RANDOM $(readlink -f $line)" ; done |\
			sort | awk '{print $NF}' | sed 's/.wav//g' > filelist.tmp
	
	ntotal=$(cat filelist.tmp | wc -l)
	ntest=$((ntotal/10))     # 10% test
	ntrain=$((ntotal-ntest)) # 90% train
	
	head -n $ntrain filelist.tmp > train.list
	tail -n $ntest  filelist.tmp > test.list

	rm filelist.tmp
	echo "done splitting"
else
	echo -n "NOTE: using only '$dir_test' for test! splitting (this might take a but longer) ... "
	find "${1}" -name '*.wav' | grep -v "${dir_test}" |\
			while read line; do readlink -f $line ; done |\
			sed 's/.wav//g' > train.list
	find "${1}/${dir_test}" -name '*.wav' |\
			while read line; do readlink -f $line ; done |\
			sed 's/.wav//g' > test.list

	ntrain=$(wc -l train.list | awk '{print $1}')
	ntest=$(wc -l test.list | awk '{print $1}')
	echo "done splitting"
fi

# train files
echo -n "copying train files "
for i in $(seq 5) ; do
	outfile="train.${i}.list"
	echo -n "$i " ; rm -f $outfile
	cp -f train.list $outfile
done
echo "ok"

# test files
echo -n "copying test files "
for i in $(seq 5) ; do
	outfile="test.${i}.list"
	echo -n "$i " ; rm -f $outfile
	cp -f test.list $outfile
done
echo "ok"

echo -e "\033[1mcreating 'spk2gender' ...\033[0m"
(create_spk2gender "$2" "test"  "5")&
(create_spk2gender "$2" "train" "5")&
sleep 1
echo -e "\033[1mcreating 'wav.scp' ...\033[0m"
(create_wav_scp    "$2" "test"  "1")&
(create_wav_scp    "$2" "train" "1")&
sleep 1
echo -e "\033[1mcreating 'text' ...\033[0m"
(create_text       "$2" "test"  "2")&
(create_text       "$2" "train" "2")&
sleep 1
echo -e "\033[1mcreating 'utt2spk' ...\033[0m"
(create_utt2spk    "$2" "test"  "3")&
(create_utt2spk    "$2" "train" "3")& 
sleep 1
echo -e "\033[1mcreating 'corpus.txt' ...\033[0m"
(create_corpus     "$2" "test"  "4")&
(create_corpus     "$2" "train" "4")&
sleep 1
echo -e "\033[1msplitting dataset...\033[0m"
(split_dataset     "$2" "test" "test.list")&

# loucura loucura loucura
slice=$((ntrain/10))
for i in $(seq 10) ; do
	head train.list -n $((i*slice)) | tail -n $slice > train.${i}.slice
done

sliceleft=$((ntrain-i*slice))
if [[ $sliceleft -gt 0 ]] ; then
	i=$((i+1))
	tail train.list -n $sliceleft > train.${i}.slice
fi

for j in $(seq 1 $((i/2))) ; do
	(split_dataset "$2" "train" "train.${j}.slice")&
done
sleep 1

echo -n "waiting for data files ... "
check_data_finish_test  $2 $ntest
echo -n "test ok, "
check_data_finish_train $2 $ntrain 
echo "train ok"

for j in $(seq $((1+i/2)) $i) ; do
	(split_dataset "$2" "train" "train.${j}.slice")&
done
sleep 1

echo -e "\e[1mDone!\e[0m"
rm train.list test.list
rm train.*.list test.*.list
#rm train.*.slice

notify-send "'$0' finished" 2> /dev/null || echo "'$0' finished"
### EOF ###
