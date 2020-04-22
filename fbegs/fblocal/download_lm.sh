#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author; Apr 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 3 ; then
    echo "usage: $0 <data-dir> <lm-url> <link-dir>"
    echo "  <data-dir> is the dir where the lm will downloaded"
    echo "  <lm-url> is the remote url where the lm will be fetched"
    echo "  <link-dir> is the dir where lm will be symlinked with a special name"
fi

if ! type -t wget > /dev/null ; then
    echo "$0: pleases install wget"
    exit 1
fi

data_dir=$(readlink -f $1)
lm_url=$2
link_dir=$3

filename=$(basename $lm_url)
if [ ! -f ${data_dir}/${filename} ] ; then
    wget $lm_url -P $data_dir || exit 1
    # TODO check filesize
else
    echo "$0: file '$filename' exists under $data_dir. skipping download"
fi

mkdir -p $link_dir
ln -sf ${data_dir}/${filename} ${link_dir}/lm_tglarge.arpa

exit 0
