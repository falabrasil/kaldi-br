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

for f in wget ; do
    if ! type -t $f > /dev/null ; then
        echo "please install $f"
        exit 1
    fi
done

function write_yaml() {
    # https://stackoverflow.com/questions/5047165/replacing-from-match-to-end-of-line
    # https://superuser.com/questions/321240/how-do-you-redirect-wget-response-to-standard-out
    wget -O - https://raw.githubusercontent.com/alumae/kaldi-gstreamer-server/master/sample_chinese_nnet3.yaml 2> /dev/null | \
        sed "s#model :.*#model : $model_dir/final.mdl#g" | \
        sed "s#word-syms :.*#word-syms : $model_dir/words.txt#g" | \
        sed "s#fst :.*#fst : $model_dir/HCLG.fst#g" | \
        sed "s#mfcc-config :.*#mfcc-config : $model_dir/conf/mfcc.conf#g" | \
        sed "s#ivector-extraction-config :.*#ivector-extraction-config : $model_dir/conf/ivector_extractor.conf#g"
}

proj_dir=$(readlink -f $1)/s5/exp/chain_online_cmn
model_dir=$2
yaml=$3
mkdir -p ${model_dir}/{conf,ivector_extractor}

cp ${proj_dir}/tdnn1k_sp_online/final.mdl                                                   $model_dir/final.mdl
cp ${proj_dir}/tree_sp/graph_tgsmall/words.txt                                              $model_dir/words.txt
cp ${proj_dir}/tree_sp/graph_tgsmall/HCLG.fst                                               $model_dir/HCLG.fst

cp ${proj_dir}/tdnn1k_sp_online/conf/mfcc.conf                                              $model_dir/conf/mfcc.conf
echo "--sample-frequency=16000"                                                          >> $model_dir/conf/mfcc.conf
cp ${proj_dir}/tdnn1k_sp_online/conf/ivector_extractor.conf                                 $model_dir/conf/ivector_extractor.conf
sed -i "s#--splice-config=.*#--splice-config=conf/splice.conf#g"                            $model_dir/conf/ivector_extractor.conf
sed -i "s#--cmvn-config=.*#--cmvn-config=conf/online_cmvn.conf#g"                           $model_dir/conf/ivector_extractor.conf
sed -i "s#--lda-matrix=.*#--lda-matrix=ivector_extractor/final.mat#g"                       $model_dir/conf/ivector_extractor.conf
sed -i "s#--global-cmvn-stats=.*#--global-cmvn-stats=ivector_extractor/global_cmvn.stats#g" $model_dir/conf/ivector_extractor.conf
sed -i "s#--diag-ubm=.*#--diag-ubm=ivector_extractor/final.dubm#g"                          $model_dir/conf/ivector_extractor.conf
sed -i "s#--ivector-extractor=.*#--ivector-extractor=ivector_extractor/final.ie#g"          $model_dir/conf/ivector_extractor.conf
cp ${proj_dir}/tdnn1k_sp_online/conf/splice.conf                                            $model_dir/conf/splice.conf 
cp ${proj_dir}/tdnn1k_sp_online/conf/online_cmvn.conf                                       $model_dir/conf/online_cmvn.conf

cp ${proj_dir}/tdnn1k_sp_online/ivector_extractor/final.mat                                 $model_dir/ivector_extractor/final.mat
cp ${proj_dir}/tdnn1k_sp_online/ivector_extractor/global_cmvn.stats                         $model_dir/ivector_extractor/global_cmvn.stats
cp ${proj_dir}/tdnn1k_sp_online/ivector_extractor/final.dubm                                $model_dir/ivector_extractor/final.dubm
cp ${proj_dir}/tdnn1k_sp_online/ivector_extractor/final.ie                                  $model_dir/ivector_extractor/final.ie

tree $model_dir >&2

write_yaml #& # throw to bg
