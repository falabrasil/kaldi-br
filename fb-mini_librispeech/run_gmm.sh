#!/usr/bin/env bash
#
# adapted from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# author: apr 2020
# cassio trindade batista - https://cassota.gitlab.io
# last updated: aug 2021


# Change this location to somewhere where you want to put the data.
data=./corpus/

data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lex_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lexicon.utf8.dict.gz
lm_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lm.3gram.arpa.gz

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

stage=0
. utils/parse_options.sh

set -euo pipefail

# sanity check on file extensions: must be .gz files
for f in $lm_small_file $lm_large_file $lex_file ; do
  [ ! -z $f ] && [[ "$f" != *".gz" ]] && \
    echo "$0: error: model $f must be gunzip-compressed" && exit 1
done

mkdir -p $data
mkdir -p data/local/{dict_nosp,lm}

s_time=$(date +'%F_%T')

# data preparation: set up corpora, dict and LMs under $data dir
if [ $stage -le 0 ]; then
  # prepare audio dataset
  if [ -z "$audio_dir" ] ; then
    msg "$0: downloading LapsBM data (85M)"
    /usr/bin/time -f "downloading data $PRF" \
      fblocal/download_data.sh $data $data_url
  else
    msg "$0: gathering data from '$audio_dir'"
    data=$audio_dir
    [ ! -d $data ] && echo "$0: error: data dir $data must exist" && exit 1
  fi

  # prepare lexicon
  if [ -z "$lex_file" ] ; then
    msg "$0: downloading dict from FalaBrasil GitLab"
    /usr/bin/time -f "downloading lexicon $PRF" \
      fblocal/download_lexicon.sh $data $lex_url data/local/dict_nosp
  else
    msg "$0: copying lexicon from '$lex_file'"
    cp -v $lex_file $data
    gzip -cd $data/$(basename $lex_file) > data/local/dict_nosp/lexicon.txt
  fi

  # prepare 1st pass decoding n-gram ARPA language model
  if [ -z "$lm_small_file" ] ; then
    msg "$0: downloading LM from FalaBrasil GitLab"
    /usr/bin/time -f "downloading lm $PRF" \
      fblocal/download_lm.sh $data $lm_url data/local/lm
  else
    msg "$0: copying LM small from '$lm_small_file'"
    cp -v $lm_small_file $data
    ln -rsf $data/$(basename $lm_small_file) data/local/lm/small.arpa.gz
  fi

  # prepare 2nd pass rescoring n-gram ARPA language model
  # NOTE: we do not provide an LM for lattice rescoring because we don't
  #       have enough data to train one. it's optional anyways, but if
  #       you want it, you'll have to train your own.
  if [ ! -z "$lm_large_file" ] ; then
    msg "$0: copying LM large from '$lm_large_file'"
    cp -v $lm_large_file $data
    ln -rsf $data/$(basename $lm_large_file) data/local/lm/large.arpa.gz
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
    gunzip -c data/local/lm/small.arpa.gz | \
    arpa2fst --disambig-symbol=#0 \
    --read-symbol-table=data/lang_nosp_test_small/words.txt \
    - data/lang_nosp_test_small/G.fst
  utils/validate_lang.pl --skip-determinization-check data/lang_nosp_test_small
  #fblocal/format_lms.sh --src-dir data/lang_nosp data/local/lm

  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  if [ ! -z "$lm_large_file" ] ; then
    msg "$0: creating G.carpa from high-order ARPA LM"
    /usr/bin/time -f "arpa2carpa $PRF" \
      utils/build_const_arpa_lm.sh data/local/lm/large.arpa.gz \
      data/lang_nosp data/lang_nosp_test_large
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

