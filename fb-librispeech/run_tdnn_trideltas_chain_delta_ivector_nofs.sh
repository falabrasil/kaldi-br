#!/usr/bin/env bash

fb_num_epochs=4
decode=true

# NOTE: same as local/chain/run_tdnn.sh -> local/chain/tuning/run_tdnn_1d.sh -- CB

# 1d is as 1c but a recipe based on the newer, more compact configs, and with
#   various configuration changes; it also includes dropout (although I'm not
#   sure whether dropout was actually helpful, that needs to be tested).
#
# local/chain/compare_wer.sh exp/chain_cleaned/tdnn_1c_sp exp/chain_cleaned/tdnn_1d_sp
# System                      tdnn_1c_sp tdnn_1d_sp
# WER on dev(fglarge)              3.31      3.29
# WER on dev(tglarge)              3.41      3.44
# WER on dev(tgmed)                4.30      4.22
# WER on dev(tgsmall)              4.81      4.72
# WER on dev_other(fglarge)        8.73      8.71
# WER on dev_other(tglarge)        9.22      9.05
# WER on dev_other(tgmed)         11.24     11.09
# WER on dev_other(tgsmall)       12.29     12.13
# WER on test(fglarge)             3.88      3.80
# WER on test(tglarge)             4.05      3.89
# WER on test(tgmed)               4.86      4.72
# WER on test(tgsmall)             5.30      5.19
# WER on test_other(fglarge)       9.09      8.76
# WER on test_other(tglarge)       9.54      9.19
# WER on test_other(tgmed)        11.65     11.22
# WER on test_other(tgsmall)      12.77     12.24
# Final train prob              -0.0510   -0.0378
# Final valid prob              -0.0619   -0.0374
# Final train prob (xent)       -0.7499   -0.6099
# Final valid prob (xent)       -0.8118   -0.6353
# Num-parameters               20093920  22623456


#
# 1c23 is as 1c22 but with bypass-scale increased to 0.75  Better!
# 1c22 is as 1c21 but with bottleneck-dim reduced from 192 to 160.
# 1c21 is as 1c19 but with 2.5 million, instead of 5 million, frames-per-iter.
# 1c19 is a rerun of 1c{14,16} but with --constrained false in the egs.opts,
#  and upgrading to new-style configs.
# 1c16 is (by mistake) a rerun of 1c14.

# local/chain/compare_wer.sh exp/chain_cleaned/tdnn_1c14_sp exp/chain_cleaned/tdnn_1c16_sp
# System                      tdnn_1c14_sp tdnn_1c16_sp
# WER on dev(fglarge)              3.38      3.34
# WER on dev(tglarge)              3.44      3.40
# WER on dev(tgmed)                4.33      4.34
# WER on dev(tgsmall)              4.80      4.79
# WER on dev_other(fglarge)        8.63      8.66
# WER on dev_other(tglarge)        9.04      9.11
# WER on dev_other(tgmed)         11.03     11.21
# WER on dev_other(tgsmall)       12.21     12.26
# WER on test(fglarge)             3.79      3.77
# WER on test(tglarge)             3.92      3.96
# WER on test(tgmed)               4.80      4.79
# WER on test(tgsmall)             5.34      5.31
# WER on test_other(fglarge)       8.94      8.94
# WER on test_other(tglarge)       9.35      9.28
# WER on test_other(tgmed)        11.32     11.28
# WER on test_other(tgsmall)      12.43     12.39
# Final train prob              -0.0491   -0.0486
# Final valid prob              -0.0465   -0.0465
# Final train prob (xent)       -0.6463   -0.6371
# Final valid prob (xent)       -0.6668   -0.6593
# Num-parameters               23701728  23701728

