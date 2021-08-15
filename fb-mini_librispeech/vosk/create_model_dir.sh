#!/usr/bin/env bash
#
# creates a model dir in a structure compatible to vosk.
# assumes 'prepare_online_decoding.sh' has already been executed.
#
# references:
#   https://github.com/alphacep/vosk-api/blob/master/src/model.cc#L180
#   https://github.com/alphacep/vosk-api/blob/master/src/model.cc#L209
#   https://alphacephei.com/vosk/models/vosk-model-en-us-aspire-0.2.zip
#   http://alphacephei.com/vosk/models/vosk-model-en-us-0.20.zip
# 
# author: aug 2021
# cassio batista - https://cassota.gitlab.io

am_dir=exp/chain/tdnn1j_sp_online
ie_dir=$am_dir/ivector_extractor
conf_dir=$am_dir/conf
tree_dir=exp/chain/tree_sp
lang_small_dir=data/lang_test_small
lang_large_dir=data/lang_test_large

set -e

if [ $# -ne 1 ] ; then
  echo "usage: $0 <vosk-model-dir>"
  exit 1
fi

dir=$1
rm -rf $dir
mkdir -p $dir/{am,conf,graph,ivector}  # TODO rnnlm

# am files
# "/am/global_cmvn.stats";  # FIXME???
cp $am_dir/final.mdl $dir/am || exit 1
cp $am_dir/tree      $dir/am || exit 1

# conf files
# NOTE: beam parameters are configurable
cp -v  $conf_dir/mfcc.conf $dir/conf || exit 1
(
  echo "--min-active=200"
  echo "--max-active=7000"
  echo "--beam=10.0"
  echo "--lattice-beam=6.0"
  echo "--acoustic-scale=1.0"
  echo "--frame-subsampling-factor=3"
  echo "--endpoint.silence-phones=$(grep -w 'endpoint.silence-phones' $conf_dir/online.conf | cut -d'=' -f2)"
  echo "--endpoint.rule2.min-trailing-silence=0.5"
  echo "--endpoint.rule3.min-trailing-silence=1.0"
  echo "--endpoint.rule4.min-trailing-silence=2.0"
) > $dir/conf/model.conf || exit 1

# graph files
cp $tree_dir/graph_small/disambig_tid.int  $dir/graph || exit 1
cp -r $tree_dir/graph_small/phones         $dir/graph || exit 1
cp $tree_dir/graph_small/words.txt         $dir/graph || exit 1
cp $tree_dir/graph_small/phones.txt        $dir/graph || exit 1
[ -f $tree_dir/graph_small_lookahead/HCLr.fst ] && \
  [ -f $tree_dir/graph_small_lookahead/Gr.fst ] && \
  cp $tree_dir/graph_small_lookahead/{HCLr,Gr}.fst $dir/graph || \
  cp $tree_dir/graph_small/HCLG.fst $dir/graph

# ivector files
cp $ie_dir/*             $dir/ivector || exit 1
cp $conf_dir/splice.conf $dir/ivector || exit 1

# lattice rescoring files
[ -f $lang_large_dir/G.carpa ] && mkdir -p $dir/rescore && \
  cp $lang_large_dir/G.carpa $lang_small_dir/G.fst $dir/rescore

# TODO rnnlm lattice rescoring files
# "/rnnlm/feat_embedding.final.mat";
# "/rnnlm/final.raw";
# "/rnnlm/special_symbol_opts.conf";
# "/rnnlm/word_feats.txt";

echo "$0: success! check '$dir'"
tree -C $dir
