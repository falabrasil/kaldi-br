#!/usr/bin/env bash
#
# author: dec 2020
# cassio batista
# last update: may 2022


nj=12
decode_mono=false
decode_deltas=false
decode_lda=false
decode_sat=false
decode_nnet=true
decode_vosk=true

chunk_width=140,100,160
train_set=train_all  # CB: changed
test_sets="test_coddef test_cetuc test_constituicao test_coraa test_cv test_lapsbm test_lapsstory test_mls test_mtedx test_spoltech test_vf test_westpoint"
gmm=tri3b
nnet3_affix=
affix=1j   # affix for the TDNN directory name
tree_affix=

beam=8
lattice_beam=4.0

tree_dir=exp/chain${nnet3_affix}/tree_sp${tree_affix:+_$tree_affix}
lang=data/lang_chain
dir=exp/chain${nnet3_affix}/tdnn${affix}_sp

vosk_model_dir=/mnt/vosk-models/vosk-model-small-pt-0.3
vosk_subegs_dir=vosk-egs

. ./cmd.sh
. ./path.sh
. ./commons.sh
. utils/parse_options.sh

set -euo pipefail

if $decode_mono ; then
  msg "$0: generating mono graph"
  [ ! -f exp/mono/graph_nosp_small/HCLG.fst ] && \
    utils/mkgraph.sh data/lang_nosp_test_small \
      exp/mono exp/mono/graph_nosp_small
  msg "$0: decoding mono"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    steps/decode.sh --nj $njobs --cmd "$decode_cmd" \
      --scoring-opts "--min-lmwt 9 --max-lmwt 18 --word-ins-penalty 0.0" \
      --beam $beam --lattice-beam $lattice_beam \
      exp/mono/graph_nosp_small \
      data/$data \
      exp/mono/decode_nosp_small_$data
    grep -Rn WER exp/mono/decode_nosp_small_$data | \
      utils/best_wer.sh | tee exp/mono/decode_nosp_small_$data/fbwer.txt
  done
fi

if $decode_deltas ; then
  msg "$0: generating tri deltas graph"
  [ ! -f exp/tri1/graph_nosp_small/HCLG.fst ] && \
    utils/mkgraph.sh data/lang_nosp_test_small \
      exp/tri1 exp/tri1/graph_nosp_small
  msg "$0: decoding deltas"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    steps/decode.sh --nj $njobs --cmd "$decode_cmd" \
      --scoring-opts "--min-lmwt 9 --max-lmwt 18 --word-ins-penalty 0.0" \
      --beam $beam --lattice-beam $lattice_beam \
      exp/tri1/graph_nosp_small \
      data/$data \
      exp/tri1/decode_nosp_small_$data
    grep -Rn WER exp/tri1/decode_nosp_small_$data | \
        utils/best_wer.sh | tee exp/tri1/decode_nosp_small_$data/fbwer.txt
  done
fi

if $decode_lda ; then
  msg "$0: generating lda mllt graph"
  [ ! -f exp/tri2b/graph_nosp_small/HCLG.fst ] && \
    utils/mkgraph.sh data/lang_nosp_test_small \
      exp/tri2b exp/tri2b/graph_nosp_small
  msg "$0: decoding lda mllt"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    steps/decode.sh --nj $njobs --cmd "$decode_cmd" \
      --scoring-opts "--min-lmwt 9 --max-lmwt 18 --word-ins-penalty 0.0" \
      --beam $beam --lattice-beam $lattice_beam \
      exp/tri2b/graph_nosp_small_$data \
      data/$data \
      exp/tri2b/decode_nosp_small_$data
    grep -Rn WER exp/tri2b/decode_nosp_small_$data | \
      utils/best_wer.sh | tee exp/tri2b/decode_nosp_small_$data/fbwer.txt
  done
fi

if $decode_sat ; then
  msg "$0: generating sat graph (with sil probs)"
  [ ! -f exp/tri3b/graph_nosp_small/HCLG.fst ] && \
    utils/mkgraph.sh data/lang_test_small \
      exp/tri3b exp/tri3b/graph_small
  msg "$0: decoding sat (with sil probs)"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    steps/decode_fmllr.sh --nj $njobs --cmd "$decode_cmd" \
      --scoring-opts "--min-lmwt 9 --max-lmwt 18 --word-ins-penalty 0.0" \
      --beam $beam --lattice-beam $lattice_beam \
      exp/tri3b/graph_small \
      data/$data \
      exp/tri3b/decode_small_$data
    grep -Rn WER exp/tri3b/decode_small_$data | \
      utils/best_wer.sh | tee exp/tri3b/decode_small_$data/fbwer.txt
  done
fi

