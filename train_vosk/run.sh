#!/usr/bin/env bash
#
# adapted from kaldi/egs/mini_librispeech/s5/run.sh (fa95730be)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/ (comments signed as CB)
# last updated: mar 2021

# Change this location to somewhere where you want to put the data.
data=./corpus/

decode=false    # perform decode for each model?
decode_bg=false # throw decoding processes to background?

# These variables are preset in case you are running the demo to train with
# LapsBM dataset and default phonetic dict and language model from FalaBrasil.
# You may leave these variables as they are even if you wish to use your own 
# data, however in this case you need to set the following group of 
# variables '*_dir'
data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lex_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lexicon.utf8.dict.gz
lm_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lm.3gram.arpa.gz
#nlp_dir=$HOME/fb-gitlab/fb-nlp/nlp-generator/ # TODO CB: deploy heroku java server?

# set this up if you want to run with your own data.
# then execute this script as follows:
# $./run.sh \
#       --audio-dir      DATA_DIR \
#       --lex-file       LEX-FILE \
#       --lm-file-small  LM-FILE-1st-PASS \
#       --lm-file-medium LM-FILE-2nd-PASS \
#       --lm-file-large  LM-FILE-2nd-PASS-CARPA  (???)
audio_dir=
lex_file=
lm_file_small=
lm_file_medium=  # FIXME not implemented
lm_file_large=   # FIXME not implemented

. ./cmd.sh
. ./path.sh

stage=-1
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data

if [ $stage -le -1 ]; then
  s_time=$(date +'%F_%T')
  if [ -z "$audio_dir" ] ; then
    echo "[$(date +'%F %T')] $0: downloading LapsBM data (85M)" | lolcat
    fblocal/download_data.sh $data $data_url || exit 1
  else
    echo "[$(date +'%F %T')] $0: gathering data from '$audio_dir'" | lolcat
    fblocal/link_local_data.sh --nj 12 $audio_dir $data || exit 1
  fi
  e_time=$(date +'%F_%T')
  echo "$0 -1: setting up audio dir took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

if [ $stage -le 0 ]; then
  s_time=$(date +'%F_%T')
  if [ -z "$lex_file" ] ; then
    echo "[$(date +'%F %T')] $0: downloading dict from FalaBrasil GitLab" | lolcat
    fblocal/download_lexicon.sh $data $lex_url data/local/dict_nosp/ || exit 1
  else
    echo "[$(date +'%F %T')] $0: copying lexicon from '$lex_file'" | lolcat
    cp -v $lex_file $data || exit 1
    gzip -cd $data/$(basename $lex_file) > data/local/dict_nosp/lexicon.txt || exit 1
  fi
  e_time=$(date +'%F_%T')
  echo "$0 0: downloading lexicon took $(fbutils/elapsed_time.py $s_time $e_time)"

  s_time=$(date +'%F_%T')
  if [ -z "$lm_file_small" ] ; then
    echo "[$(date +'%F %T')] $0: downloading LM from FalaBrasil GitLab" | lolcat
    fblocal/download_lm.sh $data $lm_url data/local/lm/ || exit 1
  else
    echo "[$(date +'%F %T')] $0: copying LM small from '$lex_file'" | lolcat
    cp -v $lm_file_small $data || exit 1
    ln -rsf $data/$(basename $lm_file_small) $link_dir/lm_tglarge.arpa.gz || exit 1
  fi
  e_time=$(date +'%F_%T')
  echo "$0 0: downloading LM took $(fbutils/elapsed_time.py $s_time $e_time)"

  # TODO
  if [ ! -z "$lm_file_medium" ] ; then
    echo "TBD"
  fi

  # TODO
  if [ ! -z "$lm_file_large" ] ; then
    echo "TBD"
  fi
fi

if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  echo "[$(date +'%F %T')] $0: prep data" | lolcat
  s_time=$(date +'%F_%T')
  fblocal/prep_data.sh --nj 12 --split-random true $data data/
  #fblocal/prep_data.sh --nj 8 --test-dir lapsbm16k $data ./data
  e_time=$(date +'%F_%T')
  echo "$0 1: prep data took $(fbutils/elapsed_time.py $s_time $e_time)"

  # CB: stage 3 doesn't need local/lm dir
  echo "[$(date +'%F %T')] $0: prep dict" | lolcat 
  s_time=$(date +'%F_%T')
  fblocal/prep_dict.sh --nj 12 data/local/dict_nosp/
  e_time=$(date +'%F_%T')
  echo "$0 1: prep dict took $(fbutils/elapsed_time.py $s_time $e_time)"

  # CB: leave as it is
  echo "[$(date +'%F %T')] $0: prep lang" | lolcat
  s_time=$(date +'%F_%T')
  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp/ data/lang_nosp/
  e_time=$(date +'%F_%T')
  echo "$0 1: prep lang took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: format lms" | lolcat
  s_time=$(date +'%F_%T')
  fblocal/format_lms.sh --src-dir data/lang_nosp data/local/lm
  e_time=$(date +'%F_%T')
  echo "$0 1: format lms took $(fbutils/elapsed_time.py $s_time $e_time)"

  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  echo "[$(date +'%F %T')] $0: build const arpa" | lolcat
  s_time=$(date +'%F_%T')
  utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
    data/lang_nosp/ data/lang_nosp_test/
  e_time=$(date +'%F_%T')
  echo "$0 1: build const arpa took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

