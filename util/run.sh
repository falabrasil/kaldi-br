#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Ter Jan 22 15:34:14 -03 2019
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Ter Nov  6 14:11:05 -03 2018
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

. ./path.sh || exit 1
. ./cmd.sh || exit 1

nj=2      # number of parallel jobs 
lm_order=3 # language model order (n-gram quantity)

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1

#DNN parameters 
minibatch_size=512
num_epochs=8 
num_epochs_extra=5 
num_hidden_layers=2
initial_learning_rate=0.02 
final_learning_rate=0.004
#pnorm_input_dim=300 
#pnorm_output_dim=3000

#DNN parameters for small data
pnorm_input_dim=1000 
pnorm_output_dim=200



# Removing previously created data (from last run.sh execution)
rm -rf exp mfcc data/train/spk2utt data/train/cmvn.scp data/train/feats.scp data/train/split12 data/test/spk2utt data/test/cmvn.scp data/test/feats.scp data/test/split12 data/local/lang data/lang data/local/tmp data/local/dict/lexiconp.txt

echo
echo "===== PREPARING ACOUSTIC DATA ====="
echo

# Needs to be prepared by hand (or using self written scripts):
#
# spk2gender  [<speaker-id> <gender>]
# wav.scp     [<uterranceID> <full_path_to_audio_file>]
# text        [<uterranceID> <text_transcription>]
# utt2spk     [<uterranceID> <speakerID>]
# corpus.txt  [<text_transcription>]

# Making spk2utt files
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

echo
echo "===== FEATURES EXTRACTION ====="
echo

# Making feats.scp files
mfccdir=mfcc

utils/validate_data_dir.sh data/train     # script for checking prepared data - here: for data/train directory
utils/fix_data_dir.sh data/train          # tool for data proper sorting if needed - here: for data/train directory
utils/validate_data_dir.sh data/test     # script for checking prepared data - here: for data/test directory
utils/fix_data_dir.sh data/test          # tool for data proper sorting if needed - here: for data/test directory
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir
steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir

# Making cmvn.scp files
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

echo
echo "===== PREPARING LANGUAGE DATA ====="
echo

# Needs to be prepared by hand (or using self written scripts):
#
# lexicon.txt           [<word> <phone 1> <phone 2> ...]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]
# optional_silence.txt  [<phone>]

# Preparing language data
utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang

echo
echo "===== LANGUAGE MODEL CREATION ====="
echo "===== MAKING lm.arpa ====="
echo

loc=`which ngram-count`;
if [ -z $loc ]; then
	if uname -a | grep 64 >/dev/null; then
		sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
	else
		sdir=$KALDI_ROOT/tools/srilm/bin/i686
	fi
	if [ -f $sdir/ngram-count ]; then
		echo "Using SRILM language modelling tool from $sdir"
		export PATH=$PATH:$sdir
	else
		echo "SRILM toolkit is probably not installed.
				Instructions: tools/install_srilm.sh"
		exit 1
   fi
fi

cat data/train/corpus.txt data/test/corpus.txt > data/local/corpus.txt

local=data/local
mkdir $local/tmp
ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount -text $local/corpus.txt -lm $local/tmp/lm.arpa

echo
echo "===== MAKING G.fst ====="
echo

lang=data/lang
arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang/words.txt $local/tmp/lm.arpa $lang/G.fst


echo
echo "============== MONOPHONE =============="
echo

echo
echo "===== MONO TRAINING ====="
echo
steps/train_mono.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono  || exit 1


echo
echo "===== MONO DECODING ====="
echo

utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode

echo
echo "===== MONO ALIGMENT ====="
echo

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono exp/mono_ali || exit 1



echo
echo "===== GETTING MONOPHONE RESULTS ====="
echo

echo "====== MONOPHONE ======" >> RESULTS
for x in exp/mono*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
echo >> RESULTS


echo
echo "============== TRIPHONE 1 (first triphone pass) DELTA FEATURES =============="
echo


echo
echo "===== TRI1 500 TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 500 1000 data/train data/lang exp/mono_ali exp/tri1_500-2 || exit 1

echo ‘finished training tri1_500-2’ >> log

  
steps/train_deltas.sh --cmd "$train_cmd" 500 2000 data/train data/lang exp/mono_ali exp/tri1_500-4 || exit 1 

echo ‘finished training tri1_500-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 500 4000 data/train data/lang exp/mono_ali exp/tri1_500-8 || exit 1

echo ‘finished training tri1_500-8’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 500 8000 data/train data/lang exp/mono_ali exp/tri1_500-16 || exit 1

echo ‘finished training tri1_500-16’ >> log



echo
echo "===== TRI1 500 DECODING====="
echo

utils/mkgraph.sh data/lang exp/tri1_500-2 exp/tri1_500-2/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_500-2/graph data/test exp/tri1_500-2/decode

echo ‘finished decoding tri1_500-2’ >> log

  
utils/mkgraph.sh data/lang exp/tri1_500-4 exp/tri1_500-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_500-4/graph data/test exp/tri1_500-4/decode 

echo ‘finished decoding tri1_500-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_500-8 exp/tri1_500-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_500-8/graph data/test exp/tri1_500-8/decode

echo ‘finished decoding tri1_500-8’ >> log

 
utils/mkgraph.sh data/lang exp/tri1_500-16 exp/tri1_500-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_500-16/graph data/test exp/tri1_500-16/decode

echo ‘finished decoding tri1_500-16’ >> log




echo
echo "===== TRI1 1K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 1000 2000 data/train data/lang exp/mono_ali exp/tri1_1k-2 || exit 1

echo ‘finished training tri1_1k-2’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 1000 4000 data/train data/lang exp/mono_ali exp/tri1_1k-4 || exit 1

echo ‘finished training tri1_1k-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 1000 8000 data/train data/lang exp/mono_ali exp/tri1_1k-8 || exit 1

