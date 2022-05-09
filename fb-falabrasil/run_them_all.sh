#!/usr/bin/env bash
#
# author: jan 2022
# cassio batista - https://cassota.gitlab.io

# TODO add stages with the aid of parse_options.sh

set -e

s_time=$(date +'%F_%T')

bash run_data_prep.sh --skip-rescoring true --use-dev-as-train true || exit 1

bash run_gmm.sh || exit 1
#bas run_gmm_b.sh || exit 1  # for an "in-depth", dataset-wise analysis.

# README README README README README README README README README README README 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# XXX XXX XXX XXX XXX XXX Train a TDNN-F chain model XXX XXX XXX XXX XXX XXX 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# README README README README README README README README README README README 
# NOTE: if you *do not* have an NVIDIA card, then open up the
#       following script and set the following options on 
#       stage 14 to `train.py`:
#           --trainer.optimization.num-jobs-initial=2
#           --trainer.optimization.num-jobs-final=3
#           --use-gpu=false
#       we do not recommend training the DNN on CPU, though. 
#       you'd better set up Kaldi on Google Colab instead.
# NOTE: if you do have multiple GPU cards, on the other hand,
#       then set the parameters as the following:
#           --trainer.optimization.num-jobs-initial=2
#           --trainer.optimization.num-jobs-final=4
#           --use-gpu=true
#       (the example above assumes you have 4 NVIDIA cards)
bash run_tdnn.sh || exit 1

e_time=$(date +'%F_%T')

echo "$0: success"
echo $s_time
echo $e_time
