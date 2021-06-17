#!/usr/bin/env bash
#
# Downloads data and resources from servers.
# Prepare data files according to Kaldi's taste.
#
# author: may 2021
# cassio batista - https://cassota.gitlab.io

set -e

data=./corpus

data_url=https://gitlab.com/fb-audio-corpora/lapsbm16k/-/archive/master/lapsbm16k-master.tar.gz
lex_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lexicon.utf8.dict.gz
lm_url=https://gitlab.com/fb-nlp/nlp-resources/-/raw/master/res/lm.3gram.arpa.gz
#ie_url=https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip

audio_dir=
lm_file_small=
lex_file=
#ie_file=

stage=1

. cmd.sh
. path.sh 
. fb_commons.sh
. utils/parse_options.sh


mkdir -p $data || exit 1

if [ $stage -le 1 ]; then
  if [ -z "$audio_dir" ] ; then
    msg "$0: downloading LapsBM data (85M)"
    /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
      fblocal/download_data.sh $data $data_url || exit 1
  else
    msg "$0: gathering data from '$audio_dir'"
    data=$audio_dir
  fi
fi

if [ $stage -le 2 ]; then
  mkdir -p data/local/dict_nosp
  if [ -z "$lex_file" ] ; then
    msg "$0: downloading dict from FalaBrasil GitLab"
    /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
      fblocal/download_lexicon.sh $data $lex_url data/local/dict_nosp || exit 1
  else
    msg "$0: copying lexicon from '$lex_file'"
    cp -v $lex_file $data || exit 1
    gzip -cd $data/$(basename $lex_file) > data/local/dict_nosp/lexicon.txt || exit 1
  fi
fi

if [ $stage -le 3 ]; then
  mkdir -p data/local/lm
  if [ -z "$lm_file_small" ] ; then
    msg "$0: downloading LM from FalaBrasil GitLab"
    /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
      fblocal/download_lm.sh $data $lm_url data/local/lm || exit 1
  else
    msg "$0: copying LM small from '$lex_file'"
    cp -v $lm_file_small $data || exit 1
    ln -rsf $data/$(basename $lm_file_small) data/local/lm/lm_tglarge.arpa.gz || exit 1
  fi
fi

## NOTE: Vosk's model v0.3 default to 30-dim ivectors, 20 mel bins and 20 
## which may be a problem for some obscure reason since all other recipes use
## 100-dim ivectors and 40 high-res cepstral coeffs. Therefore I'm choosing to 
## train the IE model from scracth instead of using Vosk's.
#if [ $stage -le 4 ]; then
#  mkdir -p exp/nnet3/extractor || exit 1
#  if [ -z $ie_file ] ; then
#    msg "$0: downloading ivector extractor model from Vosk server (31M)"
#    fblocal/download_vosk.sh $data $ie_url exp/nnet3/extractor
#  else
#    msg "$0: copying Vosk's ivector extractor model from '$ie_file'"
#    cp -v $ie_file $data || exit 1
#    unzip $data/$(basename $ie_file) -d $data || exit 1 
#    cp -v $data/$(basename ${ie_file%.zip})/ivector/* exp/nnet3/extractor
#  fi
#fi

if [ $stage -le 5 ]; then
  # format the data as Kaldi data directories
  msg "$0: prep data"
  /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
    fblocal/prep_data.sh --nj 8 --split-random true $data data/
  #fblocal/prep_data.sh --nj 8 --test-dir lapsbm16k $data ./data

  # CB: stage 3 doesn't need local/lm dir
  msg "$0: prep dict"
  /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
    fblocal/prep_dict.sh --nj 8 data/local/dict_nosp/

  # CB: leave as it is
  msg "$0: prep lang"
  /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
    utils/prepare_lang.sh data/local/dict_nosp \
      "<UNK>" data/local/lang_tmp_nosp/ data/lang_nosp/

  msg "$0: format lms"
  /usr/bin/time -f "Time: %U secs. RAM: %M KB" \
    fblocal/format_lms.sh --src-dir data/lang_nosp data/local/lm

  ## Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  #msg "$0: build const arpa"
  #utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
  #  data/lang_nosp/ data/lang_nosp_test/
fi

msg "$0: data preparation successfully finished!"
