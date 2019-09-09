#!/bin/bash
#
# Cassio Batista   - https://cassota.gitlab.io/
# Ana Larissa Dias - larissa.engcomp@gmail.com

TAG="RUN"
COLOR_B="\e[92m"
COLOR_E="\e[0m"

. ./path.sh || exit 1
. ./cmd.sh || exit 1

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1

nj=$(($(grep -c ^processor /proc/cpuinfo)/2))       # number of parallel jobs 
lm_order=3 # language model order (n-gram quantity)

# see https://cmusphinx.github.io/wiki/tutorialam/#configuring-model-type-and-model-parameters
num_leaves=500 # senones (or tied-states)
tot_gauss=2000 # senones * densities (gaussians per mixture)

rm_prev_data=true
run_decode=true
use_gpu=false
use_ivector=false

# our language model is 165M in size so it is good to have a copy offline
# somewhere in your machine to speed things up and also save network bandwidth.
# moreover you leave it blank to donwload it from FalaBrasil's GitLab server
##lm_offline_path=
lm_offline_path=${HOME}/fb-gitlab/fb-asr/fb-asr-resources/kaldi-resources/lm/lm.arpa
if [[ ! -z $lm_offline_path ]] ; then
    if [[ ! -f $lm_offline_path ]] ; then
        echo "[$TAG] LM file '$lm_offline_path' 
does not exist. you can either fix the variable '\$lm_offline_path' 
to a valid path on your own machine or leave it empty in order to 
download the LM directly from FalaBrasil's repo on GitLab server."
        exit 1
    else
        mkdir -p data/local/tmp
        cp -rv $lm_offline_path data/local/tmp
    fi
fi

if $use_gpu ; then
  if ! cuda-compiled; then
    cat << EOF && exit 1
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

# Removing previously created data (from last run.sh execution). 
if $rm_prev_data ; then
    echo -en $COLOR_B
    echo "[$TAG] removing data from previous run"
    echo -en $COLOR_E
    rm -rf exp mfcc \
        data/{train,test}/{spk2utt,cmvn.scp,feats.scp,split2} \
        data/lang \
        data/local/lang \
        data/local/dict/lexiconp.txt
fi

num_speakers=$(ls -d data/train/*/ | wc -l)
if [ $num_speakers -le $nj ] ; then
    echo "[$TAG] the number of jobs ($nj) must be smaller than the number of speakers in the train set ($num_speakers)"
    exit 1
fi

echo -en $COLOR_B
echo "[$TAG] running 1st fix_data_dir"
echo -en $COLOR_E
utils/fix_data_dir.sh data/train
utils/fix_data_dir.sh data/test

echo -en $COLOR_B
echo "[$TAG] running gmm"
echo -en $COLOR_E
./run_gmm.sh \
    --nj $nj \
    --num_leaves $num_leaves \
    --tot_gauss $tot_gauss \
    --lm_order $lm_order 
    
if ! $use_ivector ; then
    echo -en $COLOR_B
    echo "[$TAG] running dnn with *no* ivectors"
    echo -en $COLOR_E
    ./run_dnn.sh \
        --nj $nj \
        --use_gpu $use_gpu
else
    echo -en $COLOR_B
    echo "[$TAG] running dnn with ivectors"
echo -en $COLOR_E
    ./run_dnn_ivector.sh \
        --nj $nj \
        --use_gpu $use_gpu
fi

echo -en $COLOR_B
echo "[$TAG] running 2nd fix_data_dir"
echo -en $COLOR_E
utils/fix_data_dir.sh data/train
utils/fix_data_dir.sh data/test

echo -en $COLOR_B
echo "[$TAG] running decode"
echo -en $COLOR_E
./run_decode.sh \
    --nj $nj \
    --run_decode $run_decode \
    --use_ivector $use_ivector