echo ‘finished training tri1_1k-8’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 1000 16000 data/train data/lang exp/mono_ali exp/tri1_1k-16 || exit 1

echo ‘finished training tri1_1k-16’ >> log


echo
echo "===== TRI1 1K DECODING====="
echo

utils/mkgraph.sh data/lang exp/tri1_1k-2 exp/tri1_1k-2/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_1k-2/graph data/test exp/tri1_1k-2/decode 

echo ‘finished decoding tri1_1k-2’ >> log


utils/mkgraph.sh data/lang exp/tri1_1k-4 exp/tri1_1k-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_1k-4/graph data/test exp/tri1_1k-4/decode 

echo ‘finished decoding tri1_1k-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_1k-8 exp/tri1_1k-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_1k-8/graph data/test exp/tri1_1k-8/decode  

echo ‘finished decoding tri1_1k-8’ >> log


utils/mkgraph.sh data/lang exp/tri1_1k-16 exp/tri1_1k-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_1k-16/graph data/test exp/tri1_1k-16/decode

echo ‘finished decoding tri1_1k-16’ >> log



echo
echo "===== TRI1 2K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 2000 4000 data/train data/lang exp/mono_ali exp/tri1_2k-2 || exit 1

echo ‘finished training tri1_2k-2’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 2000 8000 data/train data/lang exp/mono_ali exp/tri1_2k-4 || exit 1

echo ‘finished training tri1_2k-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 2000 16000 data/train data/lang exp/mono_ali exp/tri1_2k-8 || exit 1

echo ‘finished training tri1_2k-8’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 2000 32000 data/train data/lang exp/mono_ali exp/tri1_2k-16 || exit 1

echo ‘finished training tri1_2k-16’ >> log

echo
echo "===== TRI1 2K DECODING====="
echo


utils/mkgraph.sh data/lang exp/tri1_2k-2 exp/tri1_2k-2/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_2k-2/graph data/test exp/tri1_2k-2/decode

echo ‘finished decoding tri1_2k-2’ >> log


utils/mkgraph.sh data/lang exp/tri1_2k-4 exp/tri1_2k-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_2k-4/graph data/test exp/tri1_2k-4/decode

echo ‘finished decoding tri1_2k-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_2k-8 exp/tri1_2k-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_2k-8/graph data/test exp/tri1_2k-8/decode

echo ‘finished decoding tri1_2k-8’ >> log


utils/mkgraph.sh data/lang exp/tri1_2k-16 exp/tri1_2k-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_2k-16/graph data/test exp/tri1_2k-16/decode

echo ‘finished decoding tri1_2k-16’ >> log




echo
echo "===== TRI1 4K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 4000 8000 data/train data/lang exp/mono_ali exp/tri1_4k-2 || exit 1

echo ‘finished training tri1_4k-2’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 4000 16000 data/train data/lang exp/mono_ali exp/tri1_4k-4 || exit 1

echo ‘finished training tri1_4k-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 4000 32000 data/train data/lang exp/mono_ali exp/tri1_4k-8 || exit 1

echo ‘finished training tri1_4k-8’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 4000 64000 data/train data/lang exp/mono_ali exp/tri1_4k-16 || exit 1

echo ‘finished training tri1_4k-16’ >> log



echo
echo "===== TRI1 4K DECODING====="
echo


utils/mkgraph.sh data/lang exp/tri1_4k-2 exp/tri1_4k-2/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_4k-2/graph data/test exp/tri1_4k-2/decode

echo ‘finished decoding tri1_4k-2’ >> log


utils/mkgraph.sh data/lang exp/tri1_4k-4 exp/tri1_4k-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_4k-4/graph data/test exp/tri1_4k-4/decode

echo ‘finished decoding tri1_4k-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_4k-8 exp/tri1_4k-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_4k-8/graph data/test exp/tri1_4k-8/decode

echo ‘finished decoding tri1_4k-8’ >> log


utils/mkgraph.sh data/lang exp/tri1_4k-16 exp/tri1_4k-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_4k-16/graph data/test exp/tri1_4k-16/decode

echo ‘finished decoding tri1_4k-16’ >> log



echo
echo "===== TRI1 6K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 6000 12000 data/train data/lang exp/mono_ali exp/tri1_6k-2 || exit 1

echo ‘finished training tri1_6k-2’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 6000 24000 data/train data/lang exp/mono_ali exp/tri1_6k-4 || exit 1

echo ‘finished training tri1_6k-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 6000 48000 data/train data/lang exp/mono_ali exp/tri1_6k-8 || exit 1

echo ‘finished training tri1_6k-8’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 6000 96000 data/train data/lang exp/mono_ali exp/tri1_6k-16 || exit 1

echo ‘finished training tri1_6k-16’ >> log



echo
echo "===== TRI1 6K DECODING====="
echo


utils/mkgraph.sh data/lang exp/tri1_6k-2 exp/tri1_6k-2/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_6k-2/graph data/test exp/tri1_6k-2/decode

echo ‘finished decoding tri1_6k-2’ >> log


utils/mkgraph.sh data/lang exp/tri1_6k-4 exp/tri1_6k-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_6k-4/graph data/test exp/tri1_6k-4/decode

echo ‘finished decoding tri1_6k-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_6k-8 exp/tri1_6k-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_6k-8/graph data/test exp/tri1_6k-8/decode

echo ‘finished decoding tri1_6k-8’ >> log


utils/mkgraph.sh data/lang exp/tri1_6k-16 exp/tri1_6k-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_6k-16/graph data/test exp/tri1_6k-16/decode

echo ‘finished decoding tri1_6k-16’ >> log




echo
echo "===== TRI1 8K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 8000 16000 data/train data/lang exp/mono_ali exp/tri1_8k-2 || exit 1

