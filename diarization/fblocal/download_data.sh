#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author; Apr 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -ne 2 ; then
    echo "usage: $0 <data-dir> <corpus-url>"
    echo "  <data-dir> is the dir where data will be downloaded"
    echo "  <corpus-url> is the remote URL where the data will be fetched"
    exit 1
fi

for f in wget ; do
    if ! type -t $f > /dev/null ; then
        echo "$0: please install $f"
        exit 1
    fi
done

data_dir=$(readlink -f $1)
# CB: callhome dataset is huge we we're limit to ten files of the english part
files=( 0638 4065 4074 4077 4092 4093 4104 4112 4145 4156 )
corpus_url=$2
num_wavs=10

for f in ${files[@]} ; do
    if [ -f $data_dir/$f.wav ] ; then
        echo -ne "\r$0: '$f.wav' exists. skipping download"
    else
        echo
        wget -q --show-progress -np -nH --cut-dirs 5 -r -e robots=off \
            -R "*.html*" $corpus_url/$f.wav -P $data_dir || exit 1
    fi
done
echo

# sanity check
msg="$0: error: number of files do not match $num_wavs"
[ $(find $data_dir -name "*.wav" | wc -l) -ne $num_wavs ] && echo $msg && exit 1

exit 0
