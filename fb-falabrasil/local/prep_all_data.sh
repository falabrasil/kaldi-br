#!/usr/bin/env bash
#
# call all other tailored-written data prep scripts to come out and play
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e

nj=12

[ $# -ne 2 ] && echo "usage: $0 [--nj <nj>] <corpus-dir> <data-dir>" && exit 1
corpus_dir=$1
data_dir=$2

[ ! -d $corpus_dir ] && echo "$0: error: bad dir: $corpus_dir" && exit 1

# coraa, voxforge and common voice
for subset in train dev test ; do
  [[ "$subset" == "dev" ]] && ss=valid || ss=$subset
  (local/data/coraa_csv2kdata.py \
    $corpus_dir/datasets/coraa/metadata_${subset}_final.csv \
    $data_dir/${subset}_coraa || touch .derr)&
  (local/data/cv_tsv2kdata.sh \
    $corpus_dir/datasets/cv-corpus-8.0-2022-01-19/pt/$subset.tsv \
    $data_dir/${subset}_cv || touch .derr)&
  (local/data/vf_list2kdata.sh \
    $corpus_dir/datasets/voxforge/$subset.list \
    $data_dir/${subset}_vf || touch .derr)&
  (local/data/mls2kdata.sh \
    $corpus_dir/datasets/mls/data/mls_portuguese_opus/$subset \
    $data_dir/${subset}_mls || touch .derr)&
  (local/data/mtedx2kdata.sh \
    $corpus_dir/datasets/mtedx/data/pt-pt/data/$ss \
    $data_dir/${subset}_mtedx || touch .derr)&
  sleep 0.5
  while [ $(jobs -p | wc -l) -ge $nj ] ; do sleep 10 ; done
  [ -f .derr ] && rm .derr && echo "$0: error at data prep stage" && exit 1
done

# falabrasil (the usual) 
for dataset in cetuc coddef constituicao lapsbm lapsstory spoltech westpoint ; do
  for subset in train dev test ; do
    list_file=$corpus_dir/datasets/$dataset/$subset.list
    [ ! -f $list_file ] && continue
    (local/data/fb_list2kdata.sh \
      $list_file \
      $data_dir/${subset}_${dataset} || touch .derr)&
    sleep 0.5
  done
  while [ $(jobs -p | wc -l) -ge $nj ] ; do sleep 10 ; done
  [ -f .derr ] && rm .derr && echo "$0: error at data prep stage" && exit 1
done

wait

echo "$0: success!"
