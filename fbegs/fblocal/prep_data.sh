#!/bin/bash
#
# A script that fills the files inside data/train and data/test folders
# This scripts was used to be called 'fb_01' in the old days.
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# Author: Apr 2020
# Cassio Batista - https://cassota.gitlab.io/
#
# Reference:
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

[ -z $NJ ] && NJ=2

SPLIT_RANDOM=true
DIR_TEST="lapsbm16k"

if test $# -ne 2 ; then
    echo "A script that fills the files inside data/train and data/test folders"
    echo
    echo "Usage: $0 <corpus-dir> <data-dir>"
    echo "  <corpus-dir> is the folder where you downloaded the dataset"
    echo "  <data-dir> is the folder will hold the files created"
    echo "    e.g.: $0 ./corpus ./data"
    exit 1
elif [ ! -d $1 ] ; then
    echo "$0: Error: '$1' must be a dir"
    exit 1
fi

corpus_dir=$1
data_dir=$2

# check dependencies
for f in gawk dos2unix ; do
    if ! type -t $f > /dev/null ; then
        echo "$0: error: please install $f"
        exit 1
    fi
done

if $SPLIT_RANDOM ; then
    echo -n "[$(date +'%F %T')] $0: dataset will be random split. "
    echo "this might take a while... "
    find "$corpus_dir" -name '*.wav' | sort -R |\
        awk '{print $NF}' | sed 's/.wav//g' > filelist.tmp
    ntotal=$(cat filelist.tmp | wc -l)
    ntest=$((ntotal/10))     # 10% test
    ntrain=$((ntotal-ntest)) # 90% train
    head -n $ntrain filelist.tmp > train.list
    tail -n $ntest  filelist.tmp > test.list
    rm filelist.tmp
elif [ ! -z "$DIR_TEST" ] ; then
    echo -n "[$(date +'%F %T')] $0: NOTE: using only '$DIR_TEST' for test! "
    echo "this might take a while... "
    find "$corpus_dir" -name '*.wav' | grep -v "${DIR_TEST}" |\
            while read line; do readlink -f $line ; done |\
            sed 's/.wav//g' > train.list
    find "$corpus_dir/$DIR_TEST" -name '*.wav' |\
            while read line; do readlink -f $line ; done |\
            sed 's/.wav//g' > test.list
    ntrain=$(wc -l train.list | awk '{print $1}')
    ntest=$(wc -l test.list | awk '{print $1}')
else
    echo
    echo "$0: Houston we have a problem"
    exit 1
fi

function create_data_files() {
    presuffix=$1
    filelist=${presuffix}.slice
    rm -f {text,wav.scp,utt2spk,spk2gender,corpus.txt}.${presuffix}
    tmp=$(mktemp)
    while read line ; do
        # unix.stackexchange - bash-string-replace-multiple-chars-with-one
        # stackoverflow - extracting-first-two-characters-of-a-string-shell-scripting
        spkID=$(sed 's/\// /g' <<< $line | awk '{print $(NF-1)}')
        wavname=$(basename $line).wav
        uttID="${spkID}_${wavname}"

        # c.) text (uttID = spkID + audio filename with no extension .wav)
        # <utteranceID> <text_transcription>
        #  dad_4_4_2     four four two
        #  july_1_2_5    one two five
        #  july_6_8_3    six eight three
        echo "$uttID $(cat ${line}.txt | dos2unix)" >> text.${presuffix}

        # d.) utt2spk (uttID = spkID + audio filename with no extension .wav)
        # <utteranceID> <speakerID>
        #  dad_4_4_2     dad
        #  july_1_2_5    july
        #  july_6_8_3    july
        echo "$uttID $spkID" >> utt2spk.${presuffix}

        # b.) wav.scp (uttID = spkID + audio filename with no extension .wav)
        # <utteranceID> <full_path_to_audio_file>
        #  dad_4_4_2     ${HOME}/kaldi/egs/digits/corpus/train/dad/4_4_2.wav
        #  july_1_2_5    ${HOME}/kaldi/egs/digits/corpus/train/july/1_2_5.wav
        #  july_6_8_3    ${HOME}/kaldi/egs/digits/corpus/train/july/6_8_3.wav
        # NOTE: CB - beware: no symlinks anymore
        echo "$uttID ${line}.wav" >> wav.scp.${presuffix}

        # a.) spk2gender (spkID = folder name) XXX: SORTED!
        # <speakerID> <gender>
        #  cristine    f
        #  dad         m
        #  josh        m
        #  july        f
        # NOTE: FalaBrasil's datasets follot this nomenclature
        #       - West Point:                  - LapsBenchmark:               
        #               - f01br16b22k1                 - LapsBM-F004          
        #               - m09br16b22k1                 - LapsBM-M001          
        #       - CETUC:  ^                    - Spoltech:      ^
        #               -     AnaVarela_F042           - BR-F00430
        #               - EduardoTardin_M022           - BR-M00171
        #                               ^                   ^
        #       Datasets like "constituicao" which is single-speaker and 
        #       do not contain any gender info in the dir name are 
        #       assumed to be male by default
        aux=$(tr -cs 'A-Za-z0-9' ' ' <<< $spkID)
        aux=$(awk '{print substr ($NF,0,1)}' <<< $aux | tr '[FM]' '[fm]')
        gender=$(grep 'f' <<< $aux || echo "m")
        echo "$spkID $gender" >> $tmp

        # e.) corpus.txt 
        # <text_transcription>
        #  one two five
        #  six eight three
        #  four four two
        cat ${line}.txt | grep -avE '^$' | dos2unix >> corpus.txt.${presuffix}
    done < $filelist
    sort $tmp | uniq > spk2gender.${presuffix}
    rm -f $tmp
}

