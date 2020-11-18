#!/bin/bash
#
# Create resource files inside data/train and data/test folders.
# This script used to be called 'fb_01' in the old days.
#
# The files created are  the following:
#   - text
#   - wav.scp
#   - utt2spk
#   - spk2gender
#   - corpus.txt
#   - extra_questions.txt
#   - spk2utt
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/
#
# Reference:
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

nj=2
split_random=false
test_dir="lapsbm16k"

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 2 ; then
    echo "Usage: $0 <corpus-dir> <data-dir>"
    echo "  <corpus-dir> is the folder where you downloaded the dataset"
    echo "  <data-dir> is the folder will hold the files created"
    echo "    e.g.: $0 ./corpus ./data"
    exit 1
elif [ ! -d $1 ] ; then
    echo "$0: Error: '$1' must be a dir"
    exit 1
fi

corpus_dir=$(readlink -f $1)
data_dir=$2

if $split_random ; then
    echo -n "$0: dataset will be random split. "
    echo "this might take a while... "
    find "$corpus_dir" -name '*.wav' | sort -R |\
        awk '{print $NF}' | sed 's/.wav//g' > filelist.tmp
    ntotal=$(cat filelist.tmp | wc -l)
    ntest=$((ntotal/10))     # 10% test
    ntrain=$((ntotal-ntest)) # 90% train
    head -n $ntrain filelist.tmp > train.list
    tail -n $ntest  filelist.tmp > test.list
    rm filelist.tmp
elif [ ! -z "$test_dir" ] ; then
    echo -n "$0: NOTE: using only '$test_dir' for test! "
    echo "this might take a while... "
    find $corpus_dir -name '*.wav' | grep -v "${test_dir}" |\
           sed 's/.wav//g' > train.list
    find $corpus_dir/$test_dir -name '*.wav' |\
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

for part in train test ; do
    mkdir -p ${data_dir}/${part}
    split -de -a 3 -n l/${nj} --additional-suffix '.slice' ${part}.list "${part}."
done

for part in train test ; do
    # fork processes
    echo -n "$0: creating $part files: "
    for i in $(seq -f "%03g" 0 $((nj-1))); do
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
        echo "$0: merging file '$f' for ${part} dataset"
        rm -f ${data_dir}/${part}/${f}
        for i in $(seq -f "%03g" 0 $((nj-1))); do
            suff=${part}.${i}
            cat ${f}.${suff} >> ${data_dir}/${part}/${f}
            rm ${f}.${suff}
        done
    done
done

# TODO CB: check the impact of putting this section into the above loop
tmp=$(mktemp)
for part in train test ; do
    #for f in {text,wav.scp,utt2spk,spk2gender,corpus.txt} ; do
    for f in {text,wav.scp,utt2spk,spk2gender} ; do
        sort ${data_dir}/${part}/${f} | uniq > $tmp
        mv $tmp ${data_dir}/${part}/${f}
    done
done

for part in train test ; do 
    utils/utt2spk_to_spk2utt.pl \
        ${data_dir}/${part}/utt2spk > ${data_dir}/${part}/spk2utt || exit 1
    utils/validate_data_dir.sh --non-print --no-feats ${data_dir}/${part}  || exit 1
done

rm *.slice *.list
exit 0