echo ‘finished training tri1_8k-2’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 8000 32000 data/train data/lang exp/mono_ali exp/tri1_8k-4 || exit 1

echo ‘finished training tri1_8k-4’ >> log


steps/train_deltas.sh --cmd "$train_cmd" 8000 64000 data/train data/lang exp/mono_ali exp/tri1_8k-8 || exit 1

echo ‘finished training tri1_8k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 8000 128000 data/train data/lang exp/mono_ali exp/tri1_8k-16 || exit 1

echo ‘finished training tri1_8k-16’ >> log




echo
echo "===== TRI1 8K DECODING====="
echo


utils/mkgraph.sh data/lang exp/tri1_8k-2 exp/tri1_8k-2/graph || exit 1 

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_8k-2/graph data/test exp/tri1_8k-2/decode

echo ‘finished decoding tri1_8k-2’ >> log


utils/mkgraph.sh data/lang exp/tri1_8k-4 exp/tri1_8k-4/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_8k-4/graph data/test exp/tri1_8k-4/decode

echo ‘finished decoding tri1_8k-4’ >> log


utils/mkgraph.sh data/lang exp/tri1_8k-8 exp/tri1_8k-8/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_8k-8/graph data/test exp/tri1_8k-8/decode

echo ‘finished decoding tri1_8k-8’ >> log


utils/mkgraph.sh data/lang exp/tri1_8k-16 exp/tri1_8k-16/graph || exit 1

steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1_8k-16/graph data/test exp/tri1_8k-16/decode

echo ‘finished decoding tri1_8k-16’ >> log


echo                                                                                                                                                       
echo "===== TRI1(first triphone pass) DELTA FEATURES ALIGNMENT ====="
echo




echo
echo "===== TRI1 500 ALIGMENT ====="
echo

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_500-2 exp/tri1_500-2_ali

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_500-4 exp/tri1_500-4_ali

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_500-8 exp/tri1_500-8_ali

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_500-16 exp/tri1_500-16_ali

echo ‘aligned tri1_500’ >> log



echo
echo "===== TRI1 1k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_1k-2 exp/tri1_1k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_1k-4 exp/tri1_1k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_1k-8 exp/tri1_1k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_1k-16 exp/tri1_1k-16_ali
echo ‘aligned tri1_1k’ >> log

echo
echo "===== TRI1 2k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_2k-2 exp/tri1_2k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_2k-4 exp/tri1_2k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_2k-8 exp/tri1_2k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_2k-16 exp/tri1_2k-16_ali
echo ‘aligned tri1_2k’ >> log

echo
echo "===== TRI1 4k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_4k-2 exp/tri1_4k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_4k-4 exp/tri1_4k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_4k-8 exp/tri1_4k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_4k-16 exp/tri1_4k-16_ali
echo ‘aligned tri1_4k’ >> log

echo
echo "===== TRI1 6k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_6k-2 exp/tri1_6k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_6k-4 exp/tri1_6k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_6k-8 exp/tri1_6k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_6k-16 exp/tri1_6k-16_ali
echo ‘aligned tri1_6k’ >> log

echo
echo "===== TRI1 8k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_8k-2 exp/tri1_8k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_8k-4 exp/tri1_8k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_8k-8 exp/tri1_8k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1_8k-16 exp/tri1_8k-16_ali
echo ‘aligned tri1_8k’ >> log

echo
echo "===== GETTING TRI1 (DELTA FEATURES) RESULTS ====="
echo

echo "====== TRI1 (DELTA FEATURES) ======" >> RESULTS
for x in exp/tri1_*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
echo >> RESULTS

echo
echo "============== TRIPHONE 2 (delta + delta-delta) =============="
echo

echo
echo "===== TRI2 500 TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 500 1000 data/train data/lang exp/tri1_500-2_ali exp/tri2_500-2 || exit 1  
echo ‘finished training tri2_500-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 500 2000 data/train data/lang exp/tri1_500-4_ali exp/tri2_500-4 || exit 1  
echo ‘finished training tri2_500-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 500 4000 data/train data/lang exp/tri1_500-8_ali exp/tri2_500-8 || exit 1  
echo ‘finished training tri2_500-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 500 8000 data/train data/lang exp/tri1_500-16_ali exp/tri2_500-16 || exit 1 
echo ‘finished training tri2_500-16’ >> log


echo
echo "===== TRI2 500 DECODING====="
echo

utils/mkgraph.sh data/lang exp/tri2_500-2 exp/tri2_500-2/graph || exit 1 
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_500-2/graph data/test exp/tri2_500-2/decode
echo ‘finished decoding tri2_500-2’ >> log

utils/mkgraph.sh data/lang exp/tri2_500-4 exp/tri2_500-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_500-4/graph data/test exp/tri2_500-4/decode  
echo ‘finished decoding tri2_500-4’ >> log

utils/mkgraph.sh data/lang exp/tri2_500-8 exp/tri2_500-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_500-8/graph data/test exp/tri2_500-8/decode 
echo ‘finished decoding tri2_500-8’ >> log

utils/mkgraph.sh data/lang exp/tri2_500-16 exp/tri2_500-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_500-16/graph data/test exp/tri2_500-16/decode
echo ‘finished decoding tri2_500-16’ >> log

echo
echo "===== TRI2 1K TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 1000 2000 data/train data/lang exp/tri1_1k-2_ali exp/tri2_1k-2 || exit 1 
echo ‘finished training tri2_1k-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 1000 4000 data/train data/lang exp/tri1_1k-4_ali exp/tri2_1k-4 || exit 1
echo ‘finished training tri2_1k-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 1000 8000 data/train data/lang exp/tri1_1k-8_ali exp/tri2_1k-8 || exit 1 
echo ‘finished training tri2_1k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 1000 16000 data/train data/lang exp/tri1_1k-16_ali exp/tri2_1k-16 || exit 1 
echo ‘finished training tri2_1k-16’ >> log


