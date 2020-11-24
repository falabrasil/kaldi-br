#!/usr/bin/env bash
#
#
# author: nov 2020
# cassio batista - https://cassota.gitlab.io

nlp_dir=${HOME}/fb-gitlab/fb-nlp/nlp-generator

if test $# -ne 2 ; then
  echo "usage: $0 <data-dir> <lexicon-file>"
  echo "  e.g.: $0 ./data ./data/local/dict/lexicon.txt"
  exit 1
fi

data_dir=$1
lex_file=$2

[ -d $data_dir ] || { echo "$0: expected data dir to exist" && exit 1; }
[ -f $lexicon ] || { echo "$0: expected lexicon file to exist" && exit 1; }

tmp_wlist=$(mktemp)
for part in train test ; do
  corpus=$data_dir/$part/corpus.txt
  for word in $(cat $corpus) ; do
    echo $word
  done
done | sort | uniq > $tmp_wlist

# NOTE: the following will add duplicate words to lexicon, which shall be
# removed later by fblocal/prep_dict.sh
echo "$0: creating lexicon"
tmp_dict=$(mktemp)

LC_ALL=pt_BR.UTF-8 java -jar $nlp_dir/fb_nlplib.jar -g -i $tmp_wlist -o $tmp_dict
cat $tmp_dict >> $lex_file
rm -f $tmp_wlist $tmp_dict
