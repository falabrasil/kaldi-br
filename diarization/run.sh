#!/usr/bin/env bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# Adapted from:
#   - https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8
#   - https://github.com/kaldi-asr/kaldi/issues/2523#issuecomment-408935477
# Data:
#   - https://ca.talkbank.org/access/CallHome/
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/

# Change this location to somewhere where you want to put the data.
data=./corpus/

# NOTE: CB: this dataset is huge, therefore the script is gonna be
#       downloading only the first 10 audios from the english part.
#       bear in mind that these corpus contains 64 kbps, 2-channel
#       μ-law-encoded telephone speech, which is converted by sox
#       to signed-integer linear PCM at 16 kHz via wav.scp file
#       (see fblocal/prep_data.sh)
data_url=https://media.talkbank.org/ca/CallHome/eng/0wav/

# https://david-ryan-snyder.github.io/2017/10/04/model_sre16_v2.html
# https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8
model_url=http://kaldi-asr.org/models/3/0003_sre16_v2_1a.tar.gz
nnet_dir=xvector_nnet_1a/
plda_dir=xvectors_sre_combined/

# dumb alias to $name variable seen during tutorials
segname=segmented

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data/english

start_time=$(date)

echo "[$(date +'%F %T')] $0: download data" | lolcat
fblocal/download_data.sh $data/english $data_url

if [ $stage -le 0 ] ; then
echo "[$(date +'%F %T')] $0: download model" | lolcat
  fblocal/download_model.sh $data $model_url exp/$nnet_dir exp/$plda_dir || exit 1
fi

# data preparation
if [ $stage -le 1 ] ; then
  echo "[$(date +'%F %T')] $0: prep data" | lolcat
  fblocal/prep_data.sh $data/english data/original/

  echo "[$(date +'%F %T')] $0: compute mfcc from original dataset" | lolcat
  steps/make_mfcc.sh --nj 5 --cmd "$train_cmd" \
      data/original/ exp/make_mfcc/original/ mfcc/original/
  utils/fix_data_dir.sh data/original/

  echo "[$(date +'%F %T')] $0: compute vad decisions from original dataset" | lolcat
  sid/compute_vad_decision.sh --nj 5 --cmd "$train_cmd" \
      data/original/ exp/make_vad/original/ mfcc/original/

  echo "[$(date +'%F %T')] $0: creating segments file from vad decisions" | lolcat
  diarization/vad_to_segments.sh --nj 5 --cmd "$train_cmd" \
      data/original/ data/$segname/
fi

# feature extraction
if [ $stage -le 2 ] ; then
  echo "[$(date +'%F %T')] $0: compute mfcc from segmented dataset" | lolcat
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 5 \
      --cmd "$train_cmd" --write-utt2num-frames true \
      data/$segname/ exp/make_mfcc/$segname/ mfcc/$segname/

  echo "[$(date +'%F %T')] $0: apply cmvn and dump it to disk" | lolcat
  local/nnet3/xvector/prepare_feats.sh --nj 5 --cmd "$train_cmd" \
      data/$segname/ data/${segname}_cmn/ exp/${segname}_cmn/

  cp data/$segname/{vad.scp,segments} data/${segname}_cmn/
  utils/fix_data_dir.sh data/${segname}_cmn/
fi

# extract embeddings
if [ $stage -le 3 ] ; then
  # NOTE: CB if you don't have a NVIDIA card, set nj to 10 and use-gpu to false
  # TODO having a single GPU whats the impact of nj = 1 vs nj = 2?
  echo "[$(date +'%F %T')] $0: extract xvector embeddings" | lolcat
  diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 5G" \
      --nj 2 --use-gpu true \
      --window 1.5 --period 0.75 --apply-cmn false \
      --min-segment 0.5 exp/$nnet_dir \
      data/${segname}_cmn/ exp/xvectors_$segname/
fi

# PLDA scoring
if [ $stage -le 4 ] ; then
  echo "[$(date +'%F %T')] $0: compute pair-wise similarity via plda score" | lolcat
  diarization/nnet3/xvector/score_plda.sh --cmd "$train_cmd --mem 4G" \
      --target-energy 0.9 --nj 5 exp/$plda_dir \
      exp/xvectors_$segname/ exp/xvectors_$segname/plda_scores/
fi

# clustering
if [ $stage -le 5 ] ; then
  echo "[$(date +'%F %T')] $0: perform agglomerative hierarchical clustering" | lolcat
  if [ -f data/$segname/reco2num_spk ] ; then
    echo "$0: reco2num_spk file found. number of speakers per audio is known"
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 5 \
        --reco2num-spk data/$segname/reco2num_spk \
        exp/xvectors_$segname/plda_scores/ \
        exp/xvectors_$segname/plda_scores_num_speakers/
  else
    threshold=0.5 # CB: see towardsdatascience article (run.sh header)
    echo "$0: unknown number of speakers per audio. applying threshold $threshold"
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 5 \
        --threshold $threshold \
        exp/xvectors_$segname/plda_scores/ \
        exp/xvectors_$segname/plda_scores_threshold_$threshold/
  fi
fi

# split audios
if [ $stage -le 6 ] ; then
  echo "[$(date +'%F %T')] $0: split original files with sox" | lolcat
  fblocal/split_but_merge_by_speaker.sh --nj 6 exp/xvectors_$segname/ \
      $data/english/ data/diarized/ || exit 1
fi

exit 0