# 1c14 is as 1c13 but with two more layers.
# A bit better!  Overfits slightly.
# local/chain/compare_wer.sh exp/chain_cleaned/tdnn_1c_sp exp/chain_cleaned/tdnn_1c10_sp exp/chain_cleaned/tdnn_1c11_sp exp/chain_cleaned/tdnn_1c12_sp exp/chain_cleaned/tdnn_1c13_sp exp/chain_cleaned/tdnn_1c14_sp
# System                      tdnn_1c_sp tdnn_1c10_sp tdnn_1c11_sp tdnn_1c12_sp tdnn_1c13_sp tdnn_1c14_sp
# WER on dev(fglarge)              3.31      3.43      3.37      3.36      3.33      3.38
# WER on dev(tglarge)              3.41      3.50      3.45      3.43      3.40      3.44
# WER on dev(tgmed)                4.30      4.37      4.30      4.40      4.25      4.33
# WER on dev(tgsmall)              4.81      4.79      4.82      4.86      4.74      4.80
# WER on dev_other(fglarge)        8.73      9.10      8.61      8.49      8.78      8.63
# WER on dev_other(tglarge)        9.22      9.46      9.11      8.92      9.23      9.04
# WER on dev_other(tgmed)         11.24     11.33     11.23     10.91     11.10     11.03
# WER on dev_other(tgsmall)       12.29     12.58     12.23     12.07     12.33     12.21
# WER on test(fglarge)             3.88      3.86      3.83      3.78      3.84      3.79
# WER on test(tglarge)             4.05      4.01      3.96      3.93      3.96      3.92
# WER on test(tgmed)               4.86      4.80      4.83      4.81      4.77      4.80
# WER on test(tgsmall)             5.30      5.31      5.24      5.24      5.22      5.34
# WER on test_other(fglarge)       9.09      9.02      9.05      8.88      9.02      8.94
# WER on test_other(tglarge)       9.54      9.58      9.47      9.20      9.42      9.35
# WER on test_other(tgmed)        11.65     11.63     11.35     11.28     11.46     11.32
# WER on test_other(tgsmall)      12.77     12.69     12.51     12.38     12.60     12.43
# Final train prob              -0.0510   -0.0423   -0.0449   -0.0517   -0.0460   -0.0491
# Final valid prob              -0.0619   -0.0446   -0.0456   -0.0503   -0.0460   -0.0465
# Final train prob (xent)       -0.7499   -0.5974   -0.6351   -0.6660   -0.6329   -0.6463
# Final valid prob (xent)       -0.8118   -0.6331   -0.6612   -0.6854   -0.6588   -0.6668
# Num-parameters               20093920  21339360  21339360  22297824  21339360  23701728

# 1c13 is as 1c12 but changing tdnnf5-layer back to tdnnf6-layer.
# 1c12 is as 1c11 but with changes to the learning rates (reduced) and l2
#  (doubled for non-final layers), a larger frames-per-iter, and
#  changing to tdnnf5-layer, i.e. keeping the extra splicing.
# 1c11 is as 1c10 but with double the l2-regularize.
# 1c10 is as 1c but using a newer type of setup based on the Swbd
# setup I'm working on, with tdnnf6-layers.
# Basing it on 7p10m.  Making it 4 epochs, for speed.

# 7n is a kind of factorized TDNN, with skip connections

# steps/info/chain_dir_info.pl exp/chain_cleaned/tdnn_1c_sp
# exp/chain_cleaned/tdnn_1c_sp: num-iters=1307 nj=3..16 num-params=20.1M dim=40+100->6024 combine=-0.051->-0.050 (over 23) xent:train/valid[869,1306,final]=(-0.808,-0.767,-0.771/-0.828,-0.780,-0.787) logprob:train/valid[869,1306,final]=(-0.051,-0.049,-0.047/-0.059,-0.056,-0.056)

# local/chain/compare_wer.sh exp/chain_cleaned/tdnn_1b_sp exp/chain_cleaned/tdnn_1c_sp
# System                      tdnn_1b_sp tdnn_1c_sp
# WER on dev(fglarge)              3.77      3.35
# WER on dev(tglarge)              3.90      3.49
# WER on dev(tgmed)                4.89      4.30
# WER on dev(tgsmall)              5.47      4.78
# WER on dev_other(fglarge)       10.05      8.76
# WER on dev_other(tglarge)       10.80      9.26
# WER on dev_other(tgmed)         13.07     11.21
# WER on dev_other(tgsmall)       14.46     12.47
# WER on test(fglarge)             4.20      3.87
# WER on test(tglarge)             4.28      4.08
# WER on test(tgmed)               5.31      4.80
# WER on test(tgsmall)             5.97      5.25
# WER on test_other(fglarge)      10.44      8.95
# WER on test_other(tglarge)      11.05      9.41
# WER on test_other(tgmed)        13.36     11.52
# WER on test_other(tgsmall)      14.90     12.66
# Final train prob              -0.0670   -0.0475
# Final valid prob              -0.0704   -0.0555
# Final train prob (xent)       -1.0502   -0.7708
# Final valid prob (xent)       -1.0441   -0.7874

