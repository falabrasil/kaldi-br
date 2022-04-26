#!/usr/bin/env bash
#
# parses common voices *.tsv files into Kaldi files
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e 

if [ $# -ne 2 ] ; then
  echo "usage: $0 <tsv-file> <data-dir>"
  exit 1
fi
tsv_file=$1
data_dir=$2

[ ! -f $tsv_file ] && echo >&2 "$0: error: bad tsv file: $tsv_file" && exit 1
mkdir -p $data_dir || exit 1
#rm -f $data_dir/{wav.scp,text,utt2spk}

# TODO I could use client_id as uttid but I didn\'t want to (lazy)
# hopefully files don\'t need to be uniquely sorted again - cassio
corpus_dir=$(dirname $tsv_file)/clips
cut -f2 $tsv_file | tail -n +2 | cut -d'.' -f1 | sort -u | awk -v dir=$corpus_dir '{print $1" sox -G "dir"/"$1".mp3 -c1 -b16 -r16k -esigned -t wav - |"}' > $data_dir/wav.scp
cut -f2 $tsv_file | tail -n +2 | cut -d'.' -f1 | sort -u | awk '{print $1" "$1}' > $data_dir/utt2spk
cut -f2-3 $tsv_file | tail -n +2 | sort -u | sed -e 's/\.mp3\t/ /g' | sed 's/['\''«»"”?!,;:\.]//g' | awk '{print tolower($0)}' > $data_dir/text