echo
echo "===== TRI2 1K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri2_1k-2 exp/tri2_1k-2/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_1k-2/graph data/test exp/tri2_1k-2/decode   
echo ‘finished decoding tri2_1k-2’ >> log

utils/mkgraph.sh data/lang exp/tri2_1k-4 exp/tri2_1k-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_1k-4/graph data/test exp/tri2_1k-4/decode  
echo ‘finished decoding tri2_1k-4’ >> log 

utils/mkgraph.sh data/lang exp/tri2_1k-8 exp/tri2_1k-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_1k-8/graph data/test exp/tri2_1k-8/decode   
echo ‘finished decoding tri2_1k-8’ >> log

utils/mkgraph.sh data/lang exp/tri2_1k-16 exp/tri2_1k-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_1k-16/graph data/test exp/tri2_1k-16/decode
echo ‘finished decoding tri2_1k-16’ >> log

echo
echo "===== TRI2 2K TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" 2000 4000 data/train data/lang exp/tri1_2k-2_ali exp/tri2_2k-2 || exit 1 
echo ‘finished training tri2_2k-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 2000 8000 data/train data/lang exp/tri1_2k-4_ali exp/tri2_2k-4 || exit 1  
echo ‘finished training tri2_2k-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 2000 16000 data/train data/lang exp/tri1_2k-8_ali exp/tri2_2k-8 || exit 1  
echo ‘finished training tri2_2k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 2000 32000 data/train data/lang exp/tri1_2k-16_ali exp/tri2_2k-16 || exit 1
echo ‘finished training tri2_2k-16’ >> log

echo
echo "===== TRI2 2K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri2_2k-2 exp/tri2_2k-2/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_2k-2/graph data/test exp/tri2_2k-2/decode   
echo ‘finished decoding tri2_2k-2’ >> log


utils/mkgraph.sh data/lang exp/tri2_2k-4 exp/tri2_2k-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_2k-4/graph data/test exp/tri2_2k-4/decode  
echo ‘finished decoding tri2_2k-4’ >> log

utils/mkgraph.sh data/lang exp/tri2_2k-8 exp/tri2_2k-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_2k-8/graph data/test exp/tri2_2k-8/decode   
echo ‘finished decoding tri2_2k-8’ >> log

utils/mkgraph.sh data/lang exp/tri2_2k-16 exp/tri2_2k-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_2k-16/graph data/test exp/tri2_2k-16/decode
echo ‘finished decoding tri2_2k-16’ >> log

echo
echo "===== TRI2 4K TRAINING  ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 4000 8000 data/train data/lang exp/tri1_4k-2_ali exp/tri2_4k-2 || exit 1 
echo ‘finished training tri2_4k-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 4000 16000 data/train data/lang exp/tri1_4k-4_ali exp/tri2_4k-4 || exit 1 
echo ‘finished training tri2_4k-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 4000 32000 data/train data/lang exp/tri1_4k-8_ali exp/tri2_4k-8 || exit 1 
echo ‘finished training tri2_4k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 4000 64000 data/train data/lang exp/tri1_4k-16_ali exp/tri2_4k-16 || exit 1
echo ‘finished training tri2_4k-16’ >> log

echo
echo "===== TRI2 4K DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri2_4k-2 exp/tri2_4k-2/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_4k-2/graph data/test exp/tri2_4k-2/decode   
echo ‘finished decoding tri2_4k-2’ >> log

utils/mkgraph.sh data/lang exp/tri2_4k-4 exp/tri2_4k-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_4k-4/graph data/test exp/tri2_4k-4/decode   
echo ‘finished decoding tri2_4k-4’ >> log

utils/mkgraph.sh data/lang exp/tri2_4k-8 exp/tri2_4k-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_4k-8/graph data/test exp/tri2_4k-8/decode  
echo ‘finished decoding tri2_4k-8’ >> log

utils/mkgraph.sh data/lang exp/tri2_4k-16 exp/tri2_4k-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_4k-16/graph data/test exp/tri2_4k-16/decode
echo ‘finished decoding tri2_4k-16’ >> log

echo
echo "===== TRI2 6K TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 6000 12000 data/train data/lang exp/tri1_6k-2_ali exp/tri2_6k-2 || exit 1 
echo ‘finished training tri2_6k-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 6000 24000 data/train data/lang exp/tri1_6k-4_ali exp/tri2_6k-4 || exit 1 
echo ‘finished training tri2_6k-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 6000 48000 data/train data/lang exp/tri1_6k-8_ali exp/tri2_6k-8 || exit 1 
echo ‘finished training tri2_6k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 6000 96000 data/train data/lang exp/tri1_6k-16_ali exp/tri2_6k-16 || exit 1
echo ‘finished training tri2_6k-16’ >> log

echo
echo "===== TRI2 6K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri2_6k-2 exp/tri2_6k-2/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_6k-2/graph data/test exp/tri2_6k-2/decode  
echo ‘finished decoding tri2_6k-2’ >> log

utils/mkgraph.sh data/lang exp/tri2_6k-4 exp/tri2_6k-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_6k-4/graph data/test exp/tri2_6k-4/decode   
echo ‘finished decoding tri2_6k-4’ >> log

utils/mkgraph.sh data/lang exp/tri2_6k-8 exp/tri2_6k-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_6k-8/graph data/test exp/tri2_6k-8/decode  
echo ‘finished decoding tri2_6k-8’ >> log 

utils/mkgraph.sh data/lang exp/tri2_6k-16 exp/tri2_6k-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_6k-16/graph data/test exp/tri2_6k-16/decode
echo ‘finished decoding tri2_6k-16’ >> log

