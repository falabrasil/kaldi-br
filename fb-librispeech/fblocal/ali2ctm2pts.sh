#!/usr/bin/env bash
#
# extract CTM information from alignments in gunzip-compressed 
#files and further converts them into PTS format 
#
# author: jun 2021
# cassio batista - https://cassota.gitlab.io

set -e
RES_DIR=alignme/results

if [ $# -ne 1 ] ; then
    echo "usage: $0 <am-tag>"
    echo "  e.g.: $0 tri3b"
fi

am_tag=$1

# creates phoneids.ctm
for i in $RES_DIR/${am_tag}_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/$am_tag/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat $RES_DIR/${am_tag}_ali/*.ctm > alignme/$am_tag.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt $RES_DIR/${am_tag}_ali $RES_DIR/${am_tag}_ali

# separates phoneids by file
# TODO watch for slowness
while read line ; do
  utt_id=$(echo $line | awk '{print $1}')
  ctm_file=$(echo $utt_id | cut -d '_' -f 2).ctm
  echo -ne "\r$0: extracting $ctm_file from phoneids.ctm"
  grep $utt_id alignme/$am_tag.phoneids.CTM > $RES_DIR/${am_tag}_ali/$ctm_file
done < alignme/utt2spk
echo

# creates grapheme.ctm
steps/get_train_ctm.sh alignme alignme/lang $RES_DIR/${am_tag}_ali ctm_tmp
mv ctm_tmp/ctm alignme/$am_tag.graphemes.CTM
rm -rf ctm_tmp
