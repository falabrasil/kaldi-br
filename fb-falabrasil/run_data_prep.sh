#!/usr/bin/env bash
#
# author: jan 2022
# cassio batista - https://cassota.gitlab.io

set -euo pipefail

stage=0
nj=12
skip_rescoring=false  # if your machine is memory-contrained then turn this on
use_dev_as_train=false

# Change this location to somewhere where you want to put the data.
data=./corpus/

speech_datasets_dir=/mnt/speech-datasets
lex_url=https://gitlab.com/fb-resources/dicts-br/-/raw/main/res/lexicon.vocab.txt.gz
lm_small_url=https://gitlab.com/fb-resources/lm-br/-/raw/main/res/3-gram.2e-7.arpa.gz
lm_large_url=https://gitlab.com/fb-resources/lm-br/-/raw/main/res/4-gram.unpruned.arpa.gz

# (re)set this up if you want to run with your own data.
# then execute this script as follows:
# $./run.sh \
#       --speech-datasets-dir   DATA_DIR \
#       --lex-file              LEX-FILE \
#       --lm-file-small         LM-FILE-1st-PASS \
#       --lm-file-large         LM-FILE-2nd-PASS
lex_file=
lm_small_file=
lm_large_file=

. ./cmd.sh || exit 1
. ./path.sh || exit 1
. ./commons.sh || exit 1

. utils/parse_options.sh

# sanity check on file extensions: must be .gz files
for f in $lm_small_file $lm_large_file $lex_file ; do
  [ ! -z $f ] && [[ "$f" != *".gz" ]] && \
    echo "$0: error: model $f must be gzip-compressed" && exit 1
done

mkdir -p $data
mkdir -p data/local/{dict_nosp,lm}

# resources preparation: set up dict and n-gram LMs under $data dir
if [ $stage -le 0 ]; then
  # prepare lexicon
  if [ -z "$lex_file" ] ; then
    msg "$0: downloading dict from FalaBrasil GitLab (1.5M)"
    if [ -f $data/$(basename $lex_url) ] ; then
      echo "$0: lexicon already in place. skipping download"
    else
      wget --quiet --show-progress $lex_url -P $data || \
        { echo >&2 "$0: ERROR: problem downloading dict" && exit 1 ; }
    fi
    gunzip -c $data/$(basename $lex_url) > data/local/dict_nosp/lexicon.txt
  else
    msg "$0: copying lexicon from '$lex_file'"
    cp -v $lex_file $data
    gunzip -c $data/$(basename $lex_file) > data/local/dict_nosp/lexicon.txt
  fi

  # prepare 1st pass decoding n-gram ARPA language model
  if [ -z "$lm_small_file" ] ; then
    msg "$0: downloading 3-gram 1st pass decoding LM from FalaBrasil GitLab (18M)"
    if [ -f $data/$(basename $lm_small_url) ] ; then
      echo "$0: 3-gram lm for 1st pass decoding already in place. skipping download"
    else
      wget --quiet --show-progress $lm_small_url -P $data || \
        { echo >&2 "$0: ERROR: problem downloading lm" && exit 1 ; }
    fi
    ln -rsf $data/$(basename $lm_small_url) data/local/lm/small.arpa.gz
  else
    msg "$0: copying LM small from '$lm_small_file'"
    cp -v $lm_small_file $data
    ln -rsf $data/$(basename $lm_small_file) data/local/lm/small.arpa.gz
  fi

  # prepare 2nd pass rescoring n-gram ARPA language model
  if ! $skip_rescoring ; then
    if [ -z "$lm_large_file" ] ; then
      msg "$0: downloading 4-gram 2nd pass rescoring LM from FalaBrasil GitLab (2G)"
      if [ -f $data/$(basename $lm_large_url) ] ; then
        echo "$0: 4-gram lm for 2nd pass rescoring already in place. skipping download"
      else
        wget --quiet --show-progress $lm_large_url -P $data || \
          { echo >&2 "$0: ERROR: problem downloading lm" && exit 1 ; }
      fi
      ln -rsf $data/$(basename $lm_large_url) data/local/lm/large.arpa.gz
    else
      msg "$0: copying LM large from '$lm_large_file'"
      cp -v $lm_large_file $data
      ln -rsf $data/$(basename $lm_large_file) data/local/lm/large.arpa.gz
    fi
  fi
fi

