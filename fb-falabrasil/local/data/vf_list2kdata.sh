#!/usr/bin/env bash
#
# parses a *.list file that accompanies voxforge dataset 
# into Kaldi data files such as wav.scp, text and utt2spk.
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e

[ $# -ne 2 ] && echo "usage: $0 <list-file> <data-dir>" && exit 1
list_file=$1
data_dir=$2

[ ! -f $list_file ] && echo >&2 "$0: error: bad list file: $list_file" && exit 1
mkdir -p $data_dir

i=0
corpus_dir=$(dirname $list_file)
rm -f $data_dir/{wav.scp,text,utt2spk}
while read line ; do
  wav=$corpus_dir/$line
  [ ! -f $wav ] && echo >&2 "$0: error: bad wav file: $wav" && exit 1
  wavid=$(basename ${wav%.wav})
  basedir=$(dirname $(dirname $wav))
  uttid=$(basename $basedir | sed "s/-/_/g" | awk '{print tolower($0)}')_${wavid}
  spkid=$(awk '{print tolower($0)}' $basedir/etc/README | dos2unix | \
    grep '^user name:' | cut -d':' -f2 | xargs | sed 's/-/_/g')
  [[ -z "$spkid" || "$spkid" == "anonymous" ]] && \
    spkid=$(basename $basedir | sed "s/-/_/g")
  # FIXME this is a fucking huge bottleneck because grep opens the file
  # each time it is called. Python would help with in memory processing.
  # maybe Kaldi has a pre-processing script for voxforge English already?
  text=$(grep "^$wavid" $basedir/etc/prompts-original | cut -d' ' -f2- | \
    dos2unix | sed 's/['\''«»"”?!,;:\.]//g' | awk '{print tolower($0)}' | xargs)
  echo "$uttid sox -G $wav -c1 -b16 -r16k -esigned -t wav - |" >> $data_dir/wav.scp
  echo "$uttid $spkid" >> $data_dir/utt2spk
  echo "$uttid $text" >> $data_dir/text
  i=$((i+1))
done < $list_file
sort -u $data_dir/wav.scp -o $data_dir/wav.scp
sort -u $data_dir/utt2spk -o $data_dir/utt2spk
sort -u $data_dir/text    -o $data_dir/text
utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/validate_data_dir.sh $data_dir --no-feats --non-print || exit 1
#echo "$0: success! $i audio files processed in $list_file"
