#!/usr/bin/env bash
#
# copied from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/

# Change this location to somewhere where you want to put the data.
data=./corpus/

data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lm_url=https://gitlab.com/fb-asr/fb-asr-resources/kaldi-resources/-/raw/master/lm/lm.arpa
nlp_dir=${HOME}/fb-gitlab/fb-nlp/nlp-generator/

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data

start_time=$(date)

# CB: you may call this script multiple times if you have more than one
#     dataset by changing the url, however you'll have to edit the SHA1
#     key
# CB: however if you have multiple datasets you better comment out this
#     script and call "link_local_data.sh" instead.
echo "[$(date +'%F %T')] $0: download data" | lolcat
fblocal/download_data.sh $data $data_url || exit 1
## TODO CB: verify if data (dir? link?) exists first. it'll run much faster
#fblocal/link_local_data.sh --nj 8 ${HOME}/fb-gitlab/fb-audio-corpora $data || exit 1

if [ $stage -le 0 ]; then
  # CB: args 1 and 2 are swapped from the original
  echo "[$(date +'%F %T')] $0: download lm" | lolcat
  fblocal/download_lm.sh $data $lm_url data/local/lm || exit 1
fi

if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  echo "[$(date +'%F %T')] $0: prep data" | lolcat
  fblocal/prep_data.sh --nj 3 --split-random true $data ./data
  #fblocal/prep_data.sh --nj 8 --test-dir lapsbm16k $data ./data

  # CB: stage 3 doesn't need local/lm dir
  echo "[$(date +'%F %T')] $0: prep dict" | lolcat 
  fblocal/prep_dict.sh --nj 4 $nlp_dir data/local/dict_nosp

  # CB: leave as it is
  echo "[$(date +'%F %T')] $0: prep lang" | lolcat
  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  echo "[$(date +'%F %T')] $0: format lms" | lolcat
  fblocal/format_lms.sh --src-dir data/lang_nosp data/local/lm

  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  echo "[$(date +'%F %T')] $0: build const arpa" | lolcat
  fbutils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa \
    data/lang_nosp data/lang_nosp_test
fi

if [ $stage -le 2 ]; then
  mfccdir=mfcc
  echo "[$(date +'%F %T')] $0: compute mfcc and cmvn" | lolcat
  for part in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  # CB: changed to 250
  echo "[$(date +'%F %T')] $0: subset data dir" | lolcat
  utils/subset_data_dir.sh --shortest data/train 250 data/train_500short
fi

# train a monophone system
if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  echo "[$(date +'%F %T')] $0: train mono" | lolcat
  steps/train_mono.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train_500short data/lang_nosp exp/mono

  # commented -- CB
  ## TODO: Understand why we use lang_nosp here...
  #(
  #  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
  #    exp/mono exp/mono/graph_nosp_tgsmall
  #  for test in dev_clean_2; do
  #    steps/decode.sh --nj 10 --cmd "$decode_cmd" exp/mono/graph_nosp_tgsmall \
  #      data/$test exp/mono/decode_nosp_tgsmall_$test
  #  done
  #)&

  echo "[$(date +'%F %T')] $0: align mono" | lolcat
  steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono exp/mono_ali_train
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  echo "[$(date +'%F %T')] $0: train deltas" | lolcat
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train data/lang_nosp exp/mono_ali_train exp/tri1

  # commented - CB
  ## decode using the tri1 model
  #(
  #  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
  #    exp/tri1 exp/tri1/graph_nosp_tgsmall
  #  for test in dev_clean_2; do
  #    steps/decode.sh --nj 5 --cmd "$decode_cmd" exp/tri1/graph_nosp_tgsmall \
  #    data/$test exp/tri1/decode_nosp_tgsmall_$test
  #    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #      data/$test exp/tri1/decode_nosp_{tgsmall,tgmed}_$test
  #    steps/lmrescore_const_arpa.sh \
  #      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #      data/$test exp/tri1/decode_nosp_{tgsmall,tglarge}_$test
  #  done
  #)&

  echo "[$(date +'%F %T')] $0: align deltas" | lolcat
  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri1 exp/tri1_ali_train
