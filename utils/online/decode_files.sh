#!/usr/bin/env bash
#
# Grupo FalaBrasil (2021)
# Universidade Federal do Pará (UFPA)
# License: MIT
#
# This script performs both decoding and lattice
# rescore procedures on user-defined audio files.
# XXX NOTE: make sure to execute this script from 
# XXX       within a kaldi/egs project dir after 
# XXX       you trained your model.
#
# author: may 2021
# cassio batista - https://cassota.gitlab.io


set -e

function msg { echo -e "\e[$(shuf -i 91-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }

stage=1
nj=1
data=data/decodeme

am_dir=exp/chain_online_cmn/tdnn1k_sp
ie_dir=exp/nnet3_online_cmn/extractor
tree_dir=exp/chain_online_cmn/tree_sp

. cmd.sh
. path.sh
. utils/parse_options.sh

if [ $# -lt 1 ] ; then
  echo "usage: $0 [options] <wav-file> [<wav-file>, <wav-file>, ...]"
  echo "  <wav-file> is an audio file as usual. you may pass multiple files as well"
  echo "  e.g.: $0 audio1.wav audio2.wav"
  echo
  echo "  Optional options:"
  echo "    --am-dir is the directory to the acoustic model. default: $am_dir"
  echo "    --ie-dir is the directory to the ivector extractor model. default: $ie_dir"
  exit 1
fi

audio_files=$@

# sanity check
for d in $am_dir $ie_dir ; do [ ! -d $d ] && echo "$0: error: dir '$d' must exist" && exit 1 ; done
for f in ${audio_files[@]} ; do [ ! -f $f ] && echo "$0: error: file '$f' must exist" && exit 1 ; done

mkdir -p $data/data
#mkdir -p $data/local/{dict,lm}

# data prep
# set number of jobs equal to the number of input audio files
i=0
msg "$0: prepare data"
rm -f $data/data/{wav.scp,utt2spk}
for wav in ${audio_files[@]} ; do
  i=$((i + 1))
  utt_id=$(basename ${wav%.wav})
  echo "$utt_id $(readlink -e $wav)" >> $data/data/wav.scp
  echo "$utt_id $utt_id" >> $data/data/utt2spk
done
utils/utt2spk_to_spk2utt.pl $data/data/utt2spk > $data/data/spk2utt
utils/validate_data_dir.sh --non-print --no-feats --no-text $data/data

# sanity check on number of jobs vs number of audio files
[ $nj -gt $i ] && \
  echo "$0: WARNING: #jobs $nj greater than #files $i. reducing..." && nj=$i
[ $nj -lt $i ] && \
  echo "$0: WARNING: #jobs $nj less than #files $i. may be suboptimal."

# feat extract
if [ $stage -le 1 ] ; then
  msg "$0: extracting mfcc + cmvn"
  steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --nj $nj $data/data
  steps/compute_cmvn_stats.sh $data/data
  utils/fix_data_dir.sh $data/data
fi

# prep online decode
if [ $stage -le 2 ] ; then
  msg "$0: prepare online decoding"
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc_hires.conf \
    --online-cmvn-config $ie_dir/online_cmvn.conf \
    data/lang $ie_dir $am_dir $data/online
fi

# decode
if [ $stage -le 3 ] ; then
  msg "$0: decoding (1st pass, small LM)"
  /usr/bin/time -f "decoding took %U secs.\tRAM: %M KB" \
    steps/online/nnet3/decode.sh --nj $nj --cmd "$decode_cmd" --skip-scoring true \
      --acwt 1.0 --post-decode-acwt 10.0 --lattice-beam 8.0 --per-utt true \
      $tree_dir/graph_tgsmall $data/data $data/online/decode_small
fi

# rescore (extracted from steps/lmrescore_const_arpa.sh)
if [ -f data/lang_test_tglarge/G.carpa ] && [ $stage -le 4 ] ; then
  rm -rf   $data/online/decode_large/log
  mkdir -p $data/online/decode_large/log
  msg "$0: rescoring lattices (2nd pass, large LM)"
  old_ark_in="ark:gunzip -c $data/online/decode_small/lat.JOB.gz |"
  new_ark_out="ark,t:|gzip -c > $data/online/decode_large/lat.JOB.gz"
  /usr/bin/time -f "lattice rescoring took %U secs.\tRAM: %M KB" \
    run.pl JOB=1:$nj $data/online/decode_large/log/rescorelm.JOB.log \
      lattice-lmrescore --lm-scale=-1.0 "$old_ark_in" "fstproject --project_output=true data/lang_test_tgsmall/G.fst |" ark:- \| \
      lattice-lmrescore-const-arpa --lm-scale=1.0 ark:- data/lang_test_tglarge/G.carpa "$new_ark_out"
fi

# score (extracted from local/score.sh)
# NOTE fixing LM weight to 9.0 and disabling word insertion penalty by default
if [ $stage -le 5 ] ; then
  dir=$data/online/decode_small
  [ -f data/lang_test_tglarge/G.carpa ] && dir=$data/online/decode_large
  rm -rf   $dir/scoring/log score.log
  mkdir -p $dir/scoring/log
  /usr/bin/time -f "scoring took %U secs.\tRAM: %M KB" \
    run.pl LMWT=9:9 $dir/scoring/log/best_path.LMWT.0.0.log \
      lattice-scale --inv-acoustic-scale=LMWT "ark:gunzip -c $dir/lat.*.gz|" ark:- \| \
      lattice-add-penalty --word-ins-penalty=0.0 ark:- ark:- \| \
      lattice-best-path --word-symbol-table=data/lang/words.txt \
        ark:- ark,t:$dir/scoring/LMWT.0.0.tra
  for tra in $dir/scoring/*.tra ; do
    cat $tra | utils/int2sym.pl -f 2- data/lang/words.txt | tee -a score.log
  done
fi

msg "$0: success!"
