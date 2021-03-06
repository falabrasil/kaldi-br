#!/usr/bin/env bash

set -e

# based on run_tdnn_7b.sh in the swbd recipe

# configs for 'chain'
stage=1 # assuming you already ran the xent systems # CB: originally 7
train_stage=-10
get_egs_stage=-10
dir=exp/chain/tdnn_7b
decode_iter=

# training options
num_epochs=4
remove_egs=false
common_egs_dir=
num_data_reps=3


min_seg_len=
xent_regularize=0.1
frames_per_eg=150
# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

ali_dir=exp/tri5a_rvb_ali
treedir=exp/chain/tri6_tree_11000
lang=data/lang_chain


# The iVector-extraction and feature-dumping parts are the same as the standard
# nnet3 setup, and you can skip them by setting "--stage 8" if you have already
# run those things.
fblocal/nnet3/run_ivector_common.sh --stage $stage --num-data-reps ${num_data_reps} || exit 1;

# NOTE: it starts at 7 bc ivector_common ranges from 1 up to 6 -Cassio
if [ $stage -le 7 ]; then
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]

  echo "[$(date +'%F %T')] $0: generating topo" | lolcat
  rm -rf $lang
  cp -r data/lang $lang
  silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
  # Use our special topology... note that later on may have to tune this
  # topology.
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
fi

if [ $stage -le 8 ]; then
  # Build a tree using our new topology.
  # we build the tree using clean features (data/train) rather than
  # the augmented features (data/train_rvb) to get better alignments

  echo "[$(date +'%F %T')] $0: building tree" | lolcat
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 3 \
      --cmd "$train_cmd" 11000 data/train $lang exp/tri5a $treedir
fi

if [ -z $min_seg_len ]; then
  min_seg_len=$(python -c "print(($frames_per_eg+5)/100.0)")
fi

if [ $stage -le 9 ]; then
  echo "[$(date +'%F %T')] $0: extracting ivectors online" | lolcat
  rm -rf data/train_rvb_min${min_seg_len}_hires
  utils/data/combine_short_segments.sh \
      data/train_rvb_hires $min_seg_len data/train_rvb_min${min_seg_len}_hires
  steps/compute_cmvn_stats.sh data/train_rvb_min${min_seg_len}_hires exp/make_reverb_hires/train_rvb_min${min_seg_len} mfcc_reverb || exit 1;

  #extract ivectors for the new data
  #steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 \
  fbutils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/train_rvb_min${min_seg_len}_hires data/train_rvb_min${min_seg_len}_hires_max2
  ivectordir=exp/nnet3/ivectors_train_min${min_seg_len}

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 10 \
    data/train_rvb_min${min_seg_len}_hires_max2 \
    exp/nnet3/extractor $ivectordir || exit 1;

 # combine the non-hires features for alignments/lattices
 rm -rf data/${latgen_train_set}_min${min_seg_len}
  utt_prefix="THISISUNIQUESTRING-"
  spk_prefix="THISISUNIQUESTRING-"
  utils/copy_data_dir.sh --spk-prefix "$spk_prefix" --utt-prefix "$utt_prefix" \
    --validate-opts "--non-print" \
    data/train data/train_temp_for_lats
  utils/data/combine_short_segments.sh \
      data/train_temp_for_lats $min_seg_len data/train_min${min_seg_len}
  steps/compute_cmvn_stats.sh data/train_min${min_seg_len} || exit 1;
fi

if [ $stage -le 10 ]; then
  echo "[$(date +'%F %T')] $0: align lattices" | lolcat
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  nj=10
  lat_dir=exp/tri5a_min${min_seg_len}_lats
  steps/align_fmllr_lats.sh --nj $nj --cmd "$train_cmd" data/train_min${min_seg_len} \
    data/lang exp/tri5a $lat_dir
  rm -f $lat_dir/fsts.*.gz # save space

  rvb_lat_dir=exp/tri5a_rvb_min${min_seg_len}_lats
  mkdir -p $rvb_lat_dir/temp/
  lattice-copy "ark:gunzip -c $lat_dir/lat.*.gz |" ark,scp:$rvb_lat_dir/temp/lats.ark,$rvb_lat_dir/temp/lats.scp

  # copy the lattices for the reverberated data
  rm -f $rvb_lat_dir/temp/combined_lats.scp
  touch $rvb_lat_dir/temp/combined_lats.scp
  for i in `seq 1 $num_data_reps`; do
    cat $rvb_lat_dir/temp/lats.scp | sed -e "s/THISISUNIQUESTRING/rev${i}/g" >> $rvb_lat_dir/temp/combined_lats.scp
  done
  sort -u $rvb_lat_dir/temp/combined_lats.scp > $rvb_lat_dir/temp/combined_lats_sorted.scp

  lattice-copy scp:$rvb_lat_dir/temp/combined_lats_sorted.scp "ark:|gzip -c >$rvb_lat_dir/lat.1.gz" || exit 1;
  echo "1" > $rvb_lat_dir/num_jobs

  # copy other files from original lattice dir
  for f in cmvn_opts final.mdl splice_opts tree; do
    cp $lat_dir/$f $rvb_lat_dir/$f
  done