fi

# train an LDA+MLLT system.
if [ $stage -le 5 ]; then
  echo "[$(date +'%F %T')] $0: train lda mllt" | lolcat
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train data/lang_nosp exp/tri1_ali_train exp/tri2b

  # commented -- CB
  ## decode using the LDA+MLLT model
  #(
  #  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
  #    exp/tri2b exp/tri2b/graph_nosp_tgsmall
  #  for test in dev_clean_2; do
  #    steps/decode.sh --nj 10 --cmd "$decode_cmd" exp/tri2b/graph_nosp_tgsmall \
  #      data/$test exp/tri2b/decode_nosp_tgsmall_$test
  #    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #      data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
  #    steps/lmrescore_const_arpa.sh \
  #      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #      data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
  #  done
  #)&

  # Align utts using the tri2b model
  echo "[$(date +'%F %T')] $0: align lda mllt" | lolcat
  steps/align_si.sh  --nj 5 --cmd "$train_cmd" --use-graphs true \
    data/train data/lang_nosp exp/tri2b exp/tri2b_ali_train
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 6 ]; then
  echo "[$(date +'%F %T')] $0: train sat" | lolcat
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b

  # commented -- CB
  ## decode using the tri3b model
  #(
  #  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
  #    exp/tri3b exp/tri3b/graph_nosp_tgsmall
  #  for test in dev_clean_2; do
  #    steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
  #      exp/tri3b/graph_nosp_tgsmall data/$test \
  #      exp/tri3b/decode_nosp_tgsmall_$test
  #    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #      data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
  #    steps/lmrescore_const_arpa.sh \
  #      --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #      data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
  #  done
  #)&
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 7 ]; then
  echo "[$(date +'%F %T')] $0: get prons" | lolcat
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b
  echo "[$(date +'%F %T')] $0: dict add pron probs" | lolcat
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  echo "[$(date +'%F %T')] $0: prep lang" | lolcat
  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  echo "[$(date +'%F %T')] $0: format lm" | lolcat
  fblocal/format_lms.sh --src-dir data/lang data/local/lm

  echo "[$(date +'%F %T')] $0: build const arpa" | lolcat
  fbutils/build_const_arpa_lm.sh \
    data/local/lm/lm_tglarge.arpa data/lang data/lang_test_tglarge

  echo "[$(date +'%F %T')] $0: align fmllr" | lolcat
  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

if [ $stage -le 8 ]; then
  # Test the tri3b system with the silprobs and pron-probs.

  # changed 1st arg -- CB
  # decode using the tri3b model
  echo "[$(date +'%F %T')] $0: creating GMM graph" | lolcat
  utils/mkgraph.sh data/lang_nosp_test \
                   exp/tri3b exp/tri3b/graph_tgsmall
  #for test in test; do
  #  steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
  #                        exp/tri3b/graph_tgsmall data/$test \
  #                        exp/tri3b/decode_tgsmall_$test
  #  steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
  #                     data/$test exp/tri3b/decode_{tgsmall,tgmed}_$test
  #  steps/lmrescore_const_arpa.sh \
  #    --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
  #    data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
  #done
fi

# Train a chain model
# FIXME beware the number of epochs reduced by a quarter, original is 20.
# NOTE  CB: if you have a NVIDIA card, then set use-gpu to 'true', and both
#       jobs initial and final to 1 (if you have only one GPU). For a 
#       regular desktop or cluster you may leave as it is
if [ $stage -le 9 ]; then
  echo "[$(date +'%F %T')] $0: run TDNN script" | lolcat
  fblocal/chain/run_tdnn.sh --use-gpu false \
      --jobs-initial 2 --jobs-final 4 --num-epochs 10
fi

end_time=$(date)

# local/grammar/simple_demo.sh

# Don't finish until all background decoding jobs are finished.
wait
echo "$0: done! started at '$start_time' and finished at '$end_time'" | lolcat
