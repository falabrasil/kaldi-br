#!/usr/bin/env bash
#
# trains gmm models individually in a per-dataset basis.
# this is useful for analysing each dataset's influence, 
# both for speech recognition and forced alignment.
#
# adapted from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# TODO number of senones still tuned according to mini-libri recipe 
#
# NOTE constituicao, coddef, and lapsstory are trained earlier and
# in background because few-speaker datasets are poorly parallelized
# in kaldi. this uses exactly 7 jobs in parallel.
#
# author: apr 2022
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
  # lapsstory has too long utts for a flat start so we use a 3x wider beam
  for dataset in constituicao coddef lapsstory ; do
    (
      extra_train_opts= && extra_ali_opts= && [ $dataset == lapsstory ] && \
        extra_ali_opts="--beam 30 --retry-beam 120" && \
        extra_train_opts="--initial-beam 18 --regular-beam 40 --retry-beam 120"
      njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
        njobs=$(wc -l < data/train_$dataset/spk2utt)
      prf steps/train_mono.sh --boost-silence 1.25 --nj $njobs --cmd "$train_cmd" "$extra_train_opts" \
        data/train_$dataset data/lang_nosp exp/mono_$dataset || touch .merr
      prf steps/align_si.sh --boost-silence 1.25 --nj $njobs --cmd "$train_cmd" "$extra_ali_opts" \
        data/train_$dataset data/lang_nosp exp/mono_$dataset exp/mono_ali_train_$dataset || touch .merr
    )&
    sleep 1
  done
  [ -f .merr ] && rm .merr && exit 1
  wait
  for dataset in cetuc spoltech westpoint coraa cv vf mls mtedx all ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
      njobs=$(wc -l < data/train_$dataset/spk2utt)
    prf steps/train_mono.sh --boost-silence 1.25 --nj $njobs --cmd "$train_cmd" \
      data/train_$dataset data/lang_nosp exp/mono_$dataset || exit 1
    prf steps/align_si.sh --boost-silence 1.25 --nj $njobs --cmd "$train_cmd" \
      data/train_$dataset data/lang_nosp exp/mono_$dataset exp/mono_ali_train_$dataset || exit 1
  done
fi

# train a first delta + delta-delta triphone system on all utterances
# TODO use data from larger subsets 
if [ $stage -le 1 ]; then
  msg "$0: train deltas"
  for dataset in constituicao coddef lapsstory ; do
    (
      njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
        njobs=$(wc -l < data/train_$dataset/spk2utt)
      prf steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
        2000 10000 data/train_$dataset data/lang_nosp exp/mono_ali_train_$dataset exp/tri1_$dataset || touch .derr
      prf steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
        data/train_$dataset data/lang_nosp exp/tri1_$dataset exp/tri1_ali_train_$dataset || touch .derr
    )&
    sleep 1
  done
  [ -f .derr ] && rm .derr && exit 1
  wait
  for dataset in cetuc spoltech westpoint coraa cv vf mls mtedx all ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
      njobs=$(wc -l < data/train_$dataset/spk2utt)
    prf steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
      2000 10000 data/train_$dataset data/lang_nosp exp/mono_ali_train_$dataset exp/tri1_$dataset || exit 1
    prf steps/align_si.sh --nj $njobs --cmd "$train_cmd" \
      data/train_$dataset data/lang_nosp exp/tri1_$dataset exp/tri1_ali_train_$dataset || exit 1
  done
fi

