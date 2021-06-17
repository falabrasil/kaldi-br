#!/usr/bin/env bash
#
# Extracts features, mainly MFCC with CMVN, LDA? and iVectors
#
# author: jun 2021
# cassio batista - https://cassota.gitlab.io


set -e
stage=1

. cmd.sh
. path.sh
. fb_commons.sh
. utils/parse_options.sh

# NOTE: from now on every feat extraction is from run_ivector_common.sh
#Although the nnet will be trained by high resolution data, we still have to
# perturb the normal data to get the alignment.  _sp stands for speed-perturbed
if [ $stage -le 1 ]; then
  msg "$0: preparing directory for low-resolution speed-perturbed data (for alignment)"
  utils/data/perturb_data_dir_speed_3way.sh data/train data/train_sp
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 data/train_sp
  steps/compute_cmvn_stats.sh data/train_sp
  utils/fix_data_dir.sh data/train_sp
fi

if [ $stage -le 2 ]; then
  msg "$0: aligning with the perturbed low-resolution data (tri-sat)"
  ali_dir=exp/tri4b_ali_train_sp
  [ -f $ali_dir/ali.1.gz ] && echo "$0: alignments in $ali_dir already exist." && exit 1
  steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
    data/train_sp data/lang exp/tri4b $ali_dir

  msg "$0: aligning with the perturbed low-resolution data (mono)"
  ali_dir=exp/mono_ali_train_sp
  [ -f $ali_dir/ali.1.gz ] && echo "$0: alignments in $ali_dir already exist." && exit 1
  steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
    data/train_sp data/lang exp/mono $ali_dir
fi

# Create high-resolution MFCC features (with 40 cepstra instead of 13).
# this shows how you can split across multiple file-systems.  we'll split the
# MFCC dir across multiple locations.  You might want to be careful here, if 
# you have multiple copies of Kaldi checked out and run the same recipe, not
# to let them overwrite each other.
if [ $stage -le 3 ]; then
  msg "$0: creating high-resolution MFCC features"

  for datadir in train_sp test; do
    utils/copy_data_dir.sh --validate-opts "--non-print" data/$datadir data/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  utils/data/perturb_data_dir_volume.sh data/train_sp_hires

  for datadir in train_sp test; do
    steps/make_mfcc.sh --nj 10 --mfcc-config conf/mfcc_hires.conf --cmd "$train_cmd" data/${datadir}_hires
    steps/compute_cmvn_stats.sh data/${datadir}_hires
    utils/fix_data_dir.sh data/${datadir}_hires
  done

  ## now create a data subset.  60k is 1/5th of the training dataset (around 200 hours).
  #utils/subset_data_dir.sh data/train_sp_hires 60000 data/train_sp_hires_60k
fi

if [ $stage -le 4 ]; then
  msg "$0: making a subset of data to train the diagonal UBM and the PCA transform."
  # We'll one hundredth of the data, since Librispeech is very large.
  mkdir -p exp/nnet3/diag_ubm
  temp_data_root=exp/nnet3/diag_ubm

  num_utts_total=$(wc -l < data/train_sp_hires/utt2spk)
  num_utts=$[$num_utts_total/4]  # original: divided by 100 -- CB
  utils/data/subset_data_dir.sh data/train_sp_hires \
     $num_utts ${temp_data_root}/train_sp_hires_subset

  msg "$0: computing a PCA transform from the hires data."
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
      --splice-opts "--left-context=3 --right-context=3" \
      --max-utts 10000 --subsample 2 \
       ${temp_data_root}/train_sp_hires_subset \
       exp/nnet3/pca_transform

  msg "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 6 \
    --num-frames 700000 --num-threads 2 \
    ${temp_data_root}/train_sp_hires_subset 512 \
    exp/nnet3/pca_transform exp/nnet3/diag_ubm
fi

if [ $stage -le 5 ]; then
  # iVector extractors can in general be sensitive to the amount of data, but
  # this one has a fairly small dim (defaults to 100) so we don't use all of it,
  # we use just the 60k subset (about one fifth of the data, or 200 hours).
  msg "$0: training the iVector extractor"
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 4 \
    --num-processes 2 --num-threads 2 \
    data/train_sp_hires exp/nnet3/diag_ubm exp/nnet3/extractor
fi

# We extract iVectors on the speed-perturbed training data after combining
# short segments, which will be what we train the system on.  With
# --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
# each of these pairs as one speaker. this gives more diversity in iVectors..
# Note that these are extracted 'online'.
if [ $stage -le 6 ]; then
  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  utils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/train_sp_hires exp/nnet3/ivectors_train_sp_hires/train_sp_hires_max2

  # extract feats from training data
  msg "$0: extracting iVectors from training data"
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 10 \
    exp/nnet3/ivectors_train_sp_hires/train_sp_hires_max2 \
    exp/nnet3/extractor \
    exp/nnet3/ivectors_train_sp_hires

  # extract feats from test data
  msg "$0: extracting iVectors from test data"
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 10 \
    data/test_hires \
    exp/nnet3/extractor \
    exp/nnet3/ivectors_test_hires
fi

msg "$0: feature extraction successfully executed!"
