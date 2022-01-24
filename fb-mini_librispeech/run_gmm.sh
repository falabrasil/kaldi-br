#!/usr/bin/env bash
#
# adapted from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# author: apr 2020
# cassio trindade batista - https://cassota.gitlab.io
# last updated: aug 2021

stage=0
skip_rescoring=false

. ./cmd.sh
. ./path.sh
. ./fb_commons.sh

. utils/parse_options.sh

set -euo pipefail

# train a monophone system
if [ $stage -le 0 ]; then
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
if [ $stage -le 1 ]; then
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
if [ $stage -le 2 ]; then
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
if [ $stage -le 3 ]; then
  msg "$0: train sat"
  /usr/bin/time -f "train tri-sat $PRF" \
    steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 4 ]; then
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
    gunzip -c data/local/lm/small.arpa.gz | sed "s/<unk>/<UNK>/g" | \
      arpa2fst --disambig-symbol=#0 \
               --read-symbol-table=data/lang_test_small/words.txt \
               - data/lang_test_small/G.fst
  utils/validate_lang.pl --skip-determinization-check data/lang_test_small

  if [ -f data/local/lm/large.arpa.gz ] ; then
    cp -r data/lang data/lang_test_large
    gunzip -c data/local/lm/large.arpa.gz | sed "s/<unk>/<UNK>/g" | \
      utils/map_arpa_lm.pl data/lang_test_large/words.txt | \
      arpa-to-const-arpa \
        --bos-symbol=$(grep "^<s>\s"  data/lang_test_large/words.txt | awk '{print $2}') \
        --eos-symbol=$(grep "^</s>\s" data/lang_test_large/words.txt | awk '{print $2}') \
        --unk-symbol=$(grep "<UNK>\s" data/lang_test_large/words.txt | awk '{print $2}') \
        - data/lang_test_large/G.carpa  || exit 1;
    # TODO no validate_lang??
  fi

  /usr/bin/time -f "align fmllr $PRF" \
    steps/align_fmllr.sh --nj 6 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

# Test the tri3b system with the silprobs and pron-probs.
# NOTE: all decoding routines have been moved to run_decode.sh.
#       we only create the graph that's needed for DNN training
if [ $stage -le 5 ]; then
  msg "$0: generating tri-sat graph (with sil probs)"
  /usr/bin/time -f "mkgraph $PRF" \
    utils/mkgraph.sh data/lang_test_small \
      exp/tri3b exp/tri3b/graph_small
fi

msg "$0: success!"