echo
echo "===== TRI2 8K TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 8000 16000 data/train data/lang exp/tri1_8k-2_ali exp/tri2_8k-2 || exit 1 
echo ‘finished training tri2_8k-2’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 8000 32000 data/train data/lang exp/tri1_8k-4_ali exp/tri2_8k-4 || exit 1 
echo ‘finished training tri2_8k-4’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 8000 64000 data/train data/lang exp/tri1_8k-8_ali exp/tri2_8k-8 || exit 1 
echo ‘finished training tri2_8k-8’ >> log

steps/train_deltas.sh --cmd "$train_cmd" 8000 128000 data/train data/lang exp/tri1_8k-16_ali exp/tri2_8k-16 || exit 1
echo ‘finished training tri2_8k-16’ >> log

echo
echo "===== TRI2 8K DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri2_8k-2 exp/tri2_8k-2/graph || exit 1 
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_8k-2/graph data/test exp/tri2_8k-2/decode 
echo ‘finished decoding tri2_8k-2’ >> log  

utils/mkgraph.sh data/lang exp/tri2_8k-4 exp/tri2_8k-4/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_8k-4/graph data/test exp/tri2_8k-4/decode
echo ‘finished decoding tri2_8k-4’ >> log

utils/mkgraph.sh data/lang exp/tri2_8k-8 exp/tri2_8k-8/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_8k-8/graph data/test exp/tri2_8k-8/decode
echo ‘finished decoding tri2_8k-8’ >> log

utils/mkgraph.sh data/lang exp/tri2_8k-16 exp/tri2_8k-16/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2_8k-16/graph data/test exp/tri2_8k-16/decode
echo ‘finished decoding tri2_8k-16’ >> log

echo                                                                                                                                                       
echo "===== TRI2 (delta + delta-delta) ALIGNMENT ====="
echo

echo
echo "===== TRI2 500 ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_500-2 exp/tri2_500-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_500-4 exp/tri2_500-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_500-8 exp/tri2_500-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_500-16 exp/tri2_500-16_ali
echo ‘aligned tri2_500’ >> log

echo
echo "===== TRI2 1k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_1k-2 exp/tri2_1k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_1k-4 exp/tri2_1k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_1k-8 exp/tri2_1k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_1k-16 exp/tri2_1k-16_ali
echo ‘aligned tri2_1k’ >> log

echo
echo "===== TRI2 2k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_2k-2 exp/tri2_2k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_2k-4 exp/tri2_2k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_2k-8 exp/tri2_2k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_2k-16 exp/tri2_2k-16_ali
echo ‘aligned tri2_2k’ >> log

echo
echo "===== TRI2 4k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_4k-2 exp/tri2_4k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_4k-4 exp/tri2_4k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_4k-8 exp/tri2_4k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_4k-16 exp/tri2_4k-16_ali
echo ‘aligned tri2_4k’ >> log

echo
echo "===== TRI2 6k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_6k-2 exp/tri2_6k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_6k-4 exp/tri2_6k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_6k-8 exp/tri2_6k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_6k-16 exp/tri2_6k-16_ali
echo ‘aligned tri2_6k’ >> log

echo
echo "===== TRI2 8k ALIGMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_8k-2 exp/tri2_8k-2_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_8k-4 exp/tri2_8k-4_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_8k-8 exp/tri2_8k-8_ali
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2_8k-16 exp/tri2_8k-16_ali
echo ‘aligned tri2_8k’ >> log

echo
echo "===== GETTING TRI2 (DELTA+DELTA-DELTA) RESULTS ====="
echo

echo "====== TRI2 (DELTA+DELTA-DELTA) ======" >> RESULTS
for x in exp/tri2_*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
echo >> RESULTS

echo
echo "============== TRIPHONE 3 (LDA-MLLT) =============="
echo

echo
echo "===== TRI3 500 TRAINING ====="
steps/train_lda_mllt.sh --cmd "$train_cmd" 500 1000 data/train data/lang exp/tri2_500-2_ali exp/tri3_500-2 || exit 1
echo ‘finished training tri3_500-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 500 2000 data/train data/lang exp/tri2_500-4_ali exp/tri3_500-4 || exit 1
echo ‘finished training tri3_500-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 500 4000 data/train data/lang exp/tri2_500-8_ali exp/tri3_500-8 || exit 1
echo ‘finished training tri3_500-8’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 500 8000 data/train data/lang exp/tri2_500-16_ali exp/tri3_500-16 || exit 1
echo ‘finished training tri3_500-16’ >> log



echo
echo "===== TRI3 500 DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri3_500-2 exp/tri3_500-2/graph || exit 1 
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_500-2/graph data/test exp/tri3_500-2/decode
echo ‘finished decoding tri3_500-2’ >> log

utils/mkgraph.sh data/lang exp/tri3_500-4 exp/tri3_500-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_500-4/graph data/test exp/tri3_500-4/decode  
echo ‘finished decoding tri3_500-4’ >> log

utils/mkgraph.sh data/lang exp/tri3_500-8 exp/tri3_500-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_500-8/graph data/test exp/tri3_500-8/decode
echo ‘finished decoding tri3_500-8’ >> log
 
utils/mkgraph.sh data/lang exp/tri3_500-16 exp/tri3_500-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_500-16/graph data/test exp/tri3_500-16/decode
echo ‘finished decoding tri3_500-16’ >> log

echo
echo "===== TRI3 1K TRAINING ====="
echo
steps/train_lda_mllt.sh --cmd "$train_cmd" 1000 2000 data/train data/lang exp/tri2_1k-2_ali exp/tri3_1k-2 || exit 1
echo ‘finished training tri3_1k-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 1000 4000 data/train data/lang exp/tri2_1k-4_ali exp/tri3_1k-4 || exit 1
echo ‘finished training tri3_1k-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 1000 8000 data/train data/lang exp/tri2_1k-8_ali exp/tri3_1k-8 || exit 1 
echo ‘finished training tri3_1k-8’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 1000 16000 data/train data/lang exp/tri2_1k-16_ali exp/tri3_1k-16 || exit 1 
echo ‘finished training tri3_1k-16’ >> log

