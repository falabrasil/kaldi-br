#!/usr/bin/env bash
#
# creates kaldi data files from multilingual librispeech dataset metadata
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io/

set -e

[ $# -ne 2 ] && echo "usage: $0 <corpus-dir> <data-dir>" && exit 1
corpus_dir=$1
data_dir=$2

[ ! -d $corpus_dir ] && echo "$0: error: bad dir: $corpus_dir" && exit 1
mkdir -p $data_dir || exit 1

sort $corpus_dir/transcripts.txt -o $data_dir/text
awk '{print $1}' $data_dir/text | \
  awk -F '_' '{printf "%s_%s_%s %s\n", $1, $2, $3, $1}' > $data_dir/utt2spk

# https://unix.stackexchange.com/questions/474232/why-cant-paste-print-stdin-next-to-stderr
paste > $data_dir/wav.scp \
  <(awk '{print $1}' $data_dir/text) \
  <(find $corpus_dir -name "*.opus" | sort | \
      awk '{printf "opusdec --quiet --rate 16000 --force-wav %s - |\n", $0}')

#sort -u $data_dir/wav.scp -o $data_dir/wav.scp
#sort -u $data_dir/text -o $data_dir/text
#sort -u $data_dir/utt2spk -o $data_dir/utt2spk
utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/validate_data_dir.sh $data_dir --no-feats --non-print || exit 1
#echo "$0: success! $(wc -l < $data_dir/wav.scp) audio files processed in $corpus_dir"
