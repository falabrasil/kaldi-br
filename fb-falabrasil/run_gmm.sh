#!/usr/bin/env bash
#
# trains gmm models
# adapted from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# TODO number of senones still tuned according to mini-libri recipe 
#
# author: may 2022
# cassio batista - https://cassota.gitlab.io

set -euo pipefail

nj=12
stage=0

. ./cmd.sh || exit 1
. ./path.sh || exit 1
. ./commons.sh || exit 1

. utils/parse_options.sh

# train a monophone system
if [ $stage -le 0 ]; then
  msg "$0: train mono"
  prf steps/train_mono.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
    data/train_5k_nodup data/lang_nosp exp/mono || exit 1
  prf steps/align_si.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" \
    data/train_10k data/lang_nosp exp/mono exp/mono_ali || exit 1
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 1 ]; then
  msg "$0: train deltas"
  prf steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train_10k data/lang_nosp exp/mono_ali exp/tri1 || exit 1
  prf steps/align_si.sh --nj $nj --cmd "$train_cmd" \
    data/train_30k data/lang_nosp exp/tri1 exp/tri1_ali || exit 1
fi

# train an LDA+MLLT system.
if [ $stage -le 2 ]; then
  msg "$0: train lda mllt"
  prf steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train_30k data/lang_nosp exp/tri1_ali exp/tri2b || exit 1
  prf steps/align_si.sh --nj $nj --cmd "$train_cmd" --use-graphs true \
    data/train_30k data/lang_nosp exp/tri2b exp/tri2b_ali || exit 1
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 3 ]; then
  msg "$0: train sat"
  prf steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train_30k data/lang_nosp exp/tri2b_ali exp/tri3b || exit 1
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 4 ]; then
  msg "$0: add silence and pronunciation probabilities (sp)"
  prf steps/get_prons.sh --cmd "$train_cmd" \
    data/train_all data/lang_nosp exp/tri3b

  prf utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt \
    exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt \
    data/local/dict

  prf utils/prepare_lang.sh \
    data/local/dict "<UNK>" data/local/lang_tmp data/lang

  symtab=data/lang_test_small/words.txt
  if [ -f data/lang_test_small/G.fst ] ; then
    echo "$0: warn: G.fst exists. skipping compilation..."
  else
    cp -r data/lang data/lang_test_small
    gunzip -c data/local/lm/small.arpa.gz | \
      sed "s/<unk>/<UNK>/g" | \
      arpa2fst \
        --disambig-symbol=#0 \
        --read-symbol-table=$symtab \
        - data/lang_test_small/G.fst || exit 1
  fi
  utils/validate_lang.pl --skip-determinization-check \
    data/lang_test_small || exit 1

  # FIXME -L untested
  # NOTE carpa generation consumes a lot of RAM
  if [ -L data/local/lm/large.arpa.gz ] ; then
    symtab=data/lang_test_large/words.txt
    if [ -f data/lang_test_large/G.carpa ] ; then
      echo "$0: warn: G.carpa exists. skipping compilation..."
    else
      cp -r data/lang data/lang_test_large
      gunzip -c data/local/lm/large.arpa.gz | \
        sed "s/<unk>/<UNK>/g" | utils/map_arpa_lm.pl $symtab | \
        arpa-to-const-arpa \
          --bos-symbol=$(grep "^<s>\s"  $symtab | awk '{print $2}') \
          --eos-symbol=$(grep "^</s>\s" $symtab | awk '{print $2}') \
          --unk-symbol=$(grep "<UNK>\s" $symtab | awk '{print $2}') \
          - data/lang_test_large/G.carpa || exit 1
    fi
    # TODO no validate_lang??
  fi

  # finally, align sat
  prf steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
    data/train_all data/lang exp/tri3b exp/tri3b_ali || exit 1
fi

# Test the tri3b system with the silprobs and pron-probs.
# NOTE: all decoding routines have been moved to run_decode.sh.
#       we only create the graph that's needed for DNN training
if [ $stage -le 5 ]; then
  msg "$0: generating tri-sat graph (with sil probs)"
  prf utils/mkgraph.sh data/lang_test_small exp/tri3b exp/tri3b/graph_small || exit 1
fi

msg "$0: success!"
