#!/usr/bin/env bash

fb_num_epochs=4
decode=true

# NOTE: same as local/nnet3/tuning/run_tdnn_1c.sh -- CB

# 1c is as 1b, but uses more modern TDNN configuration.

# local/nnet3/compare_wer.sh exp/nnet3_cleaned/tdnn_sp exp/nnet3_cleaned/tdnn_1c_sp
# System                        tdnn_sp tdnn_1c_sp
# WER on dev(fglarge)              4.52      4.20
# WER on dev(tglarge)              4.80      4.37
# WER on dev(tgmed)                6.02      5.31
# WER on dev(tgsmall)              6.80      5.86
# WER on dev_other(fglarge)       12.54     12.55
# WER on dev_other(tglarge)       13.16     13.00
# WER on dev_other(tgmed)         15.51     14.98
# WER on dev_other(tgsmall)       17.12     15.88
# WER on test(fglarge)             5.00      4.91
# WER on test(tglarge)             5.22      4.99
# WER on test(tgmed)               6.40      5.93
# WER on test(tgsmall)             7.14      6.49
# WER on test_other(fglarge)      12.56     12.94
# WER on test_other(tglarge)      13.04     13.38
# WER on test_other(tgmed)        15.58     15.11
# WER on test_other(tgsmall)      16.88     16.28
# Final train prob               0.7180    0.8509
# Final valid prob               0.7003    0.8157
# Final train prob (logLL)      -0.9483   -0.4294
# Final valid prob (logLL)      -0.9963   -0.5662
# Num-parameters               19268504  18391704

# steps/info/nnet3_dir_info.pl exp/nnet3_cleaned/tdnn_sp
# exp/nnet3_cleaned/tdnn_1c_sp: num-iters=1088 nj=3..16 num-params=18.4M dim=40+100->5784 combine=-0.43->-0.43 (over 4) loglike:train/valid[723,1087,combined]=(-0.48,-0.43,-0.43/-0.58,-0.57,-0.57) accuracy:train/valid[723,1087,combined]=(0.840,0.854,0.851/0.811,0.816,0.816)

# this is the standard "tdnn" system, built in nnet3; it's what we use to
# call multi-splice.

# without cleanup:
# local/nnet3/run_tdnn.sh  --train-set train960 --gmm tri6b --nnet3-affix "" &


# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call train_tdnn.sh with --gpu false,
# --num-threads 16 and --minibatch-size 128.

# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).


set -e

stage=0
train_set=train #train_960_cleaned
gmm=mono #tri6b_cleaned  # this is the source gmm-dir for the data-type of interest; it
                   # should have alignments for the specified training data.
#nnet3_affix=_cleaned
nnet3_affix=

# Options which are not passed through to run_ivector_common.sh
affix=mono_nochain_delta_ivector
train_stage=-10
common_egs_dir=
reporting_email=
remove_egs=true

. ./cmd.sh
. ./path.sh
. ./fb_commons.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

#local/nnet3/run_ivector_common.sh --stage $stage \
#                                  --train-set $train_set \
#                                  --gmm $gmm \
#                                  --nnet3-affix "$nnet3_affix" || exit 1;

gmm_dir=exp/${gmm}
graph_dir=$gmm_dir/graph_tgsmall
ali_dir=exp/${gmm}_ali_${train_set}_sp
dir=exp/nnet3${nnet3_affix}/tdnn${affix:+_$affix}_sp
train_data_dir=data/${train_set}_sp_hires
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
     $graph_dir/HCLG.fst $ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 11 ]; then
  echo "$0: creating neural net configs";

  num_targets=$(tree-info $ali_dir/tree |grep num-pdfs|awk '{print $2}')

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input
  #fixed-affine-layer name=lda input=Append(-2,-1,0,1,2,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # this takes the MFCCs and generates filterbank coefficients.  The MFCCs
  # are more compressible so we prefer to dump the MFCCs to disk rather
  # than filterbanks.
  idct-layer name=idct input=input dim=40 cepstral-lifter=22 affine-transform-file=$dir/configs/idct.mat
  batchnorm-component name=batchnorm0 input=idct
  spec-augment-layer name=spec-augment freq-max-proportion=0.5 time-zeroed-proportion=0.2 time-mask-max-frames=20

  delta-layer name=delta input=spec-augment
  no-op-component name=input2 input=Append(delta, Scale(0.4, ReplaceIndex(ivector, t, 0)))

  relu-batchnorm-dropout-layer name=tdnn1 $affine_opts dim=1536 input=input2
  tdnnf-layer name=tdnnf2 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=1
  tdnnf-layer name=tdnnf3 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=1
  tdnnf-layer name=tdnnf4 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=1
  tdnnf-layer name=tdnnf5 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=0
  tdnnf-layer name=tdnnf6 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf7 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  tdnnf-layer name=tdnnf8 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf9 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf10 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf11 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf12 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf13 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf14 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf15 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf16 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  #tdnnf-layer name=tdnnf17 $tdnnf_opts dim=1536 bottleneck-dim=160 time-stride=3
  linear-component name=prefinal-l dim=256 $linear_opts

  prefinal-layer name=prefinal input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output input=prefinal dim=$num_targets max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs || exit 1;
fi

if [ $stage -le 12 ]; then

  steps/nnet3/train_dnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.num-epochs $fb_num_epochs \
    --trainer.optimization.num-jobs-initial 1 \
    --trainer.optimization.num-jobs-final 1 \
    --trainer.optimization.initial-effective-lrate 0.0017 \
    --trainer.optimization.final-effective-lrate 0.00017 \
    --egs.dir "$common_egs_dir" \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval 100 \
    --feat-dir=$train_data_dir \
    --ali-dir $ali_dir \
    --lang data/lang \
    --reporting.email="$reporting_email" \
    --dir=$dir  || exit 1;

fi

if $decode && [ $stage -le 13 ]; then
  # this does offline decoding that should give about the same results as the
  # real online decoding (the one with --per-utt true)
  rm $dir/.error 2>/dev/null || true
    steps/nnet3/decode.sh --nj 10 --cmd "$decode_cmd" \
      --scoring-opts "--word-ins-penalty 0.0 --min-lmwt 8 --max-lmwt 9" \
      --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_test_hires \
      ${graph_dir} data/test_hires $dir/decode_test_tgsmall || exit 1
  grep -Rw WER $dir/decode_test_tgsmall | utils/best_wer.sh
    #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
    #  data/${test}_hires $dir/decode_${test}_{tgsmall,tgmed}  || exit 1
    #steps/lmrescore_const_arpa.sh \
    #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
    #  data/${test}_hires $dir/decode_${test}_{tgsmall,tglarge} || exit 1
    #steps/lmrescore_const_arpa.sh \
    #  --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
    #  data/${test}_hires $dir/decode_${test}_{tgsmall,fglarge} || exit 1
  wait
fi

exit 0;
echo "$0: success!"
