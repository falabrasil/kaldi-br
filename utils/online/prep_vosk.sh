#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Universidade Federal do Pará (UFPA)
#
# Receives a Kaldi egs dir as input, gathers important models files and 
# stores them into another dir in a Vosk-compliant structure
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/


python3 -c "import vosk" || { echo "$0: vosk not installed" && exit 1; }

if [ $# -ne 2 ] ; then
    echo "usage: $0 <kaldi-proj-dir> <model-dir>"
    echo "  <kaldi-proj-dir> is the project where your model was trained under kaldi/egs"
    echo "  <model-dir> is where you want the important model files to be"
    exit 1
fi

proj_dir=$(readlink -f $1)/s5/exp/chain_online_cmn
model_dir=$2

mkdir -p $model_dir/ivector

cp $proj_dir/tree_sp/graph_tgsmall/disambig_tid.int         $model_dir
cp $proj_dir/tdnn1k_sp_online/final.mdl                     $model_dir
cp $proj_dir/tree_sp/graph_tgsmall/HCLG.fst                 $model_dir
cp $proj_dir/tdnn1k_sp_online/conf/mfcc.conf                $model_dir
echo "--sample-frequency=16000"                          >> $model_dir/mfcc.conf
cp $proj_dir/tree_sp/graph_tgsmall/phones/word_boundary.int $model_dir
cp $proj_dir/tree_sp/graph_tgsmall/words.txt                $model_dir

cp $proj_dir/tdnn1k_sp_online/ivector_extractor/final.dubm        $model_dir/ivector
cp $proj_dir/tdnn1k_sp_online/ivector_extractor/final.ie          $model_dir/ivector
cp $proj_dir/tdnn1k_sp_online/ivector_extractor/final.mat         $model_dir/ivector
cp $proj_dir/tdnn1k_sp_online/ivector_extractor/global_cmvn.stats $model_dir/ivector
cp $proj_dir/tdnn1k_sp_online/ivector_extractor/online_cmvn.conf  $model_dir/ivector
cp $proj_dir/tdnn1k_sp_online/conf/splice.conf                    $model_dir/ivector

tree $model_dir
