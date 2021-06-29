#!/usr/bin/env bash
#
# extract CTM information from alignments in gunzip-compressed 
# files and further converts them into PTS format 
#
# author: jun 2021
# cassio batista - https://cassota.gitlab.io

set -e
RES_DIR=alignme/results
BSL_DIR=$HOME/fb-gitlab/fb-audio-corpora/male-female-aligned/scripts/ds2fb/workspace/pts_out/fb

chain=false
nnet3=false

. cmd.sh
. path.sh
. utils/parse_options.sh

if [ $# -ne 1 ] ; then
    echo "usage: $0 <am-tag>"
    echo "  e.g.: $0 tri3b"
fi

am_tag=$1

# do sanity check and set acoustic model basedir
$chain && $nnet3 && \
  echo "$0: error: gotta decide between chain & nnet3. can't do both" && exit 1
exp_dir=exp
$nnet3 && exp_dir=exp/nnet3 && echo "$0: nnet3 selected"
$chain && exp_dir=exp/chain && echo "$0: chain selected"

# creates phoneids.ctm
# NOTE: upper case extensions (e.g. CTM) are done so on purpose
for i in $RES_DIR/${am_tag}_ali/ali.*.gz ; do 
[[ "$am_tag" == *"fs3"* ]] && \
  ali-to-phones --frame-shift="0.03" --ctm-output $exp_dir/$am_tag/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.CTM || \
  ali-to-phones --ctm-output $exp_dir/$am_tag/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.CTM
done
cat $RES_DIR/${am_tag}_ali/*.CTM > alignme/$am_tag.phoneids.CTM

# separates phoneids by file
# TODO watch for slowness
while read line ; do
  utt_id=$(echo $line | awk '{print $1}')
  ctm_file=$(echo $utt_id | cut -d '_' -f 2).ctm
  #echo -ne "\r$0: extracting $ctm_file from phoneids.ctm"
  grep $utt_id alignme/$am_tag.phoneids.CTM > $RES_DIR/${am_tag}_ali/$ctm_file || echo "$0: file missing: $utt_id"
done < alignme/utt2spk
echo

# creates grapheme.ctm
steps/get_train_ctm.sh alignme alignme/lang $RES_DIR/${am_tag}_ali ctm_tmp
mv ctm_tmp/ctm alignme/$am_tag.graphemes.CTM
rm -rf ctm_tmp

# ctm2pts2pb2tol
fblocal/ctm2pts.py alignme/lang/phones.txt $RES_DIR/${am_tag}_ali $RES_DIR/${am_tag}_ali
fblocal/pts2pb.py  $BSL_DIR $RES_DIR/${am_tag}_ali M $RES_DIR/${am_tag}_ali/ali_m.pb
fblocal/pts2pb.py  $BSL_DIR $RES_DIR/${am_tag}_ali F $RES_DIR/${am_tag}_ali/ali_f.pb
fblocal/pb2tol.py  $RES_DIR/${am_tag}_ali/ali_{m,f}.pb | tee $RES_DIR/${am_tag}_ali/ali.tol
