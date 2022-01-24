#!/usr/bin/env bash

set -euo pipefail

# This script is called from local/nnet3/run_tdnn.sh and
# local/chain/run_tdnn.sh (and may eventually be called by more
# scripts).  It contains the common feature preparation and
# iVector-related parts of the script.  See those scripts for examples
# of usage.

stage=0
train_set=train_clean_5  # this will be changed by an upper level script (run_tdnn)
test_sets="dev_clean_2"  # this will be changed by an upper level script (run_tdnn)
gmm=tri3b

online_cmvn_iextractor=false  # same as 1j script

nnet3_affix=

. ./cmd.sh
. ./path.sh
. ./fb_commons.sh
. ./utils/parse_options.sh

gmm_dir=exp/${gmm}
ali_dir=exp/${gmm}_ali_${train_set}_sp

for f in data/${train_set}/feats.scp ${gmm_dir}/final.mdl; do
  if [ ! -f $f ]; then
    echo "$0: expected file $f to exist"
    exit 1
  fi
done

if [ $stage -le 1 ]; then
  # Although the nnet will be trained by high resolution data, we still have to
  # perturb the normal data to get the alignment _sp stands for speed-perturbed
  msg "$0: preparing directory for low-resolution speed-perturbed data (for alignment)"
  /usr/bin/time -f "speed perturb $PRF" \
    utils/data/perturb_data_dir_speed_3way.sh data/${train_set} data/${train_set}_sp

  msg "$0: making MFCC features for low-resolution speed-perturbed data"
  /usr/bin/time -f "mfcc computation $PRF" \
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 6 data/${train_set}_sp
  steps/compute_cmvn_stats.sh data/${train_set}_sp
  utils/fix_data_dir.sh data/${train_set}_sp
fi

if [ $stage -le 2 ]; then
  msg "$0: aligning with the perturbed low-resolution data"
  /usr/bin/time -f "align fmllr $PRF" \
    steps/align_fmllr.sh --nj 6 --cmd "$train_cmd" \
      data/${train_set}_sp data/lang $gmm_dir $ali_dir
fi

if [ $stage -le 3 ]; then
  # Create high-resolution MFCC features (with 40 cepstra instead of 13).
  # this shows how you can split across multiple file-systems.
  msg "$0: creating high-resolution MFCC features"
  mfccdir=data/${train_set}_sp_hires/data

  # CB: non-print flag needed for non ASCII chars
  for datadir in ${train_set}_sp ${test_sets}; do
    utils/copy_data_dir.sh --validate-opts "--non-print" \
      data/$datadir data/${datadir}_hires
  done

  # do volume-perturbation on the training data prior to extracting hires
  # features; this helps make trained nnets more invariant to test data volume.
  /usr/bin/time -f "volume perturb $PRF" \
    utils/data/perturb_data_dir_volume.sh data/${train_set}_sp_hires

  for datadir in ${train_set}_sp ${test_sets}; do
    /usr/bin/time -f "mfcc computation $PRF" \
      steps/make_mfcc.sh --nj 6 --mfcc-config conf/mfcc_hires.conf \
        --cmd "$train_cmd" data/${datadir}_hires
    steps/compute_cmvn_stats.sh data/${datadir}_hires
    utils/fix_data_dir.sh data/${datadir}_hires
  done
fi

if [ $stage -le 4 ]; then
  # We'll use about a quarter of the data.
  mkdir -p exp/nnet3${nnet3_affix}/diag_ubm
  temp_data_root=exp/nnet3${nnet3_affix}/diag_ubm

  num_utts_total=$(wc -l <data/${train_set}_sp_hires/utt2spk)
  num_utts=$[$num_utts_total/4]
  utils/data/subset_data_dir.sh data/${train_set}_sp_hires \
     $num_utts ${temp_data_root}/${train_set}_sp_hires_subset

  msg "$0: computing a PCA transform from the hires data."
  /usr/bin/time -f "pca transform $PRF" \
    steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
        --splice-opts "--left-context=3 --right-context=3" \
        --max-utts 10000 --subsample 2 \
         ${temp_data_root}/${train_set}_sp_hires_subset \
         exp/nnet3${nnet3_affix}/pca_transform

  msg "$0: training the diagonal UBM."
  # Use 512 Gaussians in the UBM.
  /usr/bin/time -f "train ubm $PRF" \
    steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 4 \
      --num-frames 700000 \
      --num-threads 2 \
      ${temp_data_root}/${train_set}_sp_hires_subset 512 \
      exp/nnet3${nnet3_affix}/pca_transform exp/nnet3${nnet3_affix}/diag_ubm
fi

if [ $stage -le 5 ]; then
  # Train the iVector extractor.  Use all of the speed-perturbed data since iVector extractors
  # can be sensitive to the amount of data.  The script defaults to an iVector dimension of
  # 100.
  msg "$0: training the iVector extractor"
  /usr/bin/time -f "train ie $PRF" \
    steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 2 \
       --num-threads 2 --num-processes 2 \
       --online-cmvn-iextractor $online_cmvn_iextractor \
       data/${train_set}_sp_hires exp/nnet3${nnet3_affix}/diag_ubm \
       exp/nnet3${nnet3_affix}/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  msg "$0: extract iVectors from perturbed data"
  # We extract iVectors on the speed-perturbed training data after combining
  # short segments, which will be what we train the system on.  With
  # --utts-per-spk-max 2, the script pairs the utterances into twos, and treats
  # each of these pairs as one speaker; this gives more diversity in iVectors..
  # Note that these are extracted 'online'.

  # note, we don't encode the 'max2' in the name of the ivectordir even though
  # that's the data we extract the ivectors from, as it's still going to be
  # valid for the non-'max2' data, the utterance list is the same.

  ivectordir=exp/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires

  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  temp_data_root=${ivectordir}
  fbutils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/${train_set}_sp_hires ${temp_data_root}/${train_set}_sp_hires_max2

  /usr/bin/time -f "extracting ivectors $PRF" \
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 6 \
      ${temp_data_root}/${train_set}_sp_hires_max2 \
      exp/nnet3${nnet3_affix}/extractor $ivectordir

  # Also extract iVectors for the test data, but in this case we don't need the speed
  # perturbation (sp).
  for data in $test_sets; do
    /usr/bin/time -f "extracting ivectors $PRF" \
      steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 6 \
        data/${data}_hires exp/nnet3${nnet3_affix}/extractor \
        exp/nnet3${nnet3_affix}/ivectors_${data}_hires
  done
fi

msg "$0: done extracting ivectors"