echo
echo "===== TRI3 1K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri3_1k-2 exp/tri3_1k-2/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_1k-2/graph data/test exp/tri3_1k-2/decode   
echo ‘finished decoding tri3_1k-2’ >> log

utils/mkgraph.sh data/lang exp/tri3_1k-4 exp/tri3_1k-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_1k-4/graph data/test exp/tri3_1k-4/decode
echo ‘finished decoding tri3_1k-4’ >> log 

utils/mkgraph.sh data/lang exp/tri3_1k-8 exp/tri3_1k-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_1k-8/graph data/test exp/tri3_1k-8/decode     
echo ‘finished decoding tri3_1k-8’ >> log

utils/mkgraph.sh data/lang exp/tri3_1k-16 exp/tri3_1k-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_1k-16/graph data/test exp/tri3_1k-16/decode
echo ‘finished decoding tri3_1k-16’ >> log

echo
echo "===== TRI3 2K TRAINING ====="
echo
steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 4000 data/train data/lang exp/tri2_2k-2_ali exp/tri3_2k-2 || exit 1
echo ‘finished training tri3_2k-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 8000 data/train data/lang exp/tri2_2k-4_ali exp/tri3_2k-4 || exit 1    
echo ‘finished training tri3_2k-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 16000 data/train data/lang exp/tri2_2k-8_ali exp/tri3_2k-8 || exit 1 
echo ‘finished training tri3_2k-8’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 32000 data/train data/lang exp/tri2_2k-16_ali exp/tri3_2k-16 || exit 1
echo ‘finished training tri3_2k-16’ >> log

echo
echo "===== TRI3 2K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri3_2k-2 exp/tri3_2k-2/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_2k-2/graph data/test exp/tri3_2k-2/decode   
echo ‘finished decoding tri3_2k-2’ >> log

utils/mkgraph.sh data/lang exp/tri3_2k-4 exp/tri3_2k-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_2k-4/graph data/test exp/tri3_2k-4/decode
echo ‘finished decoding tri3_2k-4’ >> log

utils/mkgraph.sh data/lang exp/tri3_2k-8 exp/tri3_2k-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_2k-8/graph data/test exp/tri3_2k-8/decode  
echo ‘finished decoding tri3_2k-8’ >> log

utils/mkgraph.sh data/lang exp/tri3_2k-16 exp/tri3_2k-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_2k-16/graph data/test exp/tri3_2k-16/decode
echo ‘finished decoding tri3_2k-16’ >> log

echo
echo "===== TRI3 4K TRAINING  ====="
echo
steps/train_lda_mllt.sh --cmd "$train_cmd" 4000 8000 data/train data/lang exp/tri2_4k-2_ali exp/tri3_4k-2 || exit 1
echo ‘finished training tri3_4k-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 4000 16000 data/train data/lang exp/tri2_4k-4_ali exp/tri3_4k-4 || exit 1 
echo ‘finished training tri3_4k-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 4000 32000 data/train data/lang exp/tri2_4k-8_ali exp/tri3_4k-8 || exit 1 
echo ‘finished training tri3_4k-8’ >> log


steps/train_lda_mllt.sh --cmd "$train_cmd" 4000 64000 data/train data/lang exp/tri2_4k-16_ali exp/tri3_4k-16 || exit 1

echo ‘finished training tri3_4k-16’ >> log



echo
echo "===== TRI3 4K DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri3_4k-2 exp/tri3_4k-2/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_4k-2/graph data/test exp/tri3_4k-2/decode     
echo ‘finished decoding tri3_4k-2’ >> log

utils/mkgraph.sh data/lang exp/tri3_4k-4 exp/tri3_4k-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_4k-4/graph data/test exp/tri3_4k-4/decode  
echo ‘finished decoding tri3_4k-4’ >> log

utils/mkgraph.sh data/lang exp/tri3_4k-8 exp/tri3_4k-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_4k-8/graph data/test exp/tri3_4k-8/decode   
echo ‘finished decoding tri3_4k-8’ >> log

utils/mkgraph.sh data/lang exp/tri3_4k-16 exp/tri3_4k-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_4k-16/graph data/test exp/tri3_4k-16/decode
echo ‘finished decoding tri3_4k-16’ >> log

echo
echo "===== TRI3 6K TRAINING ====="
echo
steps/train_lda_mllt.sh --cmd "$train_cmd" 6000 12000 data/train data/lang exp/tri2_6k-2_ali exp/tri3_6k-2 || exit 1 
echo ‘finished training tri3_6k-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 6000 24000 data/train data/lang exp/tri2_6k-4_ali exp/tri3_6k-4 || exit 1 
echo ‘finished training tri3_6k-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 6000 48000 data/train data/lang exp/tri2_6k-8_ali exp/tri3_6k-8 || exit 1 
echo ‘finished training tri3_6k-8’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 6000 96000 data/train data/lang exp/tri2_6k-16_ali exp/tri3_6k-16 || exit 1
echo ‘finished training tri3_6k-16’ >> log

echo
echo "===== TRI3 6K DECODING====="
echo
utils/mkgraph.sh data/lang exp/tri3_6k-2 exp/tri3_6k-2/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_6k-2/graph data/test exp/tri3_6k-2/decode
echo ‘finished decoding tri3_6k-2’ >> log

utils/mkgraph.sh data/lang exp/tri3_6k-4 exp/tri3_6k-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_6k-4/graph data/test exp/tri3_6k-4/decode
echo ‘finished decoding tri3_6k-4’ >> log


utils/mkgraph.sh data/lang exp/tri3_6k-8 exp/tri3_6k-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_6k-8/graph data/test exp/tri3_6k-8/decode  
echo ‘finished decoding tri3_6k-8’ >> log 

