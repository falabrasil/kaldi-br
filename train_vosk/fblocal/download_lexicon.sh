#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author; may 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 3 ; then
    echo "usage: $0 <data-dir> <lex-url>"
    echo "  <data-dir> is the dir where the lexicon will be downloaded to"
    echo "  <lex-url> is the remote url where the lexicon will be fetched from"
    echo "  <link-dir> is the dir where lm will be symlinked with a special name"
    exit 1
fi

data_dir=$1
lex_url=$2
link_dir=$3

mkdir -p $data_dir || exit 1
mkdir -p $link_dir || exit 1

sha=7c2218556522b8f1f05d4d28bd436edfdc3ca268
filename=$(basename $lex_url)
if [ ! -f $data_dir/$filename ] ; then
    wget -q --show-progress $lex_url -P $data_dir || exit 1
else
    echo "$0: file '$filename' exists under $data_dir. skipping download"
fi

if [ "$(sha1sum $data_dir/$filename | awk '{print $1}')" != $sha ] ; then
    echo "$0: error: SHA1 digest key mismatch. please redownload file"
    rm -f $data_dir/$filename
    exit 1
fi

gzip -cd $data_dir/$filename > $link_dir/lexicon.txt

exit 0
