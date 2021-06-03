#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
# 
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 4 ; then
    echo "Usage: $0 <data-dir> <model-url> <nnet-dir> <plda-dir>"
    echo "  <data-dir> is where the model will be downloaded to"
    echo "  <model-url> is the url link to fetch the model from"
    echo "  <nnet-dir> is the folder where the model will be extracted to"
    echo "  <plda-dir> is the folder where the plda will be extracted to"
    exit 1
fi

data_dir=$1
url=$2
nnet_dir=$3
plda_dir=$4

sha=f79c7aa56e3cc7e59ed1c93e447186a5ed579ca3
filename=$(basename $url)
filebase=${filename%%.*}

mkdir -p $data_dir $nnet_dir $plda_dir || exit 1
if [ -f $data_dir/$filename ] ; then
    if [ $(sha1sum $data_dir/$filename | awk '{print $1}') == $sha ] ; then
        echo "$0: file '$filename' exists under $data_dir. skipping download"
    else
        echo "$0: error: SHA 1 sum mismatch. removing file '$filename'..."
        exit 1
    fi
else
    wget -q --show-progress $url -P $data_dir || exit 1
    if [ $(sha1sum $data_dir/$filename | awk '{print $1}') != $sha ] ; then
        echo "$0: error: SHA 1 sum mismatch"
        exit 1
    fi
fi

tar -zxf $data_dir/$filename -C $data_dir
cp -r $data_dir/$filebase/$nnet_dir/* $nnet_dir  # FIXME CB: ln?
cp -r $data_dir/$filebase/$plda_dir/* $plda_dir  # FIXME CB: ln?

exit 0
