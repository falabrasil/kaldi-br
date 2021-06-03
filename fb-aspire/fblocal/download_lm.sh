#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: Apr 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 3 ; then
    echo "usage: $0 <data-dir> <lm-url> <link-dir>"
    echo "  <data-dir> is the dir where the lm will downloaded"
    echo "  <lm-url> is the remote url where the lm will be fetched"
    echo "  <link-dir> is the dir where lm will be symlinked with a special name"
    exit 1
fi

data_dir=$1
lm_url=$2
link_dir=$3

mkdir -p $data_dir || exit 1
mkdir -p $link_dir || exit 1

sha=e4062301e4c131b1f9c686b40288edab650b33c2
filename=$(basename $lm_url)
if [ ! -f $data_dir/$filename ] ; then
    wget -q --show-progress $lm_url -P $data_dir || exit 1
else
    echo "$0: file '$filename' exists under $data_dir. skipping download"
fi

if [ "$(sha1sum $data_dir/$filename | awk '{print $1}')" != $sha ] ; then
    echo "$0: error: SHA1 digest key mismatch. please redownload file"
    rm -f $data_dir/$filename
    exit 1
fi

ln -sf $(readlink -f ${data_dir}/${filename}) ${link_dir}/lm_tglarge.arpa.gz

exit 0
