#!/usr/bin/env bash
#
# author: dec 2020
# cassio batista

decode_bg=false

train_set=train  # CB: changed
gmm=tri3b
nnet3_affix=_online_cmn
affix=1k   # affix for the TDNN directory name
tree_affix=

gmm_dir=exp/$gmm
ali_dir=exp/${gmm}_ali_${train_set}_sp
tree_dir=exp/chain${nnet3_affix}/tree_sp${tree_affix:+_$tree_affix}
lang=data/lang_chain
lat_dir=exp/chain${nnet3_affix}/${gmm}_${train_set}_sp_lats
dir=exp/chain${nnet3_affix}/tdnn${affix}_sp
train_data_dir=data/${train_set}_sp_hires
lores_train_data_dir=data/${train_set}_sp
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

set -euo pipefail

(
  echo "[$(date +'%F %T')] $0: generating mono graph" | lolcat
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/mono exp/mono/graph_nosp_tgsmall
  echo "[$(date +'%F %T')] $0: decoding mono" | lolcat
  steps/decode.sh --nj 6 --cmd "$decode_cmd" \
    exp/mono/graph_nosp_tgsmall \
    data/test \
    exp/mono/decode_nosp_tgsmall_test
  grep -Rn WER exp/mono/decode_nosp_tgsmall_test | \
      utils/best_wer.sh  > exp/mono/decode_nosp_tgsmall_test/fbwer.txt
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: generating tri deltas graph" | lolcat
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri1 exp/tri1/graph_nosp_tgsmall
  echo "[$(date +'%F %T')] $0: decoding deltas" | lolcat
  steps/decode.sh --nj 6 --cmd "$decode_cmd" \
    exp/tri1/graph_nosp_tgsmall \
    data/test \
    exp/tri1/decode_nosp_tgsmall_test
  grep -Rn WER exp/tri1/decode_nosp_tgsmall_test | \
      utils/best_wer.sh > exp/tri1/decode_nosp_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #  data/test exp/tri1/decode_nosp_{tgsmall,tgmed}_test
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #  data/test exp/tri1/decode_nosp_{tgsmall,tglarge}_test
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: generating lda mllt graph" | lolcat
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri2b exp/tri2b/graph_nosp_tgsmall
  echo "[$(date +'%F %T')] $0: decoding lda mllt" | lolcat
  steps/decode.sh --nj 6 --cmd "$decode_cmd" \
    exp/tri2b/graph_nosp_tgsmall \
    data/test \
    exp/tri2b/decode_nosp_tgsmall_test
  grep -Rn WER exp/tri2b/decode_nosp_tgsmall_test | \
      utils/best_wer.sh > exp/tri2b/decode_nosp_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #  data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #  data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: generating sat graph (nosp)" | lolcat
  utils/mkgraph.sh data/lang_nosp_test_tgsmall \
    exp/tri3b exp/tri3b/graph_nosp_tgsmall
  echo "[$(date +'%F %T')] $0: decoding sat (nosp)" | lolcat
  steps/decode_fmllr.sh --nj 6 --cmd "$decode_cmd" \
    exp/tri3b/graph_nosp_tgsmall \
    data/test \
    exp/tri3b/decode_nosp_tgsmall_test
  grep -Rn WER exp/tri3b/decode_nosp_tgsmall_test | \
      utils/best_wer.sh > exp/tri3b/decode_nosp_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
  #  data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
  #  data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: generating sat graph (with sil probs)" | lolcat
  utils/mkgraph.sh data/lang_test_tgsmall \
                   exp/tri3b exp/tri3b/graph_tgsmall
  echo "[$(date +'%F %T')] $0: decoding sat (with sil probs)" | lolcat
  steps/decode_fmllr.sh --nj 6 --cmd "$decode_cmd" \
    exp/tri3b/graph_tgsmall \
    data/test \
    exp/tri3b/decode_tgsmall_test
  grep -Rn WER exp/tri3b/decode_tgsmall_test | \
      utils/best_wer.sh > exp/tri3b/decode_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
  #                   data/$test exp/tri3b/decode_{tgsmall,tgmed}_$test
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
  #  data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: decoding dnn" | lolcat
  steps/nnet3/decode.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --frames-per-chunk $frames_per_chunk \
    --nj 6 --cmd "$decode_cmd" --num-threads 2 \
    --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_test_hires \
    $tree_dir/graph_tgsmall \
    data/test_hires \
    ${dir}/decode_tgsmall_test || exit 1
  grep -Rn WER $dir/decode_tgsmall_test | \
      utils/best_wer.sh > $dir/decode_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
  #  data/lang_test_{tgsmall,tglarge} \
  # data/${data}_hires ${dir}/decode_{tgsmall,tglarge}_${data} || exit 1
)&
$decode_bg || wait

(
  echo "[$(date +'%F %T')] $0: prepare online decoding" | lolcat
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc_hires.conf \
    --online-cmvn-config conf/online_cmvn.conf \
    $lang \
    exp/nnet3${nnet3_affix}/extractor \
    ${dir} \
    ${dir}_online

  echo "[$(date +'%F %T')] $0: online decode" | lolcat
  # note: we just give it "data/${data}" as it only uses the wav.scp, the
  # feature type does not matter.
  steps/online/nnet3/decode.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 6 --cmd "$decode_cmd" \
    $tree_dir/graph_tgsmall \
    data/test \
    ${dir}_online/decode_tgsmall_test || exit 1
  grep -Rn WER ${dir}_online/decode_tgsmall_test | \
      utils/best_wer.sh > ${dir}_online/decode_tgsmall_test/fbwer.txt
  ## CB: we don't have a huge LM to do rescoring yet
  #steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
  #  data/lang_test_{tgsmall,tglarge} \
  #  data/${data}_hires ${dir}_online/decode_{tgsmall,tglarge}_${data} || exit 1
)&
$decode_bg || wait

# https://superuser.com/questions/294161/unix-linux-find-and-sort-by-date-modified
find -name fbwer.txt -printf "%T@ %Tc %p\n" | sort -n | awk '{print $NF}' | xargs cat
