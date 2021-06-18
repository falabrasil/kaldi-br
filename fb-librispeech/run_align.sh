#!/usr/bin/env bash
#
# performs forced alignment on both GMM and TDNN-F 
# models using Kaldi scripts
# 
# author: jun 2021
# cassio batista - https://cassota.gitlab.io

set -e 

DATA_DIR=$HOME/fb-gitlab/fb-audio-corpora/male-female-align

. cmd.sh
. path.sh
. fb_commons.sh
. utils/parse_options.sh

# NOTE: 'alignme' dir will be the new 'data' dir
mkdir -p alignme/local

# copy lexicon and lm files
cp -r data/local/dict alignme/local
cp -r data/local/lm   alignme/local

# extend lexicon
# TODO: Q: sort -u? A: will displace SIL & UNK
msg "$0: extend lex"
rm -fv alignme/local/dict/{lexiconp,lexiconp_silprob}.txt
cat data/local/dict/lexicon.txt $DATA_DIR/dict_fb.txt > dict.tmp
head -n +2 dict.tmp  > alignme/local/dict/lexicon.txt  # sil unk
tail -n +3 dict.tmp >> alignme/local/dict/lexicon.txt  # remainder

# prep lang
msg "$0: prep lang"
utils/prepare_lang.sh \
  alignme/local/dict \
  "<UNK>" \
  alignme/local/lang_tmp \
  alignme/lang

utils/validate_lang.pl --skip-determinization-chech alignme/lang

# prep data
msg "$0: prep data"
find $DATA_DIR/{male,female} -name "*.wav" | xargs readlink -f | \
  sort | sed 's/\.wav//g' | while read line ; do
    spk_id=$(sed 's/\// /g' <<< $line | awk '{print $(NF-1)}') ;
    utt_id="${spk_id}_$(basename $line)" ;
    gender=${spk_id:0:1} ;
    echo "$utt_id $(cat $line.txt)" >> alignme/text ;
    echo "$utt_id $spk_id" >> alignme/utt2spk ;
    echo "$utt_id $line.wav" >> alignme/wav.scp ;
  done

utils/utt2spk_to_spk2utt.pl alignme/utt2spk > alignme/spk2utt
utils/fix_data_dir.sh alignme 

# extract feats
msg "$0: extract mfcc feats"
rm -rf alignme_{lores,hires}
utils/copy_data_dir.sh alignme alignme_lores
utils/copy_data_dir.sh alignme alignme_hires

echo "[$0] computing low resolution features" 
steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 alignme_lores
steps/compute_cmvn_stats.sh alignme_lores
utils/fix_data_dir.sh alignme_lores

echo "[$0] computing high resolution features" 
steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 --mfcc-config conf/mfcc_hires.conf \
    alignme_hires 
steps/compute_cmvn_stats.sh alignme_hires
utils/fix_data_dir.sh alignme_hires

#####################################
### align with GMM models routine ###
#####################################

echo "[$0] align mono"
steps/align_si.sh --nj 1 --cmd "$train_cmd" \
  alignme_lores alignme/lang exp/mono alignme/results/mono_ali
for i in alignme/results/mono_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/mono/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat alignme/results/mono_ali/*.ctm > alignme/mono.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt alignme/results/mono_ali alignme/results/mono_ali

echo "[$0] align tri-deltas"
steps/align_si.sh --nj 1 --cmd "$train_cmd" \
  alignme_lores alignme/lang exp/tri1 alignme/results/tri1_ali
for i in alignme/results/tri1_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/tri1/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat alignme/results/tri1_ali/*.ctm > alignme/tri1.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt alignme/results/tri1_ali alignme/results/tri1_ali

echo "[$0] align tri-lda"
steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  alignme_lores alignme/lang exp/tri2b alignme/results/tri2b_ali
for i in alignme/results/tri2b_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/tri2b/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat alignme/results/tri2b_ali/*.ctm > alignme/tri2b.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt alignme/results/tri2b_ali alignme/results/tri2b_ali

echo "[$0] align tri-sat (1st)"
steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  alignme_lores alignme/lang exp/tri3b alignme/results/tri3b_ali
for i in alignme/results/tri3b_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/tri3b/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat alignme/results/tri3b_ali/*.ctm > alignme/tri3b.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt alignme/results/tri3b_ali alignme/results/tri3b_ali

echo "[$0] align tri-sat (2nd)"
steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  alignme_lores alignme/lang exp/tri4b alignme/results/tri4b_ali
for i in alignme/results/tri4b_ali/ali.*.gz ; do 
  ali-to-phones --ctm-output exp/tri4b/final.mdl ark:"gunzip -c $i|" - > ${i%.gz}.ctm
done
cat alignme/results/tri4b_ali/*.ctm > alignme/tri4b.phoneids.CTM  # upper case on purpose
fblocal/ctm2pts.py alignme/lang/phones.txt alignme/results/tri4b_ali alignme/results/tri4b_ali

exit 0

#############################################
### align with TDNN-F mono models routine ###
#############################################

# FIXME bad ivector_hires path!
steps/nnet3/align.sh --nj 1 --cmd "$train_cmd" --use-gpu true \
  --online-ivector-dir exp/tdnn/ivectors_hires \
  --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
  alignme_hires \
  alignme/lang \
  exp/chain/tdnn_trisat_chain_lda_ivector_fs3_sp \
  alignme/results/tdnn_trisat_chain_lda_ivector_fs3_sp_ali

###################################################
### align with TDNN-F tri-deltas models routine ###
###################################################

 echo "TBD"

################################################
### align with TDNN-F tri-sat models routine ###
################################################

 echo "TBD"
