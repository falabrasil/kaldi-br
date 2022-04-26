#!/usr/bin/env bash
#
# parses a *.list file that accompanies dataset in DVC remote repo
# into Kaldi data files such as wav.scp, text and utt2spk.
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e

if [ $# -ne 2 ] ; then
  echo "usage: $0 <list-file> <data-dir>"
  exit 1
fi
list_file=$1
data_dir=$2

[ ! -f $list_file ] && echo >&2 "$0: error: bad list file: $list_file" && exit 1
mkdir -p $data_dir || exit 1

i=0
corpus_dir=$(dirname $list_file)
rm -f $data_dir/{wav.scp,text,utt2spk}
while read line ; do
  wav=$corpus_dir/$line
  txt=${wav%.wav}.txt
  [[ ! -f $wav || ! -f $txt ]] && \
    echo >&2 "$0: error: bad wav or txt file: '$wav' vs. '$txt'" && exit 1
  spkid=$(basename $(dirname $wav) | sed 's/-/_/g')
  uttid=${spkid}_$(basename ${wav%.wav} | sed 's/-/_/g')
  echo "$uttid sox -G $wav -c1 -b16 -r16k -esigned -t wav - |" >> $data_dir/wav.scp
  echo "$uttid $(cat $txt)" >> $data_dir/text
  echo "$uttid $spkid" >> $data_dir/utt2spk
  i=$((i+1))
done < $list_file
sort -u $data_dir/wav.scp -o $data_dir/wav.scp
sort -u $data_dir/text -o $data_dir/text
sort -u $data_dir/utt2spk -o $data_dir/utt2spk
utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/validate_data_dir.sh $data_dir --no-feats --non-print || exit 1
#echo "$0: success! $i audio files processed in $list_file"
