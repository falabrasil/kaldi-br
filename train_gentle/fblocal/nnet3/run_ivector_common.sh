#!/usr/bin/env bash
#set -e
# this script is based on local/multicondition/run_nnet2_common.sh
# minor corrections were made to dir names for nnet3

stage=1
snrs="20:10:15:5:0"
foreground_snrs="20:10:15:5:0"
background_snrs="20:10:15:5:0"
num_data_reps=3
base_rirs="simulated"

set -e
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


# check if the required tools are present
local/multi_condition/check_version.sh || exit 1;

mkdir -p exp/nnet3
if [ $stage -le 1 ]; then
  # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
  echo "[$(date +'%F %T')] $0: download RIRs data (1.2G)" | lolcat
  if [ ! -f rirs_noises.zip ] ; then
    wget -q --show-progress --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip -q rirs_noises.zip
  else
    echo "$0: skipping download. file exists: $(du -sh rirs_noises.zip)"
  fi

  rvb_opts=()
  if [ "$base_rirs" == "simulated" ]; then
    # This is the config for the system using simulated RIRs and point-source noises
    rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
    rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")
    rvb_opts+=(--noise-set-parameters RIRS_NOISES/pointsource_noises/noise_list)
  else
    # This is the config for the JHU ASpIRE submission system
    rvb_opts+=(--rir-set-parameters "1.0, RIRS_NOISES/real_rirs_isotropic_noises/rir_list")
    rvb_opts+=(--noise-set-parameters RIRS_NOISES/real_rirs_isotropic_noises/noise_list)
  fi

  # corrupt the fisher data to generate multi-condition data
  # for data_dir in train dev test; do
  for data_dir in train test; do
    if [ "$data_dir" == "train" ]; then
      num_reps=$num_data_reps
    else
      num_reps=1
    fi
    echo "[$(date +'%F %T')] $0: reverberate data dir" | lolcat
    python steps/data/reverberate_data_dir.py \
      "${rvb_opts[@]}" \
      --prefix "rev" \
      --foreground-snrs $foreground_snrs \
      --background-snrs $background_snrs \
      --speech-rvb-probability 1 \
      --pointsource-noise-addition-probability 1 \
      --isotropic-noise-addition-probability 1 \
      --num-replications $num_reps \
      --max-noises-per-minute 1 \
      --source-sampling-rate 16000 \
      data/${data_dir} data/${data_dir}_rvb
  done
fi


if [ $stage -le 2 ]; then
  echo "[$(date +'%F %T')] $0: compute mfcc and cmvn" | lolcat
  mfccdir=mfcc_reverb
  for data_dir in train_rvb test_rvb ; do
    utils/copy_data_dir.sh --validate-opts "--non-print" \
        data/$data_dir data/${data_dir}_hires
    steps/make_mfcc.sh --nj 10 --mfcc-config conf/mfcc_hires.conf \
        --cmd "$train_cmd" data/${data_dir}_hires \
        exp/make_reverb_hires/${data_dir} $mfccdir || exit 1;
    steps/compute_cmvn_stats.sh data/${data_dir}_hires exp/make_reverb_hires/${data_dir} $mfccdir || exit 1;
    utils/fix_data_dir.sh data/${data_dir}_hires
    utils/validate_data_dir.sh --non-print --no-feats data/${data_dir}_hires || exit 1
  done

  # I'm dividing the original value by 100 because alcaim16k-DVD1de4 doesn't
  # have enough files for this absurd split - Cassio
  m=$((100000/100))
  n=$((30000/100))
  utils/subset_data_dir.sh data/train_rvb_hires $m data/train_rvb_hires_100k
  utils/subset_data_dir.sh data/train_rvb_hires $n data/train_rvb_hires_30k
fi

if [ $stage -le 3 ]; then
  echo "[$(date +'%F %T')] $0: get pca transform" | lolcat
  steps/online/nnet2/get_pca_transform.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 30000 --subsample 2 \
    data/train_rvb_hires exp/nnet3/pca_transform
fi

if [ $stage -le 4 ]; then
  # To train a diagonal UBM we don't need very much data, so use the smallest
  # subset.
  echo "[$(date +'%F %T')] $0: train diag ubm" | lolcat
  steps/online/nnet2/train_diag_ubm.sh --cmd "$train_cmd" --nj 10 --num-frames 400000 \
    data/train_rvb_hires_30k 512 exp/nnet3/pca_transform \
    exp/nnet3/diag_ubm
fi

if [ $stage -le 5 ]; then
  # iVector extractors can in general be sensitive to the amount of data, but
  # this one has a fairly small dim (defaults to 100) so we don't use all of it,
  # we use just the 100k subset (about one sixteenth of the data).
  echo "[$(date +'%F %T')] $0: train ivector extractor" | lolcat
  steps/online/nnet2/train_ivector_extractor.sh --cmd "$train_cmd" --nj 10 \
    data/train_rvb_hires_100k exp/nnet3/diag_ubm \
    exp/nnet3/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "[$(date +'%F %T')] $0: extract ivectors" | lolcat
  ivectordir=exp/nnet3/ivectors_train_rvb
  # having a larger number of speakers is helpful for generalization, and to
  # handle per-utterance decoding well (iVector starts at zero).
  #steps/online/nnet2/copy_data_dir.sh --utts-per-spk-max 2 \
  fbutils/data/modify_speaker_info.sh --utts-per-spk-max 2 \
    data/train_rvb_hires data/train_rvb_hires_max2

  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj 10 \
    data/train_rvb_hires_max2 exp/nnet3/extractor $ivectordir || exit 1;
fi
