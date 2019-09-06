. ./path.sh || exit 1
. ./cmd.sh || exit 1

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1

nj=$(($(grep -c ^processor /proc/cpuinfo)/2))       # number of parallel jobs 
lm_order=3 # language model order (n-gram quantity)

num_leaves=400
tot_gauss=1600

rm_prev_data=true
run_decode=true
use_gpu=false
use_ivector=false

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
  num_threads=12
  parallel_opts="--num-threads $num_threads"
fi

# Removing previously created data (from last run.sh execution). 
if $rm_prev_data ; then
    rm -rf \
        exp \
        mfcc \
        data/{train,test}/{spk2utt,cmvn.scp,feats.scp,split2} \
        data/lang \
        data/local/lang \
        data/local/dict/lexiconp.txt
fi

./run_gmm.sh \
    --nj $nj \
    --num_leaves $num_leaves \
    --tot_gauss $tot_gauss \
    --lm_order $lm_order 
    
if ! $use_ivector ; then
    echo "'iam gonna run dnn with no ivectors"
    ./run_dnn.sh \
        --nj $nj \
        --use_gpu $use_gpu
else
    ./run_dnn_ivector.sh \
        --nj $nj \
        --use_gpu $use_gpu
fi

./run_decode.sh \
    --nj $nj \
    --run_decode $run_decode
