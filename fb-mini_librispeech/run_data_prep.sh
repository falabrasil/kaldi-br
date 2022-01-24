#!/usr/bin/env bash
#
# author: jan 2022
# cassio batista - https://cassota.gitlab.io

stage=0
skip_rescoring=false

# Change this location to somewhere where you want to put the data.
data=./corpus/

data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lex_url=https://gitlab.com/fb-resources/dicts-br/-/raw/main/res/lexicon.vocab.txt.gz
lm_small_url=https://gitlab.com/fb-resources/lm-br/-/raw/main/res/3-gram.2e-7.arpa.gz
lm_large_url=https://gitlab.com/fb-resources/lm-br/-/raw/main/res/4-gram.unpruned.arpa.gz

# set this up if you want to run with your own data.
# then execute this script as follows:
# $./run.sh \
#       --audio-dir      DATA_DIR \
#       --lex-file       LEX-FILE \
#       --lm-file-small  LM-FILE-1st-PASS \
#       --lm-file-large  LM-FILE-2nd-PASS
audio_dir=
lex_file=
lm_small_file=
lm_large_file=

. ./cmd.sh
. ./path.sh
. ./fb_commons.sh

. utils/parse_options.sh

set -euo pipefail

# sanity check on file extensions: must be .gz files
for f in $lm_small_file $lm_large_file $lex_file ; do
  [ ! -z $f ] && [[ "$f" != *".gz" ]] && \
    echo "$0: error: model $f must be gunzip-compressed" && exit 1
done

mkdir -p $data
mkdir -p data/local/{dict_nosp,lm}

# data preparation: set up corpora, dict and LMs under $data dir
if [ $stage -le 0 ]; then
  # prepare audio dataset
  if [ -z "$audio_dir" ] ; then
    msg "$0: downloading LapsBM data (85M)"
    if [ -f $data/$(basename $data_url) ] ; then
      echo "$0: data is already in place. skipping download"
    else
      wget --quiet --show-progress $data_url -P $data || exit 1
    fi
    tar -zxf $data/$(basename $data_url) -C $data || exit 1;
  else
    msg "$0: gathering data from '$audio_dir'"
    [ ! -d $data ] && echo "$0: error: data dir $data must exist" && exit 1
    ln -rsf $audio_dir $data
  fi

  # prepare lexicon
  if [ -z "$lex_file" ] ; then
    msg "$0: downloading dict from FalaBrasil GitLab"
    if [ -f $data/$(basename $lex_url) ] ; then
      echo "$0: lexicon already in place. skipping download"
    else
      wget --quiet --show-progress $lex_url -P $data || exit 1
    fi
    gzip -cd $data/$(basename $lex_url) > data/local/dict_nosp/lexicon.txt
  else
    msg "$0: copying lexicon from '$lex_file'"
    cp -v $lex_file $data
    gzip -cd $data/$(basename $lex_file) > data/local/dict_nosp/lexicon.txt
  fi

  # prepare 1st pass decoding n-gram ARPA language model
  if [ -z "$lm_small_file" ] ; then
    msg "$0: downloading 3-gram 1st pass decoding LM from FalaBrasil GitLab"
    if [ -f $data/$(basename $lm_small_url) ] ; then
      echo "$0: 3-gram lm for 1st pass decoding already in place. skipping download"
    else
      wget --quiet --show-progress $lm_small_url -P $data || exit 1
    fi
    ln -rsf $data/$(basename $lm_small_url) data/local/lm/small.arpa.gz
  else
    msg "$0: copying LM small from '$lm_small_file'"
    cp -v $lm_small_file $data
    ln -rsf $data/$(basename $lm_small_file) data/local/lm/small.arpa.gz
  fi

  # prepare 2nd pass rescoring n-gram ARPA language model
  if ! $skip_rescoring ; then
    if [ -z "$lm_large_file" ] ; then
      msg "$0: downloading 4-gram 2nd pass rescoring LM from FalaBrasil GitLab"
      if [ -f $data/$(basename $lm_large_url) ] ; then
        echo "$0: 4-gram lm for 2nd pass rescoring already in place. skipping download"
      else
        wget --quiet --show-progress $lm_large_url -P $data || exit 1
      fi
      ln -rsf $data/$(basename $lm_large_url) data/local/lm/large.arpa.gz
    else
      msg "$0: copying LM large from '$lm_large_file'"
      cp -v $lm_large_file $data
      ln -rsf $data/$(basename $lm_large_file) data/local/lm/large.arpa.gz
    fi
  fi
fi

# data preparation: set up Kaldi data files: scp, text, FST, etc.
if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  msg "$0: prep data"
  /usr/bin/time -f "prep data $PRF" \
    fblocal/prep_data.sh --nj 6 --split-random true $data data
  #fblocal/prep_data.sh --nj 8 --test-dir lapsbm16k $data ./data

  # stage 3 doesn't need local/lm dir
  msg "$0: prep dict"
  /usr/bin/time -f "prep dict $PRF" \
    fblocal/prep_dict.sh --nj 6 data/local/dict_nosp

  # leave as it is
  msg "$0: prep lang"
  /usr/bin/time -f "prep lang $PRF" \
    utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  msg "$0: creating G.fst from low-order ARPA LM"
  cp -r data/lang_nosp data/lang_nosp_test_small
  /usr/bin/time -f "arpa2fst $PRF" \
    gunzip -c data/local/lm/small.arpa.gz | sed "s/<unk>/<UNK>/g" | \
    arpa2fst --disambig-symbol=#0 \
    --read-symbol-table=data/lang_nosp_test_small/words.txt \
    - data/lang_nosp_test_small/G.fst
  utils/validate_lang.pl --skip-determinization-check data/lang_nosp_test_small
  #fblocal/format_lms.sh --src-dir data/lang_nosp data/local/lm

  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  if ! $skip_rescoring ; then
    cp -r data/lang_nosp data/lang_nosp_test_large
    msg "$0: creating G.carpa from high-order ARPA LM"
    gunzip -c data/local/lm/large.arpa.gz | sed "s/<unk>/<UNK>/g" | \
      utils/map_arpa_lm.pl data/lang_nosp_test_large/words.txt | \
      arpa-to-const-arpa \
        --bos-symbol=$(grep "^<s>\s"  data/lang_nosp_test_large/words.txt | awk '{print $2}') \
        --eos-symbol=$(grep "^</s>\s" data/lang_nosp_test_large/words.txt | awk '{print $2}') \
        --unk-symbol=$(grep "<UNK>\s" data/lang_nosp_test_large/words.txt | awk '{print $2}') \
        - data/lang_nosp_test_large/G.carpa  || exit 1;
    # TODO no validate_lang??
  fi
fi

if [ $stage -le 2 ]; then
  mfccdir=mfcc
  msg "$0: compute mfcc and cmvn"
  for part in train test; do
    /usr/bin/time -f "mfcc extraction $PRF" \
      steps/make_mfcc.sh --cmd "$train_cmd" --nj 6 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  # NOTE: there's a rule here to comprise different dataset sizes
  msg "$0: subset data dir"
  n=$(wc -l < data/train/wav.scp)
  if [ $n -lt 1000 ] ; then
    n=$((n/4))  # too few samples
  elif [ $n -gt 5000 ] ; then
    n=1500			# enough samples, ~same as librispeech
  else
    n=500
  fi
  utils/subset_data_dir.sh --shortest data/train $n data/train_500short
fi

msg "$0: success!"