if [ $stage -le 2 ]; then
  mfccdir=mfcc
  echo "[$(date +'%F %T')] $0: compute mfcc and cmvn" | lolcat
  s_time=$(date +'%F_%T')
  for part in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 12 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
  e_time=$(date +'%F_%T')
  echo "$0 2: compute mfccs took $(fbutils/elapsed_time.py $s_time $e_time)"

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  # CB: change to 250 for LapsBM
  echo "[$(date +'%F %T')] $0: subset data dir" | lolcat
  s_time=$(date +'%F_%T')
  utils/subset_data_dir.sh --shortest data/train 500 data/train_500short
  e_time=$(date +'%F_%T')
  echo "$0 2: subset data dir took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

# train a monophone system
s_time=$(date +'%F_%T')
if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  echo "[$(date +'%F %T')] $0: train mono" | lolcat
  s_time=$(date +'%F_%T')
  steps/train_mono.sh --boost-silence 1.25 --nj 12 --cmd "$train_cmd" \
    data/train_500short data/lang_nosp exp/mono
  e_time=$(date +'%F_%T')
  echo "$0 3: train mono took $(fbutils/elapsed_time.py $s_time $e_time)"

  if $decode ; then
    # TODO: Understand why we use lang_nosp here...
    (
      echo "[$(date +'%F %T')] $0: generating mono graph" | lolcat
      s_time=$(date +'%F_%T')
      utils/mkgraph.sh data/lang_nosp_test_tgsmall \
        exp/mono exp/mono/graph_nosp_tgsmall
      e_time=$(date +'%F_%T')
      echo "$0 3: mkgraph mono took $(fbutils/elapsed_time.py $s_time $e_time)"

      echo "[$(date +'%F %T')] $0: decoding mono" | lolcat
      s_time=$(date +'%F_%T')
      steps/decode.sh --nj 12 --cmd "$decode_cmd" exp/mono/graph_nosp_tgsmall \
        data/test exp/mono/decode_nosp_tgsmall_test
      grep -Rn WER exp/mono/decode_nosp_tgsmall_test | \
          utils/best_wer.sh  > exp/mono/decode_nosp_tgsmall_test/fbwer.txt
      e_time=$(date +'%F_%T')
      echo "$0 3: decoding mono took $(fbutils/elapsed_time.py $s_time $e_time)"
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align mono" | lolcat
  s_time=$(date +'%F_%T')
  steps/align_si.sh --boost-silence 1.25 --nj 12 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono exp/mono_ali_train
  e_time=$(date +'%F_%T')
  echo "$0 3: align mono took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  echo "[$(date +'%F %T')] $0: train deltas" | lolcat
  s_time=$(date +'%F_%T')
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train data/lang_nosp exp/mono_ali_train exp/tri1
  e_time=$(date +'%F_%T')
  echo "$0 4: train deltas took $(fbutils/elapsed_time.py $s_time $e_time)"

  # decode using the tri1 model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating tri deltas graph" | lolcat
      s_time=$(date +'%F_%T')
      utils/mkgraph.sh data/lang_nosp_test_tgsmall \
        exp/tri1 exp/tri1/graph_nosp_tgsmall
      e_time=$(date +'%F_%T')
      echo "$0 4: mkgraph deltas took $(fbutils/elapsed_time.py $s_time $e_time)"

      echo "[$(date +'%F %T')] $0: decoding deltas" | lolcat
      s_time=$(date +'%F_%T')
      steps/decode.sh --nj 12 --cmd "$decode_cmd" exp/tri1/graph_nosp_tgsmall \
        data/test exp/tri1/decode_nosp_tgsmall_test
      grep -Rn WER exp/tri1/decode_nosp_tgsmall_test | \
          utils/best_wer.sh > exp/tri1/decode_nosp_tgsmall_test/fbwer.txt
      e_time=$(date +'%F_%T')
      echo "$0 4: decoding deltas took $(fbutils/elapsed_time.py $s_time $e_time)"
      ## CB: we don't have a huge LM to do rescoring yet
      #s_time=$(date +'%F_%T')
      #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      #  data/test exp/tri1/decode_nosp_{tgsmall,tgmed}_test
      #e_time=$(date +'%F_%T')
      #echo "$0 4: rescoring deltas took $(fbutils/elapsed_time.py $s_time $e_time)"
      #s_time=$(date +'%F_%T')
      #steps/lmrescore_const_arpa.sh \
      #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      #  data/test exp/tri1/decode_nosp_{tgsmall,tglarge}_test
      #e_time=$(date +'%F_%T')
      #echo "$0 4: rescoring carpa deltas took $(fbutils/elapsed_time.py $s_time $e_time)"
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  echo "[$(date +'%F %T')] $0: align deltas" | lolcat
  s_time=$(date +'%F_%T')
  steps/align_si.sh --nj 12 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri1 exp/tri1_ali_train
  e_time=$(date +'%F_%T')
  echo "$0 4: align deltas took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

# train an LDA+MLLT system.
if [ $stage -le 5 ]; then
  echo "[$(date +'%F %T')] $0: train lda mllt" | lolcat
  s_time=$(date +'%F_%T')
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train data/lang_nosp exp/tri1_ali_train exp/tri2b
  e_time=$(date +'%F_%T')
  echo "$0 5: train lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"

  # decode using the LDA+MLLT model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating lda mllt graph" | lolcat
      s_time=$(date +'%F_%T')
      utils/mkgraph.sh data/lang_nosp_test_tgsmall \
        exp/tri2b exp/tri2b/graph_nosp_tgsmall
      e_time=$(date +'%F_%T')
      echo "$0 5: mkgraph lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"

      echo "[$(date +'%F %T')] $0: decoding lda mllt" | lolcat
      s_time=$(date +'%F_%T')
      steps/decode.sh --nj 12 --cmd "$decode_cmd" exp/tri2b/graph_nosp_tgsmall \
        data/test exp/tri2b/decode_nosp_tgsmall_test
      grep -Rn WER exp/tri2b/decode_nosp_tgsmall_test | \
          utils/best_wer.sh > exp/tri2b/decode_nosp_tgsmall_test/fbwer.txt
      e_time=$(date +'%F_%T')
      echo "$0 5: decoding lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"
      ## CB: we don't have a huge LM to do rescoring yet
      #s_time=$(date +'%F_%T')
      #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      #  data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 5: rescoring lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"
      #s_time=$(date +'%F_%T')
      #steps/lmrescore_const_arpa.sh \
      #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      #  data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 5: rescoring carpa lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi

  # Align utts using the tri2b model
  echo "[$(date +'%F %T')] $0: align lda mllt" | lolcat
  s_time=$(date +'%F_%T')
  steps/align_si.sh --nj 12 --cmd "$train_cmd" --use-graphs true \
    data/train data/lang_nosp exp/tri2b exp/tri2b_ali_train
  e_time=$(date +'%F_%T')
  echo "$0 5: align lda mllt took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

# Train tri3b, which is LDA+MLLT+SAT
s_time=$(date +'%F_%T')
if [ $stage -le 6 ]; then
  echo "[$(date +'%F %T')] $0: train sat" | lolcat
  s_time=$(date +'%F_%T')
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b
  e_time=$(date +'%F_%T')
  echo "$0 6: train sat nosp took $(fbutils/elapsed_time.py $s_time $e_time)"

  # decode using the tri3b model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating sat graph (nosp)" | lolcat
      s_time=$(date +'%F_%T')
      utils/mkgraph.sh data/lang_nosp_test_tgsmall \
        exp/tri3b exp/tri3b/graph_nosp_tgsmall
      e_time=$(date +'%F_%T')
      echo "$0 6: mkgraph sat nosp took $(fbutils/elapsed_time.py $s_time $e_time)"

      echo "[$(date +'%F %T')] $0: decoding sat (nosp)" | lolcat
      s_time=$(date +'%F_%T')
      steps/decode_fmllr.sh --nj 12 --cmd "$decode_cmd" \
        exp/tri3b/graph_nosp_tgsmall data/test \
        exp/tri3b/decode_nosp_tgsmall_test
      grep -Rn WER exp/tri3b/decode_nosp_tgsmall_test | \
          utils/best_wer.sh > exp/tri3b/decode_nosp_tgsmall_test/fbwer.txt
      e_time=$(date +'%F_%T')
      echo "$0 6: decoding sat nosp took $(fbutils/elapsed_time.py $s_time $e_time)"

      ## CB: we don't have a huge LM to do rescoring yet
      #s_time=$(date +'%F_%T')
      #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
      #  data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 6: rescoring sat nosp took $(fbutils/elapsed_time.py $s_time $e_time)"
      #s_time=$(date +'%F_%T')
      #steps/lmrescore_const_arpa.sh \
      #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
      #  data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 6: rescore sat carpa nosp took $(fbutils/elapsed_time.py $s_time $e_time)"
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 7 ]; then
  echo "[$(date +'%F %T')] $0: get prons" | lolcat
  s_time=$(date +'%F_%T')
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b
  e_time=$(date +'%F_%T')
  echo "$0 7: get prons took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: dict add pron probs" | lolcat
  s_time=$(date +'%F_%T')
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict
  e_time=$(date +'%F_%T')
  echo "$0 7: add pp to dict took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: prep lang" | lolcat
  s_time=$(date +'%F_%T')
  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang
  e_time=$(date +'%F_%T')
  echo "$0 7: prepare lang took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: format lm" | lolcat
  s_time=$(date +'%F_%T')
  fblocal/format_lms.sh --src-dir data/lang data/local/lm
  e_time=$(date +'%F_%T')
  echo "$0 7: format lms took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: build const arpa" | lolcat
  s_time=$(date +'%F_%T')
  utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
      data/lang data/lang_test_tglarge
  e_time=$(date +'%F_%T')
  echo "$0 7: build carpa took $(fbutils/elapsed_time.py $s_time $e_time)"

  echo "[$(date +'%F %T')] $0: align fmllr" | lolcat
  s_time=$(date +'%F_%T')
  steps/align_fmllr.sh --nj 12 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
  e_time=$(date +'%F_%T')
  echo "$0 7: align sat sp took $(fbutils/elapsed_time.py $s_time $e_time)"