fi

if [ $stage -le 11 ]; then
  echo "[$(date +'%F %T')] $0: creating neural net configs using the xconfig parser" | lolcat

  num_targets=$(tree-info $treedir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 dim=1024
  relu-batchnorm-layer name=tdnn2 input=Append(-1,0,1,2) dim=1024
  relu-batchnorm-layer name=tdnn3 input=Append(-3,0,3) dim=1024
  relu-batchnorm-layer name=tdnn4 input=Append(-3,0,3) dim=1024
  relu-batchnorm-layer name=tdnn5 input=Append(-3,0,3) dim=1024
  relu-batchnorm-layer name=tdnn6 input=Append(-6,-3,0) dim=1024

  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain input=tdnn6 dim=1024 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5

  # adding the layers for xent branch
  # This block prints the configs for a separate output that will be
  # trained with a cross-entropy objective in the 'chain' models... this
  # has the effect of regularizing the hidden parts of the model.  we use
  # 0.5 / args.xent_regularize as the learning rate factor- the factor of
  # 0.5 / args.xent_regularize is suitable as it means the xent
  # final-layer learns at a rate independent of the regularization
  # constant; and the 0.5 was tuned so as to make the relative progress
  # similar in the xent and regular final layers.
  relu-batchnorm-layer name=prefinal-xent input=tdnn6 dim=1024 target-rms=0.5
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 12 ]; then
  echo "[$(date +'%F %T')] $0: train dnn" | lolcat
  mkdir -p $dir/egs
  touch $dir/egs/.nodelete # keep egs around when that run dies.

  steps/nnet3/chain/train.py --stage $train_stage \
    --egs.dir "$common_egs_dir" \
    --cmd "$decode_cmd" \
    --feat.online-ivector-dir exp/nnet3/ivectors_train_min${min_seg_len} \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.00005 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width 150 \
    --trainer.num-chunk-per-minibatch 128 \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial 1 \
    --trainer.optimization.num-jobs-final 1 \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --feat-dir data/train_rvb_min${min_seg_len}_hires \
    --tree-dir $treedir \
    --lat-dir exp/tri5a_rvb_min${min_seg_len}_lats \
    --dir $dir  || exit 1;
fi

if [ $stage -le 13 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  echo "[$(date +'%F %T')] $0: creating dnn graph" | lolcat
  utils/mkgraph.sh --self-loop-scale 1.0 \
    data/lang_pp_test $dir $dir/graph_pp || exit 1
fi

if [ $stage -le 14 ]; then
  echo "[$(date +'%F %T')] $0: decoding dnn" | lolcat
  steps/nnet3/decode.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --frames-per-chunk 150 \
    --nj 5 --cmd "$decode_cmd" --num-threads 4 \
    --online-ivector-dir exp/nnet3/ivectors_test_rvb_hires \
    $dir/graph_pp data/test_rvb_hires $dir/decode_test_rvb_hires
  grep -Rn WER $dir/decode_test_rvb_hires | \
      utils/best_wer.sh | tee > $dir/decode_test_rvb_hires/fbwer.txt
fi

# NOTE: created by Cassio
# this step is equivalent to stage 17 of mini librispeech recipe
if [ $stage -le 15 ] ; then
  echo "[$(date +'%F %T')] $0: prepare online decoding" | lolcat
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc_hires.conf \
    --online-cmvn-config conf/online_cmvn.conf \
    data/lang exp/nnet3/extractor $dir ${dir}_chain_online

  echo "[$(date +'%F %T')] $0: online decode" | lolcat
  # note: we just give it "data/${data}" as it only uses the wav.scp, the
  # feature type does not matter.
  steps/online/nnet3/decode.sh \
    --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 5 --cmd "$decode_cmd" \
    $dir/graph_pp data/test_rvb_hires ${dir}_chain_online/decode_test_rvb_hires || exit 1
  grep -Rn WER ${dir}_chain_online/decode_test_rvb_hires | \
      utils/best_wer.sh | tee > ${dir}_chain_online/decode_test_rvb_hires/fbwer.txt
fi
