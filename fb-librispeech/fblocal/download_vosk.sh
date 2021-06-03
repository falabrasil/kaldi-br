#!/bin/bash
#
# Grupo FalaBrasil (2021)
# Federal University of Pará (UFPA)
#
# author: june 2021
# cassio batista - https://cassota.gitlab.io/


set -e

if [ $# -ne 3 ] ; then
  echo "usage: $0 <data-dir> <model-url> <link-dir>"
  exit 1
fi

data_dir=$1
mdl_url=$2
link_dir=$3

mkdir -p $data_dir || exit 1
mkdir -p $link_dir || exit 1

filename=$(basename $mdl_url)
if [ ! -f $data_dir/$filename ] ; then
    wget -q --show-progress $mdl_url -P $data_dir || exit 1
else
    echo "$0: file '$filename' exists under $data_dir. skipping download"
fi

unzip -j $data_dir/$filename -d $link_dir
cp -v $link_dir/splice.conf $link_dir/splice_opts