# data preparation: set up Kaldi data files: scp, text, FST, etc.
rm -f .derr
if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  msg "$0: prep data"
  prf local/prep_all_data.sh $speech_datasets_dir data || exit 1

  # stage 3 doesn't need local/lm dir
  msg "$0: prep dict"
  prf local/prep_dict.sh --nj $nj data/local/dict_nosp

  # leave as it is
  msg "$0: prep lang"
  prf utils/prepare_lang.sh \
    data/local/dict_nosp "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  msg "$0: creating G.fst from low-order ARPA LM"
  symtab=data/lang_nosp_test_small/words.txt
  if [ -f data/lang_nosp_test_small/G.fst ] ; then
    echo "$0: warn: G.fst exists. skipping compilation..."
  else
    cp -r data/lang_nosp data/lang_nosp_test_small
    gunzip -c data/local/lm/small.arpa.gz | \
      sed "s/<unk>/<UNK>/g" | \
      arpa2fst \
        --disambig-symbol=#0 \
        --read-symbol-table=$symtab \
        - data/lang_nosp_test_small/G.fst || exit 1
  fi
  utils/validate_lang.pl --skip-determinization-check data/lang_nosp_test_small

  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  # NOTE carpa generation consumes a lot of RAM
  if ! $skip_rescoring ; then
    msg "$0: creating G.carpa from high-order ARPA LM"
    symtab=data/lang_nosp_test_large/words.txt
    if [ -f data/lang_nosp_test_large/G.carpa ] ; then
      echo "$0: warn: G.carpa exists. skipping compilation..."
    else
      cp -r data/lang_nosp data/lang_nosp_test_large
      gunzip -c data/local/lm/large.arpa.gz | \
        sed "s/<unk>/<UNK>/g" | utils/map_arpa_lm.pl $symtab | \
        arpa-to-const-arpa \
          --bos-symbol=$(grep "^<s>\s"  $symtab | awk '{print $2}') \
          --eos-symbol=$(grep "^</s>\s" $symtab | awk '{print $2}') \
          --unk-symbol=$(grep "<UNK>\s" $symtab | awk '{print $2}') \
          - data/lang_nosp_test_large/G.carpa || exit 1
    fi
    # TODO no validate_lang??
  fi
fi

# mfcc extraction is cheap so we can exaggerate on the parallel jobs
if [ $stage -le 2 ]; then
  mfccdir=mfcc
  msg "$0: compute mfcc and cmvn"
  for dataset in cetuc coddef constituicao lapsbm lapsstory spoltech westpoint coraa cv vf mls mtedx ; do
    for subset in train dev test ; do
      dir=${subset}_${dataset} && [ ! -d data/$dir ] && continue
      [ -f data/$dir/feats.scp ] && \
        echo "$0: warn: feats.scp exists in $dir. skipping..." && continue
      njobs=$((nj * 2)) && [ $njobs -gt $(wc -l < data/$dir/spk2utt) ] && \
        njobs=$(wc -l < data/$dir/spk2utt)
      steps/make_mfcc.sh --nj $njobs data/$dir exp/make_mfcc/$dir $mfccdir || exit 1
      steps/compute_cmvn_stats.sh data/$dir exp/make_mfcc/$dir $mfccdir || exit 1
      utils/fix_data_dir.sh data/$dir || exit 1
    done
  done
fi

# merge/combine stuff.
# do not merge test subsets because we want to keep WER scores separated.
# also, do not rm individual train_* because experiments must be perf'ed.
if [ $stage -le 3 ]; then
  msg "$0: combine data dir"
  rm -rf data/train_all
  if $use_dev_as_train ; then
    utils/combine_data.sh data/train_all data/train_* data/dev_* || exit 1
  else
    utils/combine_data.sh data/train_all data/train_* || exit 1
  fi

  # create individual subsets for mono, tri-deltas, and tri-sat.
  # librispeech and aspire recipes have been combined almost blindly. see #8
  # TODO: check westpoint's piece of words here
  msg "$0: subset data dir"
  utils/subset_data_dir.sh --shortest data/train_all 50000 data/train_50kshort
  utils/subset_data_dir.sh data/train_50kshort 5000 data/train_5k
  utils/data/remove_dup_utts.sh 50 data/train_5k data/train_5k_nodup
  utils/subset_data_dir.sh data/train_all 10000 data/train_10k
  utils/subset_data_dir.sh data/train_all 30000 data/train_30k
fi

msg "$0: success!"
