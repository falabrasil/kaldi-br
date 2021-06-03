#!/usr/bin/env bash
#
# Grupo FalaBrasil (2021)
# Universidade Federal do Pará (UFPA)
# License: MIT
#
# This script allows one to exchange lexicon
# and LM files for both decoding and rescoring
# procedures on user-defined files
#
# author: may 2021
# cassio batista - https://cassota.gitlab.io


set -e

stage=0
data=data/decodeme

am_dir=exp/chain_online_cmn/tdnn

lm_small_file=
lm_large_file=
lex_file=

. cmd.sh
. path.sh
. utils/parse_options.sh

if [ $# -lt 1 ] ; then
  echo "usage: $0 [options] <wav-file> [<wav-file>, <wav-file>, ...]"
  echo "  <wav-file> is an audio file as usual. you may pass multiple files as well"
  echo "  e.g.: $0 --lm-small-file 3gram.arpa --lm-large-file 4gram.arpa --lex-file lexicon.txt audio1.wav"
  echo
  echo "  Required options:"
  echo "    --lm-small-file is an ARPA LM file used during 1st pass decoding"
  echo "    --lm-large-file is an ARPA LM file used during 2nd pass decoding (lattice rescoring)"
  echo "    --lex-file is the phonetic dictionary (lexicon), in case you want to change it"
  exit 1
fi

audio_files=$@

# sanity check
[ ! -d $am_dir ] && echo "$0: error: dir '$am_dir' must exist" && exit 1
for f in $lm_small_file $lex_file ${audio_files[@]} ; do
  [ ! -f $f ] && echo "$0: error: file '$f' must exist" && exit 1
done
[ -z $lm_large_file ] && echo "$0: WARNING: high-order LM not set. Lattice rescoring will NOT be performed"

mkdir -p $data/data
mkdir -p $data/local/{dict,lm}

# data prep
# set number of jobs equal to the number of input audio files
nj=0
if [ $stage -le 0 ] ; then
  msg "$0: prepare data"
  rm -f $data/data/{wav.scp,utt2spk}
  for wav in ${audio_files[@]} ; do
    nj=$((nj + 1))
    utt_id=$(basename ${wav%.wav})
    echo "$utt_id $(readlink -e $wav)" >> $data/data/wav.scp
    echo "$utt_id $utt_id" >> $data/data/utt2spk
  done
  utils/utt2spk_to_spk2utt $data/data/utt2spk > $data/data/spk2utt
  utils/validate_data_dir.sh --non-print --no-feats --no-text $data/data

  ln -rsvf $lex_file      $data/local/dict/lexicon.txt
  ln -rsvf $lm_small_file $data/local/lm/small.arpa
  ln -rsvf $lm_large_file $data/local/lm/large.arpa
fi

# lang prep
if [ $stage -le 1 ] ; then
  msg "$0: prepare lang"
  /usr/bin/time -f "prepare lang took %U secs.\tRAM: %M KB" \
    utils/prepare_lang.sh $data/local/dict "<UNK>" $data/local/lang_tmp $data/lang
  /usr/bin/time -f "arpa2fst took %U secs.\tRAM: %M KB" \
    arpa2fst --disambig-symbol=#0 --read-symbol-table=$data/lang/words.txt \
      $data/local/lm/small.arpa $data/lang/G.fst
  [ -z $lm_large_file ] || /usr/bin/time -f "arpa2carpa took %U secs.\tRAM: %M KB" \
    arpa-to-const-arpa \
      --bos-symbol=$(grep "^<s>\s"  $data/lang/words.txt | awk '{print $2}') \
      --eos-symbol=$(grep "^</s>\s" $data/lang/words.txt | awk '{print $2}') \
      --unk-symbol=$(cat $data/lang/oov.int) \
      "cat $data/local/lm/large.arpa | utils/map_arpa_lm.pl $data/lang/words.txt |" \
      $data/lang/G.carpa
fi

# feat extract
if [ $stage -le 2 ] ; then
  msg "$0: extracting mfcc + cmvn"
  steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --nj $nj $data/data
  steps/compute_cmvn_stats.sh $data/data
  utils/fix_data_dir.sh $data/data
fi

# build graph
if [ $stage -le 3 ] ; then
  msg "$0: mkgraph"
  /usr/bin/time -f "mkgraph took %U secs.\tRAM: %M KB" \
    steps/mkgraph.sh --self-loop-scale 1.0 \
      $data/lang $data/nnet3 $data/nnet3/graph
fi

# prep online decode
if [ $stage -le 4 ] ; then
  msg "$0: prepare online decoding"
  steps/online/nnet3/prepapre_online_decoding.sh \
    --mfcc-config $data/nnet3/conf/mfcc.conf \
    --online-cmvn-config $data/nnet3/conf/online_cmvn.conf \
    $data/lang $data/nnet3/ivector_extractor $data/nnet3 $data/online
fi

# decode
if [ $stage -le 5 ] ; then
  msg "$0: decoding (1st pass, small LM)"
  /usr/bin/time -f "decoding took %U secs.\tRAM: %M KB" \
    steps/online/nnet3/decode.sh --nj $nj --cmd "$decode_cmd" --skip-scoring true \
      --acwt 1.0 --post-decode-acwt 10.0 --lattice-beam 8.0 --per-utt true \
      $data/nnet3/graph $data/data $data/online/decode_small
fi

# rescore
if [ ! -z $lm_large_file ] && [ $stage -le 6 ] ; then
  rm -rf $data/online/decode_large/log
  mkdir -p $data/online/decode_large/log
  msg "$0: rescoring lattices (2nd pass, large LM)"
  old_ark_in="ark:gunzip -c $data/online/decode_small/lat.JOB.gz | fstproject --project_output=true $data/lang/G.fst |"
  new_ark_out="ark,t:|gzip -c > $data/online/decode_large/lat.JOB.gz"
  /usr/bin/time -f "lattice rescoring took %U secs.\tRAM: %M KB" \
    run.pl JOB=1:$nj $data/online/decode_large/log/rescorelm.JOB.log \
      lattice-lmrescore --lm-scape=-1.0 "$old_ark_in" ark:- \| \
      lattice-lmrescore-const-arpa --lm-scale=1.0 ark:- $data/lang/G.carpa "$new_ark_out"
fi

# score
echo "TBD"

msg "$0: success!"