if $decode_nnet ; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  rm -f $dir/.error 
  # note: if the features change (e.g. you add pitch features), you will have to
  # change the options of the following command line.
  msg "$0: prepare online decoding"
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config conf/mfcc_hires.conf \
    $lang exp/nnet3${nnet3_affix}/extractor ${dir} ${dir}_online

  msg "$0: decoding dnn"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    prf steps/nnet3/decode.sh \
        --acwt 1.0 --post-decode-acwt 10.0 \
        --frames-per-chunk $frames_per_chunk \
        --nj $njobs --cmd "$decode_cmd" --num-threads 1 \
        --online-ivector-dir exp/nnet3${nnet3_affix}/ivectors_${data}_hires \
        --beam $beam --lattice-beam $lattice_beam \
        $tree_dir/graph_small \
        data/${data}_hires \
        ${dir}/decode_small_${data}
    grep -Rn WER $dir/decode_small_$data/wer_* | \
      utils/best_wer.sh | tee $dir/decode_small_$data/fbwer.txt
    if [ -f data/lang_test_large/G.carpa ] ; then  # TODO check
      prf steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
          data/lang_test_small \
          data/lang_test_large \
          data/${data}_hires \
          ${dir}/decode_small_${data} \
          ${dir}/decode_large_${data}
      grep -Rn WER $dir/decode_large_$data/wer_* | \
        utils/best_wer.sh | tee $dir/decode_large_$data/fbwer.txt
    fi
  done

  msg "$0: online decode"
  for data in $test_sets ; do
    # note: we just give it "data/${data}" as it only uses the wav.scp, the
    # feature type does not matter.
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    prf steps/online/nnet3/decode.sh \
        --acwt 1.0 --post-decode-acwt 10.0 \
        --nj $njobs --cmd "$decode_cmd" \
        --beam $beam --lattice-beam $lattice_beam \
        $tree_dir/graph_small \
        data/${data} \
        ${dir}_online/decode_small_${data}
    grep -Rn WER ${dir}_online/decode_small_$data/wer_* | \
      utils/best_wer.sh | tee ${dir}_online/decode_small_$data/fbwer.txt
    if [ -f data/lang_test_large/G.carpa ] ; then  # TODO check
      prf steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
          data/lang_test_small \
          data/lang_test_large \
          data/${data}_hires \
          ${dir}_online/decode_small_${data} \
          ${dir}_online/decode_large_${data}
      grep -Rn WER ${dir}_online/decode_large_$data/wer_* | \
        utils/best_wer.sh | tee ${dir}_online/decode_large_$data/fbwer.txt
    fi
  done
fi

if $decode_vosk ; then
  [ ! -d $vosk_model_dir ] && \
    echo "$0: error: bad vosk model dir: $vosk_model_dir" && exit 1

  export LD_LIBRARY_PATH=$KALDI_ROOT/tools/openfst/lib/fst

  msg "$0: link data, model and config files"
  mkdir -p $vosk_subegs_dir/{conf,data/lang/phones,exp/model/{graph/phones,ivector_extractor}}
  #ln -sfv $PWD/examples/audio16.wav $egs_dir/data
  ln -rsf $vosk_model_dir/{ivector/online_cmvn.conf,mfcc.conf} $vosk_subegs_dir/conf
  ln -rsf $vosk_model_dir/ivector/*.{dubm,ie,mat,stats,conf}   $vosk_subegs_dir/exp/model/ivector_extractor
  cp      $vosk_model_dir/ivector/splice.conf                  $vosk_subegs_dir/exp/model/ivector_extractor/splice_opts
  ln -rsf $vosk_model_dir/*.{fst,int}                          $vosk_subegs_dir/exp/model/graph
  ln -rsf $vosk_model_dir/final.mdl                            $vosk_subegs_dir/exp/model
  ln -rsf $vosk_model_dir/phones.txt                           $vosk_subegs_dir/data/lang
  ln -rsf $vosk_model_dir/phones.txt                           $vosk_subegs_dir/exp/model
  echo "1:2:3:4:5:6:7:8:9:10" >                                $vosk_subegs_dir/data/lang/phones/silence.csl
  echo "1:2:3:4:5:6:7:8:9:10" >                                $vosk_subegs_dir/exp/model/graph/phones/silence.csl

  msg "$0: mkgraph-like"
  fstcompose $vosk_subegs_dir/exp/model/graph/HCLr.fst $vosk_subegs_dir/exp/model/graph/Gr.fst | \
    fstrmsymbols $vosk_subegs_dir/exp/model/graph/disambig_tid.int | \
    fstconvert --fst_type=const > $vosk_subegs_dir/exp/model/graph/HCLG.fst

  msg "$0: prepare online decoding"
  steps/online/nnet3/prepare_online_decoding.sh \
    --mfcc-config $vosk_subegs_dir/conf/mfcc.conf --online-cmvn-config $vosk_subegs_dir/conf/online_cmvn.conf \
    $vosk_subegs_dir/data/lang $vosk_subegs_dir/exp/model/ivector_extractor $vosk_subegs_dir/exp/model $vosk_subegs_dir/exp/online

  msg "$0: extracting words.txt from graph"
  fstprint --save_osymbols=$vosk_subegs_dir/exp/model/graph/words.txt \
    $vosk_subegs_dir/exp/model/graph/Gr.fst > /dev/null

  touch $vosk_subegs_dir/exp/online/cmvn_opts
  msg "$0: decoding"
  for data in $test_sets ; do
    njobs=$nj && [ $njobs -gt $(wc -l < data/${data}/spk2utt) ] && \
      njobs=$(wc -l < data/${data}/spk2utt)
    steps/online/nnet3/decode.sh --nj $njobs \
      --acwt 1.0 --post-decode-acwt 10.0 \
      --beam $beam --lattice-beam $lattice_beam \
      $vosk_subegs_dir/exp/model/graph data/$data $vosk_subegs_dir/exp/online/decode_small_$data
    grep -Rn WER $vosk_subegs_dir/exp/online/decode_small_$data/wer_* | \
      utils/best_wer.sh | tee $vosk_subegs_dir/exp/online/decode_small_$data/fbwer.txt
  done
fi

# https://superuser.com/questions/294161/unix-linux-find-and-sort-by-date-modified
echo "------------ wrapping results up ------------"
find -name fbwer.txt -printf "%T@ %Tc %p\n" | sort -n | awk '{print $NF}' | \
  xargs cat
