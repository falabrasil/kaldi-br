#!/bin/bash
#This script is a modified version of the ../rm/s5/local/online/run_nnet2.sh that trains the DNN model with iVectors to online decoding.
. ./cmd.sh


nj=2      # number of parallel jobs 

# use stage 0 to extract mfcc features and ivector for train and test.
stage=0
# use stage 1 only if you already have extracted ivector for train and test
#stage=1
train_stage=-10
use_gpu=false

# trained GMM model
gmm=tri3

# DNN model training directory
dir=exp/nnet2_online/nnet

#DNN parameters 
minibatch_size=512
num_epochs=8 
num_epochs_extra=5 
num_hidden_layers=2
initial_learning_rate=0.02 
final_learning_rate=0.004
#pnorm_input_dim=300 
#pnorm_output_dim=3000

#DNN parameters for small data
pnorm_input_dim=1000 
pnorm_output_dim=200

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.  Otherwise, call this script with --use-gpu false
EOF
  fi
  parallel_opts="--gpu 1"
  num_threads=1
else
  # Use 4 nnet jobs just like run_4d_gpu.sh so the results should be
  # almost the same, but this may be a little bit slow.
  num_threads=12
  parallel_opts="--num-threads $num_threads"
fi


# stages 1 through 3 run in run_nnet2_common.sh.

local/online/run_nnet2_common.sh --stage  $stage --gmm $gmm || exit 1;


if [ $stage -le 4 ]; then
  steps/nnet2/train_pnorm_fast.sh \
    --stage $train_stage \
    --feat-type raw \
    --online-ivector-dir exp/nnet2_online/ivectors \
    --num-threads "$num_threads" \
    --minibatch-size "$minibatch_size" \
    --parallel-opts "$parallel_opts" \
    --num-jobs-nnet 4 \
    --num-epochs $num_epochs \
    --add-layers-period 1 \
    --num-hidden-layers $num_hidden_layers \
    --mix-up 4000 \
    --initial-learning-rate $initial_learning_rate \
    --final-learning-rate $final_learning_rate \
    --cmd "$decode_cmd" \
    --pnorm-input-dim $pnorm_input_dim \
    --pnorm-output-dim $pnorm_output_dim \
    data/train data/lang exp/"$gmm"_ali $dir  || exit 1;
fi

if [ $stage -le 5 ]; then
  steps/online/nnet2/extract_ivectors_online.sh \
      --cmd "$train_cmd" \
      --nj $nj \
      data/test exp/nnet2_online/extractor exp/nnet2_online/ivectors_test || exit 1;
fi


if [ $stage -le 6 ]; then
  # Note: the iVectors seem to hurt at small amount of data.
  # However, experiments by Haihua Xu on WSJ, show it helping nicely. 
  steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" --nj $nj \
    --online-ivector-dir exp/nnet2_online/ivectors_test \
    exp/$gmm/graph data/test $dir/decode || exit 1;

  wait
fi
exit 0;