fi

# Test the tri3b system with the silprobs and pron-probs.
if [ $stage -le 8 ]; then
  # decode using the tri3b model
  if $decode ; then
    (
      echo "[$(date +'%F %T')] $0: generating sat graph (with sil probs)" | lolcat
      s_time=$(date +'%F_%T')
      utils/mkgraph.sh data/lang_test_tgsmall \
                       exp/tri3b exp/tri3b/graph_tgsmall
      e_time=$(date +'%F_%T')
      echo "$0 8: mkgraph sat sp took $(fbutils/elapsed_time.py $s_time $e_time)"

      echo "[$(date +'%F %T')] $0: decoding sat (with sil probs)" | lolcat
      s_time=$(date +'%F_%T')
      steps/decode_fmllr.sh --nj 12 --cmd "$decode_cmd" \
                            exp/tri3b/graph_tgsmall data/test \
                            exp/tri3b/decode_tgsmall_test
      grep -Rn WER exp/tri3b/decode_tgsmall_test | \
          utils/best_wer.sh > exp/tri3b/decode_tgsmall_test/fbwer.txt
      e_time=$(date +'%F_%T')
      echo "$0 8: decode sat sp took $(fbutils/elapsed_time.py $s_time $e_time)"
      ## CB: we don't have a huge LM to do rescoring yet
      #s_time=$(date +'%F_%T')
      #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      #                   data/$test exp/tri3b/decode_{tgsmall,tgmed}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 8: rescore sat sp took $(fbutils/elapsed_time.py $s_time $e_time)"
      #s_time=$(date +'%F_%T')
      #steps/lmrescore_const_arpa.sh \
      #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      #  data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
      #e_time=$(date +'%F_%T')
      #echo "$0 8: rescore carpa sat sp took $(fbutils/elapsed_time.py $s_time $e_time)"
    )&
    $decode_bg || { echo "NOTE: mkgraph takes a while" && wait; }
  fi
fi

# Train a chain model
# FIXME CB: beware the number of epochs reduced by a half, original is 20.
#       I reduced it for things to run faster while debugging.
# NOTE: CB: if you do not have an NVIDIA card, then set use-gpu to
#       'false', jobs initial to 2 and jobs final to 4. OTOH, if you
#       have multiple NVIDIA GPUs, then you might want to increase the
#       number of jobs final accordingly
if [ $stage -le 9 ]; then
  echo "[$(date +'%F %T')] $0: run TDNN script" | lolcat
  fblocal/chain/run_tdnn.sh --use-gpu true \
      --jobs-initial 1 --jobs-final 1 --num-epochs 20
fi

# local/grammar/simple_demo.sh

# Don't finish until all background decoding jobs are finished.
wait

# https://superuser.com/questions/294161/unix-linux-find-and-sort-by-date-modified
find -name fbwer.txt -printf "%T@ %Tc %p\n" | sort -n | awk '{print $NF}' | xargs cat
