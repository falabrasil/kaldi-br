#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

nj=2

trap kill_bg INT
touch .keep_running
function kill_bg() {
    rm -f .keep_running
    echo -e "\n** trapped CTRL+C"
    sleep 1
    exit 1
}

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 3 ; then
    echo "usage: $0 <xvector-dir> <input-dir> <output-dir>"
    echo "  <xvector-dir> is most likely "
    echo "  <input-dir> is the dir where the original data is placed"
    echo "  <output-dir> is the dir to store audio files after splitting"
    exit 1
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
        # recspk = rec.recId.spkId = rec.5048.002
        rec_id=$(basename $recspk | cut -d '.' -f 2)
        spk_id=$(basename $recspk | rev | cut -d '.' -f 1 | rev)
        while read line ; do
            [ -f .keep_running ] || break
            begin=$(echo $line | awk '{print $4}')
            offset=$(echo $line | awk '{print $5}')
            end=$(echo "$begin + $offset" | bc)  # (standard_in): 1 syntax err
            infile=$in_dir/$rec_id.wav
            outfile=$out_dir/$(printf "%s_%s_%04d" $rec_id $spk_id $i).wav
            #echo -ne "\r$infile    -> $outfile" >&2
            sox -G $infile \
                -r 16k -b 16 -e signed-integer -t wav $outfile \
                channels 1 trim $begin =$end
            i=$((i+1))
        done < $recspk
        [ -f .keep_running ] || break
        echo
    done < $1
}

mkdir -p $out_dir || exit 1
rm -f rec.* slice.*

# FIXME if multiple threshs had been tested then there'll be multiple rttms
rttm=$(find $xvector_dir -name rttm 2>/dev/null)
[ -z $rttm ] && echo "$0: error: rttm not found" && exit 1

i=1
n=$(wc -l < $rttm)
while read line ; do
    echo -ne "\r$0: splitting rttm by rec id and spk id ($i / $n)"
    rec_id=$(echo $line | awk '{print $2}')
    spk_id=$(printf "%03d" $(echo $line | awk '{print $8}'))
    echo $line >> rec.$rec_id.$spk_id
    i=$((i+1))
done < $rttm
echo

echo "$0: splitting audios via sox"
find . -name "rec.*" | sort > reclist
split -de -a 2 -n l/$nj reclist "slice."
for slice in $(find . -name "slice.*") ; do
    (cut_audios $slice) &
    sleep 0.1
done

for pid in $(jobs -p) ; do
    wait $pid
done

rm -f rec.* slice.*
exit 0
