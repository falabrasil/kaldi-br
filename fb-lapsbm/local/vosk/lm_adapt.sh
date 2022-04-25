#!/usr/bin/env bash
#
# trains a mini lm with missing words to interpolate with the big one.
# script adapted from @nshmyrev's on vosk model v0.21 for English:
# https://alphacephei.com/vosk/models/vosk-model-en-us-0.21-compile.zip
#
# author: oct 2021
# cassio batista - https://cassota.gitlab.io


function msg { echo -e "\e[$(shuf -i 92-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }

[ $# -ne 2 ] && echo "usage: $0 <lm-decoding-arpa> <lm-rescore-arpa>" && exit 1
LM_SMALL_ARPA=$1
LM_LARGE_ARPA=$2
for f in $LM_SMALL_ARPA $LM_LARGE_ARPA ; do
  [ ! -f $f ] && echo "$0: error: bad lm file: $f" && exit 1
done

. path.sh

set -e

s_date=$(date)

rm -rf data/local/lm/*.gz data/local/dict/*.txt
rm -rf data/lang data/lang_tmp data/lang_test_small data/lang_test_large
rm -rf exp/chain_online_cmn/tree_sp/graph_small

msg "$0: merging lexicons"
(
  head -n +2 data_bkp/local/dict/lexicon.txt ;
  (
    tail -n +3 data_bkp/local/dict/lexicon.txt ;
    cat samples/missing.dict ;
  ) | LC_ALL=C sort -u ;
) > /tmp/lexicon.txt
mv -v /tmp/lexicon.txt data/local/dict/lexicon.txt
cp -v data_bkp/local/dict/{silence_phones,nonsilence_phones,optional_silence}.txt data/local/dict

msg "$0: calling srilm scripts"
/usr/bin/time -f "$0: ngram-count: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  ngram-count -wbdiscount -order 4 \
    -text samples/missing.txt \
    -lm data/extra.lm.gz
/usr/bin/time -f "$0: mix 4-gram: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  ngram -order 4 \
    -lm data_bkp/local/lm/$LM_LARGE_ARPA \
    -mix-lm data/extra.lm.gz \
    -lambda 0.95 \
    -write-lm data/local/lm/$LM_LARGE_ARPA
/usr/bin/time -f "$0: prune 4-gram: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  ngram -order 4 \
    -lm data/local/lm/$LM_LARGE_ARPA \
    -prune 1e-7 \
    -write-lm data/en-mixp.lm.gz
/usr/bin/time -f "$0: 3-gram: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  ngram -order 3 \
    -lm data/en-mixp.lm.gz \
    -write-lm data/local/lm/$LM_SMALL_ARPA 

msg "$0: calling kaldi scripts"
/usr/bin/time -f "$0: prep lang: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  utils/prepare_lang.sh \
    data/local/dict "<UNK>" data/lang_tmp data/lang
/usr/bin/time -f "$0: arpa2fst: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  utils/format_lm.sh \
    data/lang data/local/lm/$LM_SMALL_ARPA data/local/dict/lexicon.txt data/lang_test_small
/usr/bin/time -f "$0: mkgraph: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  utils/mkgraph.sh --self-loop-scale 1.0 data/lang_test_small \
    exp/chain_online_cmn/tree_sp exp/chain_online_cmn/tree_sp/graph_small
/usr/bin/time -f "$0: arpa2carpa: %E (user: %U secs, system: %S secs)\tRAM: %M KB" \
  utils/build_const_arpa_lm.sh \
    data/local/lm/$LM_LARGE_ARPA data/lang data/lang_test_large

e_date=$(date)

msg "$0: done!"
echo $s_date
echo $e_date
