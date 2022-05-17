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

export LC_ALL=pt_BR.utf8

[ ! -d $corpus_dir ] && echo "$0: error: bad dir: $corpus_dir" && exit 1
mkdir -p $data_dir || exit 1

cp $corpus_dir/txt/segments $data_dir/segments

trans=$corpus_dir/txt/$(basename $corpus_dir).pt
local/data/mtedx/norm.py < $trans > $data_dir/text 2> $data_dir/norm.log
local/data/mtedx/filter.py $data_dir/{text,segments,utt2spk,norm.log} || exit 1
sort -u $data_dir/text -o $data_dir/text
sort -u $data_dir/segments -o $data_dir/segments
sort -u $data_dir/utt2spk -o $data_dir/utt2spk

for recid in $(awk '{print $2}' $data_dir/utt2spk | sort -u) ; do
  [ ! -f $corpus_dir/wav/$recid.flac ] && \
    echo >&2 "$0: error: bad recid $recid" && exit 1
  echo "$recid sox -G $corpus_dir/wav/$recid.flac -c1 -b16 -r16k -esigned -t wav - |"
done | sort -u > $data_dir/wav.scp
#paste > $data_dir/wav.scp \
#  <(awk '{print $2}' $data_dir/segments) \
#  <(find $corpus_dir -name "$(awk '{print $2}' $data_dir/utt2spk).flac" | sort -u | \
#      awk '{printf "sox -G %s -c1 -b16 -r16k -esigned -t wav - |\n", $0}')
#sort -u $data_dir/wav.scp -o $data_dir/wav.scp

utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/fix_data_dir.sh $data_dir
utils/validate_data_dir.sh $data_dir --no-feats --non-print || exit 1
#echo "$0: success! $(wc -l < $data_dir/segments) utts processed in $corpus_dir"
