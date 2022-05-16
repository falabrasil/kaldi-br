#!/usr/bin/env bash
#
# parses a *.list file that accompanies voxforge dataset 
# into Kaldi data files such as wav.scp, text and utt2spk.
#
# NOTE: esse deu trabalho hein pita que parou
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

set -e

[ $# -ne 2 ] && echo "usage: $0 <list-file> <data-dir>" && exit 1
list_file=$1
data_dir=$2

[ ! -f $list_file ] && echo >&2 "$0: error: bad list file: $list_file" && exit 1
mkdir -p $data_dir

export LC_ALL=pt_BR.utf8

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
  ## kaldi's voxforge recipe maps all anon speakers to a single id
  #[[ -z "$spkid" || "$spkid" == "anonymous" ]] && \
  [[ -z "$spkid" ]] && spkid=$(basename $basedir | sed "s/-/_/g")
  # forced gambiarra: see post-credits
  [[ "$uttid" == "pt_pedro_loures"* && "$spkid" == "pedro_loures"* ]] && \
    spkid=$(echo $spkid | sed "s/pedro_loures/pt_pedro_loures/g")
  [[ "$uttid" == "pt_anony"* && "$spkid" == "anony"* ]] && \
    spkid=$(echo $spkid | sed "s/anony/pt_anony/g")
  [[ "$uttid" == "anony"* && "$spkid" == "pt_anony"* ]] && \
    uttid=$(echo $uttid | sed "s/anony/pt_anony/g")
  # if the last char of the first field of the id isn't a digit, append a zero.
  # this helps sort down the line in speaker ids like 'a' and 'a2',
  # which turn out to be in wrong order in utt2spk and don't get validated.
  false && echo -n "$uttid $spkid -> "
  [[ ! "$(echo $uttid | cut -d'_' -f1)" =~ ^(*[0-9])$ ]] && \
    uttid="$(echo $uttid | cut -d'_' -f1)0_$(echo $uttid | cut -d'_' -f2-)" && \
    spkid="$(echo $spkid | cut -d'_' -f1)0_$(echo $spkid | cut -d'_' -f2-)"
  false && echo "$uttid $spkid"
  # FIXME this is a fucking huge bottleneck because grep opens the file
  # each time it is called. Python would help with in memory processing.
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
#sort -k1 -u $data_dir/utt2spk | sort -k2 -o dummy && \
#  mv dummy $data_dir/utt2spk  # you'd never guess this huh
utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt
utils/fix_data_dir.sh $data_dir
utils/validate_data_dir.sh --no-feats --non-print $data_dir || exit 1
#utils/fix_data_dir.sh $data_dir
#echo "$0: success! $i audio files processed in $list_file"

## marvel post credits exposes pedro loures and some anonymours
#while read line ; do
#  uttid=$(echo $line | cut -d' ' -f1)
#  spkid=$(echo $line | cut -d' ' -f2)
#  uttid=$(echo $uttid | cut -d'_' -f1)
#  spkid=$(echo $spkid | cut -d'_' -f1)
#  [[ "$uttid" != "$spkid" ]] && echo "$0: error: $line"
#done < data/train_vf/utt2spk
