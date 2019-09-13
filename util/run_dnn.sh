#!/bin/bash
#
# Cassio Batista   - https://cassota.gitlab.io/
# Ana Larissa Dias - larissa.engcomp@gmail.com

TAG="DNN"

function usage() {
    echo "usage: (bash) $0 OPTIONS"
    echo "eg.: $0  --use_gpu false"
    echo ""
    echo "OPTIONS"
    echo "  --use_gpu    specifies whether run on GPU or on CPU  "
}

if test $# -eq 0 ; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --use_gpu)
            use_gpu="$2"
            shift # past argument
            shift # past value
        ;;
        *)  # unknown option
            echo "[$TAG] unknown flag $1"
            usage
            shift # past argument
            exit 0
        ;;
    esac
done

if [[  -z $use_gpu ]] ; then
    echo "[$TAG] a problem with the arg flags has been detected"
    usage
    exit 1
fi

. ./path.sh || exit 1
. ./cmd.sh || exit 1

## Safety mechanism (possible running this script with modified arguments)
#. utils/parse_options.sh || exit 1

nj=6 # number of jobs default
 
# DNN parameters 
minibatch_size=512
num_epochs=8 
num_epochs_extra=5 
num_hidden_layers=2
initial_learning_rate=0.02 
final_learning_rate=0.004

#pnorm_input_dim=3000 
#pnorm_output_dim=300
pnorm_input_dim=1000 #DNN parameters for small data
pnorm_output_dim=200 #DNN parameters for small data

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
  num_threads=$nj
  parallel_opts="--num-threads $num_threads"
fi

echo
echo "============== [$TAG] DNN TRAINING ============== [$(date)]"
echo

steps/nnet2/train_pnorm_fast.sh \
    --stage -10 \
    --num-threads $num_threads \
    --minibatch-size $minibatch_size \
    --parallel-opts "$parallel_opts" \
    --num-jobs-nnet 4 \
    --num-epochs $num_epochs \
    --num-epochs-extra $num_epochs_extra \
    --add-layers-period 1 \
    --num-hidden-layers $num_hidden_layers \
    --mix-up 4000 \
    --initial-learning-rate $initial_learning_rate \
    --final-learning-rate $final_learning_rate \
    --cmd "$decode_cmd" \
    --pnorm-input-dim $pnorm_input_dim \
    --pnorm-output-dim $pnorm_output_dim \
    data/train data/lang exp/tri3_ali exp/dnn

echo
echo "============== [$TAG] FINISHED RUNNING DNN ============== [$(date)]"
echo 
