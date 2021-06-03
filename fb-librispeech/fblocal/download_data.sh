#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: Apr 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 2 ; then
    echo "usage: $0 <data-dir> <corpus-url>"
    echo "  <data-dir> is the dir where data will be downloaded"
    echo "  <corpus-url> is the remote URL where the data will be fetched"
    exit 1
fi

data_dir=$1
corpus_url=$2

num_files=700
sha=460eab24bf0f069526a64fe7fb29639d7aa6f238
filename=$(basename $corpus_url)
if [ ! -f $data_dir/$filename ] ; then
    wget -q --show-progress $corpus_url -P $data_dir || exit 1
else
    echo "$0: repo '$filename' exists under $data_dir. skipping download"
fi

if [ $(sha1sum $data_dir/$filename | awk '{print $1}') != "$sha" ] ; then
    echo "$0: error: SHA1 digest mismatch"
    exit 1
fi

tar -zxf $data_dir/$filename -C $data_dir || exit 1;

for ext in wav txt ; do
    if [ $(find $data_dir -name "*.${ext}" | wc -l) -ne $num_files ] ; then
        echo "$0: error: number of $ext files mismatch"
        exit 1
    fi
done

touch $data_dir/.done
exit 0