set -e

# configs for 'chain'
stage=0
#decode_nj=50
train_set=train #train_960_cleaned
gmm=tri1 #tri6b_cleaned
nnet3_affix=   #_cleaned

# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
affix=trideltas_chain_delta_ivector_nofs
tree_affix=trideltas_chain_delta_ivector_nofs
train_stage=-10
get_egs_stage=-10
decode_iter=

# TDNN options
frames_per_eg=150,110,100
remove_egs=true
common_egs_dir=
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'

test_online_decoding=false  # if true, it will run the last decoding stage.

# End configuration section.
echo "$0 $@"  # Print the command line for logging

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

## The iVector-extraction and feature-dumping parts are the same as the standard
## nnet3 setup, and you can skip them by setting "--stage 11" if you have already
## run those things.
#
#local/nnet3/run_ivector_common.sh --stage $stage \
#                                  --train-set $train_set \
#                                  --gmm $gmm \
#                                  --num-threads-ubm 6 --num-processes 3 \
#                                  --nnet3-affix "$nnet3_affix" || exit 1;

gmm_dir=exp/$gmm
ali_dir=exp/${gmm}_ali_${train_set}_sp
tree_dir=exp/chain${nnet3_affix}/tree_sp${tree_affix:+_$tree_affix}
lang=data/lang_chain
lat_dir=exp/chain${nnet3_affix}/${gmm}_${train_set}_sp_lats
dir=exp/chain${nnet3_affix}/tdnn${affix:+_$affix}_sp
train_data_dir=data/${train_set}_sp_hires
lores_train_data_dir=data/${train_set}_sp
train_ivector_dir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

# if we are using the speed-perturbed data we need to generate
# alignments for it.

for f in $gmm_dir/final.mdl $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
    $lores_train_data_dir/feats.scp $ali_dir/ali.1.gz; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

## NOTE: the contents of run_chain_common.sh have been moved in-file here -- CB
## Please take this as a reference on how to specify all the options of
## local/chain/run_chain_common.sh
#local/chain/run_chain_common.sh --stage $stage \
#                                --gmm-dir $gmm_dir \
#                                --ali-dir $ali_dir \
#                                --lores-train-data-dir ${lores_train_data_dir} \
#                                --lang $lang \
#                                --lat-dir $lat_dir \
#                                --num-leaves 7000 \
#                                --tree-dir $tree_dir || exit 1;

if [ $stage -le 11 ]; then
  echo "$0: creating lang directory with one state per phone."
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  if [ -d $lang ]; then
    if [ $lang/L.fst -nt data/lang/L.fst ]; then
      echo "$0: $lang already exists, not overwriting it; continuing"
    else
      echo "$0: $lang already exists and seems to be older than data/lang..."
      echo " ... not sure what to do.  Exiting."
      exit 1;
    fi
  else
    cp -r data/lang $lang
    silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
    # Use our special topology... note that later on may have to tune this
    # topology.
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
  fi
fi

