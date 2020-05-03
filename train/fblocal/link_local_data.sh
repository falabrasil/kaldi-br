#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/
#
# https://stackoverflow.com/questions/12061410/how-to-replace-a-path-with-another-path-in-sed

nj=4
exclude_dirs="tedx-|male-|fsd-|dectalk|speechcommands|base_Anderson"

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 2 ; then
    echo "usage: $0 <data-src-dir> <data-dst-dir>"
    echo "  <data-src-dir> is the dir where data will be linked from"
    echo "  <data-dst-dir> is the dir where data will be linked to"
    exit 1
elif [ ! -d $1 ] ; then
    echo "$0: error: '$1' must be a dir."
    exit 1
fi

src=$(readlink -f $1)
dst=$(readlink -f $2)

[ -f $dst/.done ] && echo "$0: data seem to be in place. skipping" && exit 0

function create_dirs() {
    src=$1
    dst=$2
    filelist=$3
    while read line ; do
        mkdir -p $line
    done <<< $(cat $filelist | sed "s#${src}#${dst}#g")
}

function link_data() {
    src=$1
    dst=$2
    filelist=$3
    while read line ; do
        ln -sf ${line}.wav $(echo $line | sed "s#${src}#${dst}#g").wav
        ln -sf ${line}.txt $(echo $line | sed "s#${src}#${dst}#g").txt
    done < $filelist
}

# find $src -not -path '*/\.*' -type d -links 2
find $src -name "*.wav" | egrep -v "$exclude_dirs" | sed 's/\.wav//g' > filelist.tmp
cat filelist.tmp | xargs dirname | sort | uniq > dirlist.tmp

split -de -a 3 -n l/${nj} dirlist.tmp "slice."
echo -n "$0: creating subdirs:"
for i in $(seq -f "%03g" 0 $((nj-1))); do
    echo -n " $i"
    ( create_dirs $src $dst slice.${i} ) &
done
echo

for pid in $(jobs -p) ; do
    wait $pid
done

split -de -a 3 -n l/${nj} filelist.tmp "slice."
echo -n "$0: symlinking dataset:"
for i in $(seq -f "%03g" 0 $((nj-1))); do
    echo -n " $i"
    ( link_data $src $dst slice.${i} ) &
done
echo

for pid in $(jobs -p) ; do
    wait $pid
done

rm *.tmp slice.*
touch $dst/.done
exit 0