utils/mkgraph.sh data/lang exp/tri3_6k-16 exp/tri3_6k-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_6k-16/graph data/test exp/tri3_6k-16/decode
echo ‘finished decoding tri3_6k-16’ >> log

echo
echo "===== TRI3 8K TRAINING ====="
echo
steps/train_lda_mllt.sh --cmd "$train_cmd" 8000 16000 data/train data/lang exp/tri2_8k-2_ali exp/tri3_8k-2 || exit 1 
echo ‘finished training tri3_8k-2’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 8000 32000 data/train data/lang exp/tri2_8k-4_ali exp/tri3_8k-4 || exit 1 
echo ‘finished training tri3_8k-4’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 8000 64000 data/train data/lang exp/tri2_8k-8_ali exp/tri3_8k-8 || exit 1 
echo ‘finished training tri3_8k-8’ >> log

steps/train_lda_mllt.sh --cmd "$train_cmd" 8000 128000 data/train data/lang exp/tri2_8k-16_ali exp/tri3_8k-16 || exit 1 
echo ‘finished training tri3_8k-16’ >> log

echo
echo "===== TRI2 8K DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri3_8k-2 exp/tri3_8k-2/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_8k-2/graph data/test exp/tri3_8k-2/decode   
echo ‘finished decoding tri3_8k-2’ >> log  

utils/mkgraph.sh data/lang exp/tri3_8k-4 exp/tri3_8k-4/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_8k-4/graph data/test exp/tri3_8k-4/decode
echo ‘finished decoding tri3_8k-4’ >> log

utils/mkgraph.sh data/lang exp/tri3_8k-8 exp/tri3_8k-8/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_8k-8/graph data/test exp/tri3_8k-8/decode
echo ‘finished decoding tri3_8k-8’ >> log

utils/mkgraph.sh data/lang exp/tri3_8k-16 exp/tri3_8k-16/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3_8k-16/graph data/test exp/tri3_8k-16/decode
echo ‘finished decoding tri3_8k-16’ >> log

echo                                                                                                                                                       
echo "===== TRI3 (LDA-MLLT with FMLLR) ALIGNMENT ====="
echo

echo
echo "===== TRI3 500 ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_500-2 exp/tri3_500-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_500-4 exp/tri3_500-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_500-8 exp/tri3_500-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_500-16 exp/tri3_500-16_ali
echo ‘aligned tri3_500’ >> log

echo
echo "===== TRI3 1k ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_1k-2 exp/tri3_1k-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_1k-4 exp/tri3_1k-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_1k-8 exp/tri3_1k-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_1k-16 exp/tri3_1k-16_ali
echo ‘aligned tri3_1k’ >> log

echo
echo "===== TRI3 2k ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_2k-2 exp/tri3_2k-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_2k-4 exp/tri3_2k-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_2k-8 exp/tri3_2k-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_2k-16 exp/tri3_2k-16_ali
echo ‘aligned tri3_2k’ >> log

echo
echo "===== TRI3 4k ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_4k-2 exp/tri3_4k-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_4k-4 exp/tri3_4k-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_4k-8 exp/tri3_4k-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_4k-16 exp/tri3_4k-16_ali
echo ‘aligned tri3_4k’ >> log

echo
echo "===== TRI3 6k ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_6k-2 exp/tri3_6k-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_6k-4 exp/tri3_6k-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_6k-8 exp/tri3_6k-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_6k-16 exp/tri3_6k-16_ali
echo ‘aligned tri3_6k’ >> log

echo
echo "===== TRI3 8k ALIGMENT ====="
echo
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_8k-2 exp/tri3_8k-2_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_8k-4 exp/tri3_8k-4_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_8k-8 exp/tri3_8k-8_ali
steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3_8k-16 exp/tri3_8k-16_ali
echo ‘aligned tri3_8k’ >> log

echo
echo "===== GETTING TRI3(LDA-MLLT) RESULTS ====="
echo

echo "====== TRI3(LDA-MLLT) ======" >> RESULTS
for x in exp/tri3_*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
echo >> RESULTS


 
echo
echo "============== DNN =============="
echo

echo
echo "===== DNN 500 TRAINING AND DECODING ====="
echo


steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim \
	--pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_500-2_ali exp/nnet4d2_tri3_500-2

echo ‘finished training dnn_500-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_500-2/decode exp/tri3_500-2/graph data/test exp/nnet4d2_tri3_500-2/decode 

echo ‘finished decoding dnn_500-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_500-4_ali exp/nnet4d2_tri3_500-4

echo ‘finished training dnn_500-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_500-4/decode exp/tri3_500-4/graph data/test exp/nnet4d2_tri3_500-4/decode 

echo ‘finished decoding dnn_500-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_500-8_ali exp/nnet4d2_tri3_500-8

echo ‘finished training dnn_500-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_500-8/decode exp/tri3_500-8/graph data/test exp/nnet4d2_tri3_500-8/decode

echo ‘finished decoding dnn_500-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_500-16_ali exp/nnet4d2_tri3_500-16

echo ‘finished training dnn_500-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_500-16/decode exp/tri3_500-16/graph data/test exp/nnet4d2_tri3_500-16/decode

echo ‘finished decoding dnn_500-16’ >> log


echo
echo "===== DNN 1k TRAINING AND DECODING ====="
echo

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_1k-2_ali exp/nnet4d2_tri3_1k-2

echo ‘finished training dnn_1k-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_1k-2/decode exp/tri3_1k-2/graph data/test exp/nnet4d2_tri3_1k-2/decode 

echo ‘finished decoding dnn_1k-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_1k-4_ali exp/nnet4d2_tri3_1k-4

echo ‘finished training dnn_1k-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_1k-4/decode exp/tri3_1k-4/graph data/test exp/nnet4d2_tri3_1k-4/decode 