# train an LDA+MLLT system.
if [ $stage -le 2 ]; then
  msg "$0: train lda mllt"
  for dataset in constituicao coddef lapsstory ; do
    (
      njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
        njobs=$(wc -l < data/train_$dataset/spk2utt)
      prf steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
        data/train_$dataset data/lang_nosp exp/tri1_ali_train_$dataset exp/tri2b_$dataset || touch .lerr
      prf steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
        data/train_$dataset data/lang_nosp exp/tri2b_$dataset exp/tri2b_ali_train_$dataset || touch .lerr
    )&
    sleep 1
  done
  [ -f .lerr ] && rm .lerr && exit 1
  wait
  for dataset in cetuc spoltech westpoint coraa cv vf mls mtedx all ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
      njobs=$(wc -l < data/train_$dataset/spk2utt)
    prf steps/train_lda_mllt.sh --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
      data/train_$dataset data/lang_nosp exp/tri1_ali_train_$dataset exp/tri2b_$dataset || exit 1
    prf steps/align_si.sh --nj $njobs --cmd "$train_cmd" --use-graphs true \
      data/train_$dataset data/lang_nosp exp/tri2b_$dataset exp/tri2b_ali_train_$dataset || exit 1
  done
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 3 ]; then
  msg "$0: train sat"
  for dataset in constituicao coddef lapsstory ; do
    (
      prf steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
        data/train_$dataset data/lang_nosp exp/tri2b_ali_train_$dataset exp/tri3b_$dataset || touch .serr
    )&
    sleep 1
  done
  [ -f .serr ] && rm .serr && exit 1
  wait
  for dataset in cetuc spoltech westpoint coraa cv vf mls mtedx all ; do
    prf steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
      data/train_$dataset data/lang_nosp exp/tri2b_ali_train_$dataset exp/tri3b_$dataset || exit 1
  done
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 4 ]; then
  msg "$0: add silence and pronunciation probabilities (sp)"
  for dataset in cetuc coddef constituicao lapsstory spoltech westpoint coraa cv vf mls mtedx all ; do
    prf steps/get_prons.sh --cmd "$train_cmd" \
      data/train_$dataset data/lang_nosp exp/tri3b_$dataset

    prf utils/dict_dir_add_pronprobs.sh --max-normalize true \
      data/local/dict_nosp \
      exp/tri3b_$dataset/pron_counts_nowb.txt \
      exp/tri3b_$dataset/sil_counts_nowb.txt \
      exp/tri3b_$dataset/pron_bigram_counts_nowb.txt \
      data/local/dict_$dataset

    prf utils/prepare_lang.sh \
      data/local/dict_$dataset "<UNK>" data/local/lang_tmp data/lang_$dataset

    symtab=data/lang_test_small/words.txt
    if [ -f data/lang_test_${dataset}_small/G.fst ] ; then
      echo "$0: warn: G.fst exists. skipping compilation..."
    else
      cp -r data/lang data/lang_test_${dataset}_small
      gunzip -c data/local/lm/small.arpa.gz | \
        sed "s/<unk>/<UNK>/g" | \
        arpa2fst \
          --disambig-symbol=#0 \
          --read-symbol-table=$symtab \
          - data/lang_test_${dataset}_small/G.fst || exit 1
    fi
    utils/validate_lang.pl --skip-determinization-check \
      data/lang_test_${dataset}_small || exit 1

    ## TODO uncomment for real recipe
    ## FIXME -L untested
    ## NOTE carpa generation consumes a lot of RAM
    #if [ -L data/local/lm/large.arpa.gz ] ; then
    #  symtab=data/lang_test_large/words.txt
    #  if [ -f data/lang_test_large/G.carpa ] ; then
    #    echo "$0: warn: G.carpa exists. skipping compilation..."
    #  else
    #    cp -r data/lang data/lang_test_large
    #    gunzip -c data/local/lm/large.arpa.gz | \
    #      sed "s/<unk>/<UNK>/g" | utils/map_arpa_lm.pl $symtab | \
    #      arpa-to-const-arpa \
    #        --bos-symbol=$(grep "^<s>\s"  $symtab | awk '{print $2}') \
    #        --eos-symbol=$(grep "^</s>\s" $symtab | awk '{print $2}') \
    #        --unk-symbol=$(grep "<UNK>\s" $symtab | awk '{print $2}') \
    #        - data/lang_test_large/G.carpa || exit 1
    #  fi
    #  # TODO no validate_lang??
    #fi

    njobs=$nj && [ $njobs -gt $(wc -l < data/train_$dataset/spk2utt) ] && \
      njobs=$(wc -l < data/train_$dataset/spk2utt)
    (
      prf steps/align_fmllr.sh --nj $njobs --cmd "$train_cmd" \
        data/train_$dataset data/lang_$dataset exp/tri3b_$dataset exp/tri3b_ali_train_$dataset || touch .aerr
    )&
    sleep 1
    [ -f .aerr ] && rm .aerr && exit 1
    [ $njobs -ge $nj ] && wait
  done
fi

# Test the tri3b system with the silprobs and pron-probs.
# NOTE: all decoding routines have been moved to run_decode.sh.
#       we only create the graph that's needed for DNN training
if [ $stage -le 5 ]; then
  msg "$0: generating tri-sat graph (with sil probs)"
  prf utils/mkgraph.sh \
    data/lang_test_all_small exp/tri3b_all exp/tri3b_all/graph_small
fi

msg "$0: success!"
