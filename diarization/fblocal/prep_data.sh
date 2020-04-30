#!/bin/bash
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
sox_args="-r 16k -b 16 -e signed-integer -t wav - channels 1"

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

function create_data_files() {
    index=$2
    filename=$1.$index.slice
    rm -f {wav.scp,utt2spk}.$index.slice
    tmp=$(mktemp)
    while read line ; do
        uttID=$(basename $line)

        # d.) utt2spk (uttID = spkID + audio filename with no extension .wav)
        # <utteranceID> <speakerID>
        #  dad_4_4_2     dad
        #  july_1_2_5    july
        #  july_6_8_3    july
        # NOTE: CB: If you have no information at all about the speaker
        #           identities, you can just make the speaker-ids the 
        #           same as the utterance-ids, so the format of the 
        #           file would be just <utterance-id> <utterance-id>.
        echo "$uttID $uttID" >> utt2spk.$index.slice

        # b.) wav.scp (uttID = spkID + audio filename with no extension .wav)
        # <utteranceID> <full_path_to_audio_file>
        #  dad_4_4_2     ${HOME}/kaldi/egs/digits/corpus/train/dad/4_4_2.wav
        #  july_1_2_5    ${HOME}/kaldi/egs/digits/corpus/train/july/1_2_5.wav
        #  july_6_8_3    ${HOME}/kaldi/egs/digits/corpus/train/july/6_8_3.wav
        # NOTE: CB - beware: no symlinks anymore
        echo "$uttID sox -G $line.wav $sox_args |" >> wav.scp.$index.slice
    done < $filename
}

corpus_dir=$(readlink -f $1)
data_dir=$2

mkdir -p $data_dir

tmp=filelist
find $corpus_dir -name "*.wav" | sed "s/\.wav//g" > $tmp.tmp
split -de -a 3 -n l/$nj --additional-suffix '.slice' $tmp.tmp "$tmp."

echo -ne "[$(date +'%F %T')] $0: creating data files"
for i in $(seq -f "%03g" 0 $((nj-1))); do
    echo -ne " $i"
    (create_data_files $tmp $i)&
    sleep 0.5
done
echo

for pid in $(jobs -p) ; do
    wait $pid
done

tmp=$(mktemp)
for f in {wav.scp,utt2spk} ; do
    echo "[$(date +'%F %T')] $0: merging file '$f'"
    rm -f $tmp
    for i in $(seq -f "%03g" 0 $((nj-1))); do
        cat $f.$i.slice >> $tmp
    done
    sort $tmp | uniq > $data_dir/$f
done

utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt || exit 1
utils/validate_data_dir.sh --no-feats --no-text $data_dir || exit 1

rm -f *.tmp *.slice
exit 0
