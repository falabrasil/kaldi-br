#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Universidade Federal do Pará (UFPA)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/

echo -e "\033[94m  ____                         \033[93m _____     _           \033[0m"
echo -e "\033[94m / ___| _ __ _   _ _ __   ___  \033[93m|  ___|_ _| | __ _     \033[0m"
echo -e "\033[94m| |  _ | '__| | | | '_ \ / _ \ \033[93m| |_ / _\` | |/ _\` |  \033[0m"
echo -e "\033[94m| |_| \| |  | |_| | |_) | (_) |\033[93m|  _| (_| | | (_| |    \033[0m"
echo -e "\033[94m \____||_|   \__,_| .__/ \___/ \033[93m|_|  \__,_|_|\__,_|    \033[0m"
echo -e "                  \033[94m|_|      \033[32m ____                _ _\033[0m\033[91m  _   _ _____ ____    _   \033[0m"
echo -e "                           \033[32m| __ ) _ __ __ _ ___(_) |\033[0m\033[91m| | | |  ___|  _ \  / \          \033[0m"
echo -e "                           \033[32m|  _ \| '_ / _\` / __| | |\033[0m\033[91m| | | | |_  | |_) |/ ∆ \        \033[0m"
echo -e "                           \033[32m| |_) | | | (_| \__ \ | |\033[0m\033[91m| |_| |  _| |  __// ___ \        \033[0m"
echo -e "                           \033[32m|____/|_|  \__,_|___/_|_|\033[0m\033[91m \___/|_|   |_|  /_/   \_\       \033[0m"
echo -e ""

if test $# -ne 2 ; then
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
