#!/usr/bin/env bash
#
# Grupo FalaBrasil (2021)
# Universidade Federal do Pará (UFPA)
#
# A script to execute Vosk's default model for
# PT_BR directly into Kaldi.
# This script must be executed from within a 
# kaldi/egs project dir, so you gotta first 
# create something like kaldi/egs/vosk_test/s5
# dir, and then copy this script into the dir
# before executing it.
#
# author: may 2021
# Cassio Batista - https://cassota.gitlab.io

set -e

function msg { echo -e "\e[$(shuf -i 91-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }

stage=0

model_url=https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip
model_zip=$(basename $model_url)
model_dir=${model_zip%.zip}
size=52344

# Pre-execution hints:
# $ mkdir $HOME/kaldi/egs/vosk_proj/s5
# $ cp -v run_vosk_on_kaldi.sh $HOME/kaldi/egs/vosk_proj/s5
# $ cd $HOME/kaldi/egs/vosk_proj/s5
# $ ./run_vosk_on_kaldi.sh audio.wav
[[ $(basename $(dirname $(dirname $PWD))) != "egs" ]] && \
  echo "$0: error: to be exec'd from under kaldi/egs/<project>/s5 dir" && exit 1

# set up egs dir under kaldi root and link some default script files and dirs
mkdir -p data/lang/phones conf local exp/model/{graph/phones,ivector_extractor}
ln -sf ../../wsj/s5/{steps,utils} .
ln -sf ../../mini_librispeech/s5/path.sh .
ln -sf ../../mini_librispeech/s5/local/score.sh local

. path.sh
. utils/parse_options.sh

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$KALDI_ROOT/tools/openfst/lib/fst

if [ $# -ne 1 ] ; then
  echo "usage: $0 <wav-file>"
  echo "  <wav-file> is the audio file to undergo decoding"
  exit 1
fi

wav_file=$(readlink -e $1)
utt_id=$(basename ${wav_file%.wav})

# download model from server
if [[ ! -d $model_dir ]] || [[ $(du -s $model_dir | awk '{print $1}') -ne $size ]]; then
  msg "$0: downloading and unzipping model"
  wget -q --show-progress $model_url
  unzip $model_zip
else
  echo "$0: model files seem to be in place. skipping download"
fi

# link data, model and config files
#ln -sfv $PWD/examples/audio16.wav $egs_dir/data
ln -rsf $model_dir/{ivector/online_cmvn.conf,mfcc.conf} conf
ln -rsf $model_dir/ivector/*.{dubm,ie,mat,stats,conf}   exp/model/ivector_extractor
cp      $model_dir/ivector/splice.conf                  exp/model/ivector_extractor/splice_opts
ln -rsf $model_dir/*.{fst,int}                          exp/model/graph
ln -rsf $model_dir/final.mdl                            exp/model
ln -rsf $model_dir/phones.txt                           data/lang
ln -rsf $model_dir/phones.txt                           exp/model
echo "1:2:3:4:5:6:7:8:9:10" >                           data/lang/phones/silence.csl
echo "1:2:3:4:5:6:7:8:9:10" >                           exp/model/graph/phones/silence.csl

# data preparation: wav.scp, utt2spk and spk2utt (no text necessary)
if [ $stage -le 0 ] ; then
  msg "$0: data preparation"
  echo "$utt_id $wav_file" > data/wav.scp
  echo "$utt_id $utt_id" > data/utt2spk
  utils/utt2spk_to_spk2utt.pl data/utt2spk > data/spk2utt
  utils/validate_data_dir.sh --non-print --no-feats --no-text data
fi

# compute mfcc and cmvn
if [ $stage -le 1 ] ; then
  msg "$0: mfcc + cmvn extraction"
  steps/make_mfcc.sh --cmd "run.pl" --nj 1 --mfcc-config conf/mfcc.conf data
  steps/compute_cmvn_stats.sh data
fi

# mkgraph: generate full graph to avoid on the fly composition
if [ $stage -le 2 ] ; then
  msg "$0: mkgraph-like"
  /usr/bin/time -f "Composing graph took %U secs.\tRAM: %M kB" \
    fstcompose exp/model/graph/HCLr.fst exp/model/graph/Gr.fst | \
      fstrmsymbols exp/model/graph/disambig_tid.int | \
      fstconvert --fst_type=const > exp/model/graph/HCLG.fst
fi

# prepare online decoding
if [ $stage -le 3 ] ; then
  rm -rf exp/online 
  msg "$0: prepare online decoding"
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc.conf --online-cmvn-config conf/online_cmvn.conf \
    data/lang exp/model/ivector_extractor exp/model exp/online

  /usr/bin/time -f "Extracting words.txt from graph took %U secs.\tRAM: %M kB" \
  fstprint --save_osymbols=exp/model/graph/words.txt \
    exp/model/graph/Gr.fst > /dev/null
fi

# decoding via online2-wav-nnet3-latgen-faster
if [ $stage -le 4 ] ; then
  msg "$0: decoding"
  touch exp/online/cmvn_opts
  /usr/bin/time -f "Decoding took %U secs.\tRAM: %M kB" \
    steps/online/nnet3/decode.sh --nj 1 \
      --acwt 1.0 --post-decode-acwt 10.0 --beam 15.0 --lattice-beam 8.0 \
      --online true --per-utt true --skip-scoring true \
      exp/model/graph data exp/online/decode_tgsmall
  grep "^$utt_id" exp/online/decode_tgsmall/log/decode.1.log
fi

## scoring
#if [ $stage -le 5 ] ; then
#  mkdir -p exp/online/decode_tgsmall/scoring/log
#  lattice-scale --inv-acoustic-scale=9.0 "ark:gunzip -c exp/online/decode_tgsmall/lat.*.gz|" ark:- | \
#    lattice-add-penalty --word-ins-penalty=0.0 ark:- ark:- | \
#    lattice-best-path --word-symbol-table=exp/model/graph/words.txt \
#    ark:- ark,t:exp/online/decode_tgsmall/scoring/8.0.0.tra.int
#
#  cat exp/online/decode_tgsmall/scoring/8.0.0.tra.int | \
#    utils/int2sym.pl -f 2- exp/model/graph/words.txt | \
#    tee exp/online/decode_tgsmall/scoring/8.0.0.tra.sym
#fi

msg "$0: success!"
