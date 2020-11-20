#!/usr/bin/env bash
#
# This script takes the same sequence of steps as mini-librispeech recipe,
# but with some tweakings to perform according to the aspire recipe. For
# example, we don't create as many data subsets as in aspire recipe, nor create
# our own LM on the fly: we download an already trained LM from the cloud, and
# we only create a second training subset apart from the main one, with the
# purpose of training the monophones on a smaller set. However, triphone deltas
# e SAT training do take two passes as in aspire recipe - Cassio
#
# adapted from:
#   kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#   kaldi/egs/aspire/s5/run.sh           (7a45e657d)
#
# Author: Nov 2020
# Cassio Batista - https://cassota.gitlab.io
# Last updated: dec 2020

# Change this location to somewhere where you want to put the data.
data=./corpus

decode=false    # perform decode for each model?
decode_bg=false # throw decoding processes to background?

data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lex_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lexicon.utf8.dict.gz
lm_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lm.3gram.arpa.gz
#nlp_dir=${HOME}/fb-gitlab/fb-nlp/nlp-generator/ # TODO deploy heroku java server?

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data

start_time=$(date +'%F %T')

# NOTE: CB: if you have multiple datasets you better download them beforehand,
#       comment out this script and call "link_local_data.sh" instead.
echo "[$(date +'%F %T')] $0: download data (85M)" | lolcat
fblocal/download_data.sh $data $data_url || exit 1
#fblocal/link_local_data.sh --nj 8 ${HOME}/fb-gitlab/fb-audio-corpora $data || exit 1

if [ $stage -le 0 ]; then
  # CB: args 1 and 2 are swapped from the original
  echo "[$(date +'%F %T')] $0: download lm" | lolcat
  fblocal/download_lm.sh $data $lm_url data/local/lm || exit 1

  echo "[$(date +'%F %T')] $0: download lexicon" | lolcat
  fblocal/download_lexicon.sh $data $lex_url data/local/dict || exit 1
fi

if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  echo "[$(date +'%F %T')] $0: prep data" | lolcat
  fblocal/prep_data.sh --nj 3 --split-random true $data data
  #fblocal/prep_data.sh --nj 8 --test-dir lapsbm16k $data ./data

  # stage 3 doesn't need local/lm dir - Cassio
  echo "[$(date +'%F %T')] $0: prep dict" | lolcat 
  fblocal/prep_dict.sh --nj 4 data/local/dict

  # leave as it is - Cassio
  echo "[$(date +'%F %T')] $0: prep lang" | lolcat
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang

  # lm file had to be renamed inside this script
  echo "[$(date +'%F %T')] $0: create test lang" | lolcat
  fblocal/fisher_create_test_lang.sh || exit 1
fi

if [ $stage -le 2 ]; then
  mfccdir=mfcc
  echo "[$(date +'%F %T')] $0: compute mfcc and cmvn" | lolcat
  for part in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 \
        data/$part exp/make_mfcc/$part $mfccdir || exit 1
    steps/compute_cmvn_stats.sh \
        data/$part exp/make_mfcc/$part $mfccdir || exit 1
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  # CB: changed to 250
  # NOTE: aspire's recipe trains on a 10k utt subset - Cassio
  echo "[$(date +'%F %T')] $0: subset data dir" | lolcat
  utils/subset_data_dir.sh --shortest data/train 250 data/train_500short
fi