## https://stackoverflow.com/questions/12061410/how-to-replace-a-path-with-another-path-in-sed
#function link_data() {
#    proj_rootdir="$1"
#    data_basedir=$(readlink -f $2 | sed 's_/_\\/_g')
#    filelist=${3}.slice
#    part=$(echo $3 | cut -d '.' -f 1)
#    cat $filelist | sed "s/$data_basedir//g" | xargs dirname | sort | uniq > ${filelist}.tmp
#    while read line ; do
#        mkdir -p ${proj_rootdir}/data/${part}/${line}
#    done < ${filelist}.tmp
#    rm ${filelist}.tmp
#    while read line ; do
#        filepath=$(echo $line | sed "s/$data_basedir//g" | xargs dirname)
#        ln -s ${line}.wav ${proj_rootdir}/data/${part}/${filepath}
#        ln -s ${line}.txt ${proj_rootdir}/data/${part}/${filepath}
#    done < $filelist
#}

for part in train test ; do
    mkdir -p ${data_dir}/${part}
    split -de -a 3 -n l/${NJ} --additional-suffix '.slice' ${part}.list "${part}."
done

for part in train test ; do
    # fork processes
    echo "[$(date +'%F %T')] $0: creating $part files"
    for i in $(seq -f "%03g" 0 $((NJ-1))); do
        [ $((i%10)) -eq 0 ] && echo -ne "\n$0: spawning thread:"
        echo -ne " $i"
        (create_data_files ${part}.${i})&
        sleep 0.5
    done
    echo

    # wait
    # https://stackoverflow.com/questions/356100/how-to-wait-in-bash-for-several-subprocesses-to-finish-and-return-exit-code-0
    for pid in $(jobs -p) ; do
        wait $pid
    done

    # merge
    for f in {text,wav.scp,utt2spk,spk2gender,corpus.txt} ; do
        echo "[$(date +'%F %T')] $0: merging file '$f' for ${part} dataset"
        rm -f ${data_dir}/${part}/${f}
        for i in $(seq -f "%03g" 0 $((NJ-1))); do
            suff=${part}.${i}
            cat ${f}.${suff} >> ${data_dir}/${part}/${f}
            rm ${f}.${suff}
        done
    done
done

tmp=$(mktemp)
for part in train test ; do
    #for f in {text,wav.scp,utt2spk,spk2gender,corpus.txt} ; do
    for f in {text,wav.scp,utt2spk,spk2gender} ; do
        sort ${data_dir}/${part}/${f} | uniq > $tmp
        mv $tmp ${data_dir}/${part}/${f}
    done
done

## TODO CB: link_data() should be part of download_data.sh
#for part in train test ; do
#    echo "[$(date +'%F %T')] $0: symlinking $part dataset"
#    for i in $(seq -f "%03g" 0 $((NJ-1))); do
#        (link_data "$1" "$2" ${part}.${i})&
#    done
#done
#
#for pid in $(jobs -p) ; do
#    wait $pid
#done

for part in train test ; do 
    utils/utt2spk_to_spk2utt.pl \
        ${data_dir}/${part}/utt2spk > ${data_dir}/${part}/spk2utt || exit 1
    utils/validate_data_dir.sh --no-feats ${data_dir}/${part}  || exit 1
done

echo -e "\e[1mDone!\e[0m"
rm *.slice *.list

notify-send "'$0' finished" 2> /dev/null || echo "'$0' finished"
### EOF ###
