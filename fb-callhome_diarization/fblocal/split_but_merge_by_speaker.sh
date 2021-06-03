#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

nj=2
stage=0

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

trap kill_bg INT
touch .keep_running
function kill_bg() {
    rm -f .keep_running
    echo -e "\n** trapped CTRL+C"
    sleep 1
    rm -f reclist rec.* slice.*
    exit 1
}

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 3 ; then
    echo "usage: $0 <xvector-dir> <input-dir> <output-dir>"
    echo "  <xvector-dir> is the xvectors model dir"
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
    while read recspk ; do
        # recspk = rec.recId.spkId = rec.5048.002
        rec_id=$(basename $recspk | cut -d '.' -f 2)
        spk_id=$(basename $recspk | rev | cut -d '.' -f 1 | rev)
        i=0
        while read line ; do
            [ -f .keep_running ] || break
            begin=$(echo $line | awk '{print $4}')
            offset=$(echo $line | awk '{print $5}')
            end=$(echo "$begin + $offset" | bc)  # (standard_in): 1 syntax err
            infile=$in_dir/$rec_id
            outfile=$out_dir/split/$(printf "%s_%s_%04d" $rec_id $spk_id $i)
            #echo -ne "\r$infile.wav   -> $outfile.wav" >&2
            sox -G $infile.wav \
                -r 16k -b 16 -e signed-integer -t wav $outfile.wav \
                channels 1 trim $begin =$end
            i=$((i+1))
        done < $recspk
        [ -f .keep_running ] || break
        #echo
    done < $1
}

function merge_audios() {
    filelist=$1
    rec_id=$(basename $filelist | cut -d '.' -f 2)
    while read line ; do
        spk_id=$(basename $line | sed 's/rec\.//g' | cut -d '.' -f 2)
        infiles=$(find $out_dir/split/ -name "${rec_id}_${spk_id}_*.wav")
        outfile=$out_dir/${rec_id}_${spk_id}.wav
        [ -z "$infiles" ] && echo -e "\n$0: warning: ${rec_id}_${spk_id}*.wav not found" && continue
        sox $infiles $outfile
        rm rec.$rec_id.$spk_id
    done < $filelist
}

function split_progress_thread() {
    n=0
    while [ $n -lt $1 ] ; do
        [ -f .keep_running ] || break
        n=$(find $out_dir/split/ -name "*.wav" | wc -l)
        p=$(echo "100 * $n / $1" | bc)
        echo -ne "\r$0: splitting audios via sox: $n / $1 ($p%) "
        sleep 2
    done
    rm -f .keep_running
    echo
}

function merge_progress_thread() {
    n=$1
    while [ $n -gt 0 ] ; do
        [ -f .keep_running ] || break
        n=$(find . -name "rec.*" | wc -l)
        echo -ne "\r$0: merging audios via sox: $n "
        #sleep 0.1
    done
}

mkdir -p $out_dir/split/ || exit 1
rm -f rec.* slice.*

# FIXME if multiple threshs had been tested then there'll be multiple rttms
rttm=$(find $xvector_dir -name rttm 2>/dev/null)
[ -z $rttm ] && echo "$0: error: rttm not found" && exit 1

if [ $stage -le 0 ] ; then
    i=1
    n=$(wc -l < $rttm)
    # prepare data prior to splitting
    while read line ; do
        echo -ne "\r$0: splitting rttm by rec id and spk id ($i / $n)"
        rec_id=$(echo $line | awk '{print $2}')
        spk_id=$(printf "%03d" $(echo $line | awk '{print $8}'))
        echo $line >> rec.$rec_id.$spk_id
        i=$((i+1))
    done < $rttm
    echo

    # split audios
    echo -n "$0: splitting audios via sox:"
    find . -name "rec.*" | sort > reclist
    split -de -a 2 -n l/$nj reclist "slice."
    for slice in $(find . -name "slice.*" | sort) ; do
        echo -n " $(basename $slice | cut -d '.' -f 2)"
        (cut_audios $slice) &
        sleep 0.1
    done
    echo

    # wait for threads
    (split_progress_thread $n)&
    for pid in $(jobs -p) ; do
        wait $pid
    done
fi

touch .keep_running

# prepare data prior to merging
# NOTE: if you have multiple files this might overwhelm the CPUs. here we used
#       four files from callhome dataset as example and it might be fine
if [ $stage -le 1 ] ; then
    rm -f slice.*
    for rec_id in $(cat reclist | cut -d '.' -f 3 | sort | uniq) ; do
        find . -name "rec.$rec_id.*" | sort > slice.$rec_id
    done

    ns=$(find . -name "slice.*" | wc -l)
    if [ $ns -gt $nj ] ; then
        echo "$0: warning: number of rec ids greater than number of jobs."
        echo "    this may overwhelm the CPU cores a bit."
    fi

    # merge audios
    echo -n "$0: merging audios via sox"
    for slice in $(find . -name "slice.*" | sort) ; do
        #echo -n " $(basename $slice | cut -d '.' -f 2)"
        (merge_audios $slice)&
        sleep 0.1
    done

    # wait for threads
    n=$(find . -name "rec.*" | wc -l)
    (merge_progress_thread $n)&
    for pid in $(jobs -p) ; do
        wait $pid
    done
fi

echo
echo "$0: done! checkout your data at '$out_dir'"
rm -f .keep_running reclist rec.* slice.*
exit 0
