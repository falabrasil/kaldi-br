#!/usr/bin/env bash
#
# creates kaldi data files from multilingual TEDx metadata
#
# NOTE: this dataset requires the 'segment' file.
# NOTE: do *NOT* sort stuff early bc *.pt trans file doesn't have utt info.
# NOTE: effort here is something else bc it requires normalising text stuff.
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e

[ $# -ne 2 ] && echo "usage: $0 <corpus-dir> <data-dir>" && exit 1
corpus_dir=$1
data_dir=$2

[ ! -d $corpus_dir ] && echo "$0: error: bad dir: $corpus_dir" && exit 1
mkdir -p $data_dir || exit 1

cp $corpus_dir/txt/segments $data_dir
awk '{print $1" "$2}' $data_dir/segments > $data_dir/utt2spk

# FIXME there are music tags and fillers like "aplausos" amongst the transcript.
# but we can't hug the world with our own hands can we ¯\_(ツ)_/¯
paste > $data_dir/text \
  <(awk '{print $1}' $data_dir/segments) \
  <(local/data/norm_mtedx.py < $corpus_dir/txt/$(basename $corpus_dir).pt)

paste > $data_dir/wav.scp \
  <(awk '{print $2}' $data_dir/segments | sort -u) \
  <(find $corpus_dir -name "*.flac" | sort | \
      awk '{printf "sox -G %s -c1 -b16 -r16k -esigned -t wav - |\n", $0}')

sort -u $data_dir/wav.scp -o $data_dir/wav.scp  # no need to, but pelo sim pelo não...
sort -u $data_dir/text -o $data_dir/text
sort -u $data_dir/utt2spk -o $data_dir/utt2spk
utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/validate_data_dir.sh $data_dir --no-feats --non-print || exit 1
#echo "$0: success! $(wc -l < $data_dir/segments) utts processed in $corpus_dir"