# train a monophone system
if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  msg "$0: train mono"
  /usr/bin/time -f "train mono $PRF" \
    steps/train_mono.sh --boost-silence 1.25 --nj 6 --cmd "$train_cmd" \
    data/train_500short data/lang_nosp exp/mono

  msg "$0: align mono"
  /usr/bin/time -f "align mono $PRF" \
    steps/align_si.sh --boost-silence 1.25 --nj 6 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono exp/mono_ali_train
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  msg "$0: train deltas"
  /usr/bin/time -f "train tri-deltas $PRF" \
    steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train data/lang_nosp exp/mono_ali_train exp/tri1

  msg "$0: align deltas"
  /usr/bin/time -f "align tri-deltas $PRF" \
    steps/align_si.sh --nj 6 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri1 exp/tri1_ali_train
fi

# train an LDA+MLLT system.
if [ $stage -le 5 ]; then
  msg "$0: train lda mllt"
  /usr/bin/time -f "train tri-lda $PRF" \
    steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train data/lang_nosp exp/tri1_ali_train exp/tri2b

  # Align utts using the tri2b model
  msg "$0: align lda mllt"
  /usr/bin/time -f "align tri-lda $PRF" \
    steps/align_si.sh --nj 6 --cmd "$train_cmd" --use-graphs true \
    data/train data/lang_nosp exp/tri2b exp/tri2b_ali_train
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 6 ]; then
  msg "$0: train sat"
  /usr/bin/time -f "train tri-sat $PRF" \
    steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 7 ]; then
  msg "$0: add silence and pronunciation probabilities (sp)"
  /usr/bin/time -f "get prons $PRF" \
    steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b

  /usr/bin/time -f "creating new dict dir with sp $PRF" \
    utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  /usr/bin/time -f "prep lang $PRF" \
    utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  #fblocal/format_lms.sh --src-dir data/lang data/local/lm
  cp -r data/lang data/lang_test_small
  /usr/bin/time -f "arpa2fst $PRF" \
    gunzip -c data/local/lm/small.arpa.gz | \
      arpa2fst --disambig-symbol=#0 \
               --read-symbol-table=data/lang_test_small/words.txt \
               - data/lang_test_small/G.fst
  utils/validate_lang.pl --skip-determinization-check data/lang_test_small

  if [ ! -z "$lm_large_file" ] ; then
    /usr/bin/time -f "arpa2carpa $PRF" \
      utils/build_const_arpa_lm.sh data/local/lm/large.arpa.gz \
          data/lang data/lang_test_large
    # TODO no validate_lang??
  fi

  /usr/bin/time -f "align fmllr $PRF" \
    steps/align_fmllr.sh --nj 6 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

# Test the tri3b system with the silprobs and pron-probs.
# NOTE: all decoding routines have been moved to run_decode.sh.
#       we only create the graph that's needed for DNN training
if [ $stage -le 8 ]; then
  msg "$0: generating tri-sat graph (with sil probs)"
  /usr/bin/time -f "mkgraph $PRF" \
    utils/mkgraph.sh data/lang_test_small \
      exp/tri3b exp/tri3b/graph_small
fi

# README README README README README README README README README README README 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# XXX XXX XXX XXX XXX XXX Train a TDNN-F chain model XXX XXX XXX XXX XXX XXX 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# NOTE: if you *do not* have an NVIDIA card, then open up the
#       following script and set the following options on 
#       stage 14 to `train.py`:
#           --trainer.optimization.num-jobs-initial=2
#           --trainer.optimization.num-jobs-final=3
#           --use-gpu=false
#       we do not recommend training the DNN on CPU, though. 
#       you'd better set up Kaldi on Google Colab instead.
# NOTE: if you do have multiple GPU cards, on the other hand,
#       then set the parameters as the following:
#           --trainer.optimization.num-jobs-initial=2
#           --trainer.optimization.num-jobs-final=4
#           --use-gpu=true
#       (the example above assumes you have 4 NVIDIA cards)
if [ $stage -le 9 ]; then
  msg "$0: run TDNN-F script"
  /usr/bin/time -f "tdnn $PRF" \
    ./run_tdnn.sh
fi

e_time=$(date +'%F_%T')

msg "$0: success!"
echo $s_time
echo $e_time