# train a monophone system
if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  echo "[$(date +'%F %T')] $0: train mono" | lolcat
  steps/train_mono.sh --nj 5 --cmd "$train_cmd" \
    data/train_500short data/lang exp/mono0a

  # NOTE aspire recipe uses conf/decode.config as config file but we are
  # skipping it here
  if $decode ; then
    # TODO: Understand why we use lang here...
    (
      echo "[$(date +'%F %T')] $0: generating mono graph" | lolcat
      utils/mkgraph.sh data/lang_test exp/mono0a exp/mono0a/graph
      echo "[$(date +'%F %T')] $0: decoding mono" | lolcat
      steps/decode.sh --nj 6 --cmd "$decode_cmd" \
          exp/mono0a/graph data/test exp/mono0a/decode_test
      grep -Rn WER exp/mono0a/decode_test | \
          utils/best_wer.sh | tee exp/mono0a/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align mono" | lolcat
  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/mono0a exp/mono0a_ali
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  echo "[$(date +'%F %T')] $0: train deltas (1st pass)" | lolcat
  steps/train_deltas.sh --cmd "$train_cmd" \
    2500 20000 data/train data/lang exp/mono0a_ali exp/tri1

  # decode using the tri1 model
  if $decode ; then
    (
    echo "[$(date +'%F %T')] $0: generating tri deltas graph (1st pass)" | lolcat
      utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph
      echo "[$(date +'%F %T')] $0: decoding deltas (1st pass)" | lolcat
      steps/decode.sh --nj 6 --cmd "$decode_cmd" \
          exp/tri1/graph data/test exp/tri1/decode_test
      grep -Rn WER exp/tri1/decode_test | \
          utils/best_wer.sh | tee exp/tri1/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align deltas (1st pass)" | lolcat
  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri1 exp/tri1_ali
fi

# train a second delta + delta-delta triphone system on all utterances
if [ $stage -le 5 ]; then
  echo "[$(date +'%F %T')] $0: train deltas (2nd pass)" | lolcat
  steps/train_deltas.sh --cmd "$train_cmd" \
    2000 10000 data/train data/lang exp/tri1_ali exp/tri2

  # decode using the tri2 model
  if $decode ; then
    (
    echo "[$(date +'%F %T')] $0: generating tri deltas graph (2nd pass)" | lolcat
      utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
      echo "[$(date +'%F %T')] $0: decoding deltas (2nd pass)" | lolcat
      steps/decode.sh --nj 6 --cmd "$decode_cmd" \
          exp/tri2/graph data/test exp/tri2/decode_test
      grep -Rn WER exp/tri2/decode_test | \
          utils/best_wer.sh | tee exp/tri2/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align deltas (2nd pass)" | lolcat
  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri2 exp/tri2_ali || exit 1
fi

# train an LDA+MLLT system.
if [ $stage -le 6 ]; then
  echo "[$(date +'%F %T')] $0: train lda mllt" | lolcat
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5000 40000 data/train data/lang exp/tri2_ali exp/tri3a || exit 1

  # decode using the tri3a LDA+MLLT model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating lda mllt graph" | lolcat
      utils/mkgraph.sh data/lang_test exp/tri3a exp/tri3a/graph
      echo "[$(date +'%F %T')] $0: decoding lda mllt" | lolcat
      steps/decode.sh --nj 6 --cmd "$decode_cmd" \
          exp/tri3a/graph data/test exp/tri3a/decode_test
      grep -Rn WER exp/tri3a/decode_test | \
          utils/best_wer.sh | tee exp/tri3a/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align lda mllt" | lolcat
  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri3a exp/tri3a_ali
fi

# Train first LDA+MLLT+SAT
if [ $stage -le 7 ]; then
  echo "[$(date +'%F %T')] $0: train sat (1st pass)" | lolcat
  steps/train_sat.sh --cmd "$train_cmd" \
    5000 100000 data/train data/lang exp/tri3a_ali exp/tri4a || exit 1

  # decode using the tri4a sat model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating sat graph (1st pass)" | lolcat
      utils/mkgraph.sh data/lang_test exp/tri4a exp/tri4a/graph
      echo "[$(date +'%F %T')] $0: decoding sat (1st pass)" | lolcat
      steps/decode_fmllr.sh --nj 6 --cmd "$decode_cmd" \
        exp/tri4a/graph data/test exp/tri4a/decode_test
      grep -Rn WER exp/tri4a/decode_test | \
          utils/best_wer.sh | tee exp/tri4a/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align sat (1st pass)" | lolcat
  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri4a exp/tri4a_ali
fi

# Train second LDA+MLLT+SAT
if [ $stage -le 8 ]; then
  echo "[$(date +'%F %T')] $0: train sat (2nd pass)" | lolcat
  steps/train_sat.sh --cmd "$train_cmd" \
    10000 300000 data/train data/lang exp/tri4a_ali exp/tri5a || exit 1

  # decode using the tri5a sat model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating sat graph (2nd pass)" | lolcat
      utils/mkgraph.sh data/lang_test exp/tri5a exp/tri5a/graph
      echo "[$(date +'%F %T')] $0: decoding sat (2nd pass)" | lolcat
      steps/decode_fmllr.sh --nj 6 --cmd "$decode_cmd" \
        exp/tri5a/graph data/test exp/tri5a/decode_test
      grep -Rn WER exp/tri5a/decode_test | \
          utils/best_wer.sh | tee exp/tri5a/decode_test/fbwer.txt
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
# NOTE: in aspire recipe, this comes within a script named build_silprob.sh
if [ $stage -le 9 ]; then
  echo "[$(date +'%F %T')] $0: get prons" | lolcat
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang exp/tri5a

  echo "[$(date +'%F %T')] $0: dict add pron probs (pp)" | lolcat
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict \
    exp/tri5a/pron_counts_nowb.txt \
    exp/tri5a/sil_counts_nowb.txt \
    exp/tri5a/pron_bigram_counts_nowb.txt \
    data/local/dict_pp

  echo "[$(date +'%F %T')] $0: prep lang pp" | lolcat
  utils/prepare_lang.sh data/local/dict_pp \
    "<UNK>" data/local/lang_pp data/lang_pp

  cp -rT data/lang_pp         data/lang_pp_test
  cp -fv data/lang_test/G.fst data/lang_pp_test

  cp -rT data/lang_pp              data/lang_pp_test_fg
  cp -fv data/lang_test_fg/G.carpa data/lang_pp_test_fg

  echo "[$(date +'%F %T')] $0: generating graph pp" | lolcat
  utils/mkgraph.sh data/lang_pp_test exp/tri5a exp/tri5a/graph_pp

  # echo "[$(date +'%F %T')] $0: format lm" | lolcat
  # fblocal/format_lms.sh --src-dir data/lang data/local/lm

  # echo "[$(date +'%F %T')] $0: build const arpa" | lolcat
  # utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
  #     data/lang data/lang_test_tglarge

  # echo "[$(date +'%F %T')] $0: align fmllr" | lolcat
  # steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
  #   data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

## Test the tri3b system with the silprobs and pron-probs.
#if [ $stage -le 8 ]; then
#  # decode using the tri3b model
#  if $decode ; then
#    (
#      echo "[$(date +'%F %T')] $0: generating sat graph (with sil probs)" | lolcat
#      utils/mkgraph.sh data/lang_test_tgsmall \
#                       exp/tri3b exp/tri3b/graph_tgsmall
#      echo "[$(date +'%F %T')] $0: decoding sat (with sil probs)" | lolcat
#      steps/decode_fmllr.sh --nj 6 --cmd "$decode_cmd" \
#                            exp/tri3b/graph_tgsmall data/test \
#                            exp/tri3b/decode_tgsmall_test
#      grep -Rn WER exp/tri3b/decode_tgsmall_test | \
#          utils/best_wer.sh > exp/tri3b/decode_tgsmall_test/fbwer.txt
#    )&
#    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
#  fi
#fi

# Train a chain model
# FIXME beware the number of epochs reduced by a half, original is 20.
#       I reduced it for things to run faster while debugging - Cassio
# NOTE: if you do not have an NVIDIA card, then set use-gpu to
#       'false', jobs initial to 2 and jobs final to 4. OTOH, if you
#       have multiple NVIDIA GPUs, then you might want to increase the
#       number of jobs final accordingly - Cassio
if [ $stage -le 10 ]; then
  echo "[$(date +'%F %T')] $0: run TDNN script" | lolcat
  fblocal/chain/run_tdnn.sh --use-gpu true \
      --jobs-initial 1 --jobs-final 1 --num-epochs 10
fi

end_time=$(date +'%F %T')

# local/grammar/simple_demo.sh

# Don't finish until all background decoding jobs are finished.
wait

echo "$0: done! started at '$start_time' and finished at '$end_time'" | lolcat

# https://superuser.com/questions/294161/unix-linux-find-and-sort-by-date-modified
find -name fbwer.txt -printf "%T@ %Tc %p\n" | sort -n | awk '{print $NF}' | xargs cat
