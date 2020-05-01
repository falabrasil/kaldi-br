#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

nj=2

# FIXME FIXME FIXME THIS FUCKING SHIT IS NOT KILLING THE BG PROCESS SOX KEEPS
# RUNNING EVERLASTINGLY
trap kill_bg INT
function kill_bg() {
    echo "** trapped CTRL+C"
    for pid in $(jobs -p) ; do
        echo "$0: killing $pid"
        kill -9 -$pid
    done
}

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 3 ; then
    echo "usage: $0 <xvector-dir> <input-dir> <output-dir>"
    echo "  <xvector-dir> is most likely "
    echo "  <input-dir> is the dir where the original data is placed"
    echo "  <output-dir> is the dir to store audio files after splitting"
elif [ ! -d $1 ] || [ ! -d $2 ] ; then
    echo "$0 error: '$1' and '$2' should both exist as dirs."
    exit 1
fi

xvector_dir=$1
in_dir=$2
out_dir=$3

function cut_audios() {
    i=0
    while read recspk ; do
        rec_id=$(basename $recspk | cut -d '.' -f 2)
        spk_id=$(basename $recspk | rev | cut -d '.' -f 1 | rev)
        while read line ; do
            begin=$(echo $line | awk '{print $4}')
            offset=$(echo $line | awk '{print $5}')
            end=$(echo "$begin + $offset" | bc)
            infile=$in_dir/$rec_id.wav
            outfile=$out_dir/$(printf "%s_%02d_%04d" $rec_id $spk_id $i).wav
            echo -ne "\r$infile    -> $outfile" >&2
            #sox -G $infile \
            #    -r 16k -b 16 -e signed-integer -t wav $outfile \
            #    channels 1 trim $begin =$end
            #i=$((i+1))
        done < $recspk
        echo
    done < $1
}

mkdir -p $out_dir || exit 1
rm -f rec.* *.slice

rttm=$(find $xvector_dir -name rttm 2>/dev/null)
[ -z $rttm ] && echo "$0: error: rttm not found" && exit 1

# rttm2recId
for rec_id in $(awk '{print $2}' $rttm | sort | uniq) ; do
    grep -w $rec_id $rttm > rec.$rec_id
done

# recId2spkId
for rec in $(find . -name "rec.*") ; do
    for spk_id in $(awk '{print $8}' $rec | sort | uniq) ; do
        grep -w " $spk_id " $rec | sort > $rec.$spk_id
    done
    rm $rec
done

find . -name "rec.*" > reclist
split -de -a 2 -n l/$nj --additional-suffix ".slice" reclist
for slice in $(find . -name "*.slice") ; do
    (cut_audios $slice)&
    sleep 0.5
done

for pid in $(jobs -p) ; do
    wait $pid
done

rm -f rec.* *.slice
exit 0