if [ $stage -le 12 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  nj=$(cat ${ali_dir}/num_jobs) || exit 1;
  steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" ${lores_train_data_dir} \
    $lang $gmm_dir $lat_dir
  rm $lat_dir/fsts.*.gz # save space
fi

if [ $stage -le 13 ]; then
  # Build a tree using our new topology. We know we have alignments for the
  # speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use
  # those.
  if [ -f $tree_dir/final.mdl ]; then
    echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
    exit 1;
  fi
  num_leaves=7000  # CB
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 1 \
      --context-opts "--context-width=2 --central-position=1" \
      --cmd "$train_cmd" $num_leaves $lores_train_data_dir $lang $ali_dir $tree_dir
fi

## end run_chain_common.sh

if [ $stage -le 14 ]; then
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}')
  learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)
  affine_opts="l2-regularize=0.008 dropout-proportion=0.0 dropout-per-dim=true dropout-per-dim-continuous=true"
  tdnnf_opts="l2-regularize=0.008 dropout-proportion=0.0 bypass-scale=0.75"
  linear_opts="l2-regularize=0.008 orthonormal-constraint=-1.0"
  prefinal_opts="l2-regularize=0.008"
  output_opts="l2-regularize=0.002"

  mkdir -p $dir/configs

  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  ## please note that it is important to have input layer with the name=input
  ## as the layer immediately preceding the fixed-affine-layer to enable
  ## the use of short notation for the descriptor
  #fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # this takes the MFCCs and generates filterbank coefficients.  The MFCCs
  # are more compressible so we prefer to dump the MFCCs to disk rather
  # than filterbanks.
  idct-layer name=idct input=input dim=40 cepstral-lifter=22 affine-transform-file=$dir/configs/idct.mat
  batchnorm-component name=batchnorm0 input=idct
  spec-augment-layer name=spec-augment freq-max-proportion=0.5 time-zeroed-proportion=0.2 time-mask-max-frames=20

  delta-layer name=delta input=spec-augment
  no-op-component name=input2 input=Append(delta, Scale(0.4, ReplaceIndex(ivector, t, 0)))

  # the first splicing is moved before the lda layer, so no splicing here
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

  prefinal-layer name=prefinal-chain input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  prefinal-layer name=prefinal-xent input=prefinal-l $prefinal_opts big-dim=1536 small-dim=256
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 15 ]; then

  steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$decode_cmd" \
    --feat.online-ivector-dir $train_ivector_dir \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --chain.frame-subsampling-factor 1 \
    --chain.alignment-subsampling-factor 1 \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts="--frames-overlap-per-eg 0 --constrained false --max-jobs-run 6 --max-shuffle-jobs-run 6" \
    --egs.chunk-width $frames_per_eg \
    --trainer.dropout-schedule $dropout_schedule \
    --trainer.add-option="--optimization.memory-compression-level=2" \
    --trainer.num-chunk-per-minibatch 64 \
    --trainer.frames-per-iter 2500000 \
    --trainer.num-epochs $fb_num_epochs \
    --trainer.optimization.num-jobs-initial 1 \
    --trainer.optimization.num-jobs-final 1 \
    --trainer.optimization.initial-effective-lrate 0.00015 \
    --trainer.optimization.final-effective-lrate 0.000015 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --feat-dir $train_data_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;
fi

graph_dir=$dir/graph_tgsmall
if $decode && [ $stage -le 16 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  utils/mkgraph.sh --self-loop-scale 1.0 --remove-oov data/lang_test_tgsmall $dir $graph_dir
fi

iter_opts=
[ ! -z $decode_iter ] && iter_opts=" --iter $decode_iter "
if $decode && [ $stage -le 17 ]; then
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --nj 10 --cmd "$decode_cmd" $iter_opts \
      --scoring-opts "--word-ins-penalty 0.0 --min-lmwt 8 --max-lmwt 9" \
      --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_test_hires \
      $graph_dir data/test_hires $dir/decode_test${decode_iter:+_$decode_iter}_tgsmall || exit 1
  grep -Rw WER $dir/decode_test${decode_iter:+_$decode_iter}_tgsmall | utils/best_wer.sh
  #steps/lmrescore.sh --cmd "$decode_cmd" --self-loop-scale 1.0 data/lang_test_{tgsmall,tgmed} \
  #    data/${decode_set}_hires $dir/decode_${decode_set}${decode_iter:+_$decode_iter}_{tgsmall,tgmed} || exit 1
  #steps/lmrescore_const_arpa.sh \
  #    --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
  #    data/${decode_set}_hires $dir/decode_${decode_set}${decode_iter:+_$decode_iter}_{tgsmall,tglarge} || exit 1
  #steps/lmrescore_const_arpa.sh \
  #    --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
  #    data/${decode_set}_hires $dir/decode_${decode_set}${decode_iter:+_$decode_iter}_{tgsmall,fglarge} || exit 1
  wait
fi

if $test_online_decoding && [ $stage -le 18 ]; then
  # note: if the features change (e.g. you add pitch features), you will have to
  # change the options of the following command line.
  steps/online/nnet3/prepare_online_decoding.sh \
       --mfcc-config conf/mfcc_hires.conf \
       $lang exp/nnet3${nnet3_affix}/extractor $dir ${dir}_online

  #nspk=$(wc -l <data/${data}_hires/spk2utt)
  # note: we just give it "data/${data}" as it only uses the wav.scp, the
  # feature type does not matter.
  steps/online/nnet3/decode.sh \
      --acwt 1.0 --post-decode-acwt 10.0 \
      --nj 10 --cmd "$decode_cmd" \
      $graph_dir data/test ${dir}_online/decode_test_tgsmall || exit 1
fi
echo "$0: success"