echo ‘finished decoding dnn_1k-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_1k-8_ali exp/nnet4d2_tri3_1k-8

echo ‘finished training dnn_1k-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_1k-8/decode exp/tri3_1k-8/graph data/test exp/nnet4d2_tri3_1k-8/decode 

echo ‘finished decoding dnn_1k-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16"\
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_1k-16_ali exp/nnet4d2_tri3_1k-16

echo ‘finished training dnn_1k-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_1k-16/decode exp/tri3_1k-16/graph data/test exp/nnet4d2_tri3_1k-16/decode 

echo ‘finished decoding dnn_1k-16’ >> log

echo
echo "===== DNN 2K TRAINING AND DECODING ====="
echo

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_2k-2_ali exp/nnet4d2_tri3_2k-2

echo ‘finished training dnn_2k-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	 --nj $nj --transform-dir exp/tri3_2k-2/decode exp/tri3_2k-2/graph data/test exp/nnet4d2_tri3_2k-2/decode 

echo ‘finished decoding dnn_2k-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16\
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_2k-4_ali exp/nnet4d2_tri3_2k-4

echo ‘finished training dnn_2k-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_2k-4/decode exp/tri3_2k-4/graph data/test exp/nnet4d2_tri3_2k-4/decode

echo ‘finished decoding dnn_2k-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	 --minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_2k-8_ali exp/nnet4d2_tri3_2k-8

echo ‘finished training dnn_2k-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_2k-8/decode exp/tri3_2k-8/graph data/test exp/nnet4d2_tri3_2k-8/decode

echo ‘finished decoding dnn_2k-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \	
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_2k-16_ali exp/nnet4d2_tri3_2k-16

echo ‘finished training dnn_2k-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_2k-16/decode exp/tri3_2k-16/graph data/test exp/nnet4d2_tri3_2k-16/decode

echo ‘finished decoding dnn_2k-16’ >> log

echo
echo "===== DNN 4K TRAINING AND DECODING ====="
echo

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_4k-2_ali exp/nnet4d2_tri3_4k-2

echo ‘finished training dnn_4k-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_4k-2/decode exp/tri3_4k-2/graph data/test exp/nnet4d2_tri3_4k-2/decode 

echo ‘finished decoding dnn_4k-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_4k-4_ali exp/nnet4d2_tri3_4k-4

echo ‘finished training dnn_4k-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_4k-4/decode exp/tri3_4k-4/graph data/test exp/nnet4d2_tri3_4k-4/decode 

echo ‘finished decoding dnn_4k-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_4k-8_ali exp/nnet4d2_tri3_4k-8

echo ‘finished training dnn_4k-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_4k-8/decode exp/tri3_4k-8/graph data/test exp/nnet4d2_tri3_4k-8/decode 

echo ‘finished decoding dnn_4k-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \	
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_4k-16_ali exp/nnet4d2_tri3_4k-16

echo ‘finished training dnn_4k-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_4k-16/decode exp/tri3_4k-16/graph data/test exp/nnet4d2_tri3_4k-16/decode 

echo ‘finished decoding dnn_4k-16’ >> log



echo
echo "===== DNN 6K TRAINING AND DECODING ====="
echo


steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_6k-2_ali exp/nnet4d2_tri3_6k-2

echo ‘finished training dnn_6k-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_6k-2/decode exp/tri3_6k-2/graph data/test exp/nnet4d2_tri3_6k-2/decode 

echo ‘finished decoding dnn_6k-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_6k-4_ali exp/nnet4d2_tri3_6k-4

echo ‘finished training dnn_6k-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_6k-4/decode exp/tri3_6k-4/graph data/test exp/nnet4d2_tri3_6k-4/decode

echo ‘finished decoding dnn_6k-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_6k-8_ali exp/nnet4d2_tri3_6k-8

echo ‘finished training dnn_6k-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_6k-8/decode exp/tri3_6k-8/graph data/test exp/nnet4d2_tri3_6k-8/decode

echo ‘finished decoding dnn_6k-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_6k-16_ali exp/nnet4d2_tri3_6k-16

echo ‘finished training dnn_6k-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_6k-16/decode exp/tri3_6k-16/graph data/test exp/nnet4d2_tri3_6k-16/decode

echo ‘finished decoding dnn_6k-16’ >> log



echo
echo "===== DNN 8K TRAINING AND DECODING ====="
echo

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
 	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
 	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_8k-2_ali exp/nnet4d2_tri3_8k-2

echo ‘finished training dnn_8k-2’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_8k-2/decode exp/tri3_8k-2/graph data/test exp/nnet4d2_tri3_8k-2/decode 

echo ‘finished decoding dnn_8k-2’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_8k-4_ali exp/nnet4d2_tri3_8k-4

echo ‘finished training dnn_8k-4’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_8k-4/decode exp/tri3_8k-4/graph data/test exp/nnet4d2_tri3_8k-4/decode 

echo ‘finished decoding dnn_8k-4’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_8k-8_ali exp/nnet4d2_tri3_8k-8

echo ‘finished training dnn_8k-8’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3_8k-8/decode exp/tri3_8k-8/graph data/test exp/nnet4d2_tri3_8k-8/decode

echo ‘finished decoding dnn_8k-8’ >> log

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_8k-16_ali exp/nnet4d2_tri3_8k-16

echo ‘finished training dnn_8k-16’ >> log

steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
--nj $nj --transform-dir exp/tri3_8k-16/decode exp/tri3_8k-16/graph data/test exp/nnet4d2_tri3_8k-16/decode

echo ‘finished decoding dnn_8k-16’ >> log

echo
echo "===== GETTING DNN RESULTS ====="
echo

echo "====== DNN ======" >> RESULTS
for x in exp/nnet4d2_*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS


echo
echo "============== FINISHED RUNNING =============="
echo 
