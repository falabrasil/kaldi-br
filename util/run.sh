#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# qua set  4 14:30:26 -03 2019
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

#!/bin/bash
#
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Cassio Batista   - cassio.batista.13@gmail.com
# Ter Nov  6 14:11:05 -03 2018
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

. ./path.sh || exit 1
. ./cmd.sh || exit 1

# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1

nj=2      # number of parallel jobs 
lm_order=3 # language model order (n-gram quantity)

num_leaves=400
tot_gauss=1600


# DNN parameters 
minibatch_size=512
num_epochs=8 
num_epochs_extra=5 
num_hidden_layers=2
initial_learning_rate=0.02 
final_learning_rate=0.004
#pnorm_input_dim=300 
#pnorm_output_dim=3000
pnorm_input_dim=1000 #DNN parameters for small data
pnorm_output_dim=200 #DNN parameters for small data

run_decode=false
use_gpu=false

if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.  Otherwise, call this script with --use-gpu false
EOF
  fi
  parallel_opts="--gpu 1"
  num_threads=1
else
  # Use 4 nnet jobs just like run_4d_gpu.sh so the results should be
  # almost the same, but this may be a little bit slow.
  num_threads=12
  parallel_opts="--num-threads $num_threads"
fi


# Removing previously created data (from last run.sh execution). 
#rm -rf exp mfcc data/train/spk2utt data/train/cmvn.scp data/train/feats.scp data/train/split2 data/test/spk2utt data/test/cmvn.scp data/test/feats.scp data/test/split2 data/local/lang data/lang data/local/tmp data/local/dict/lexiconp.txt


echo
echo "===== PREPARING ACOUSTIC DATA ====="
echo

# Needs to be prepared by hand for each train and test data (or using self written scripts):
#
# corpus.txt  [<text_transcription>]
# spk2gender  [<speaker-id> <gender>]
# text        [<uterranceID> <text_transcription>]
# utt2spk     [<uterranceID> <speakerID>]
# wav.scp     [<uterranceID> <full_path_to_audio_file>]

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
# optional_silence.txt  [<phone>]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]


# Preparing language data
utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang

echo
echo "===== LANGUAGE MODEL CREATION ====="
#echo "===== MAKING lm.arpa ====="
#echo

#loc=`which ngram-count`;
#if [ -z $loc ]; then
#	if uname -a | grep 64 >/dev/null; then
#		sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
#	else		sdir=$KALDI_ROOT/tools/srilm/bin/i686
#	fi
#	if [ -f $sdir/ngram-count ]; then
#		echo "Using SRILM language modelling tool from $sdir"
#		export PATH=$PATH:$sdir
#	else
#		echo "SRILM toolkit is probably not installed.
#				Instructions: tools/install_srilm.sh"
#		exit 1
#  fi
#fi
# Example of how to train your own language model. Note: It is not recommended to train your language model using the same dataset that will be used for the  acoustic model training.
#cat data/train/corpus.txt data/test/corpus.txt > data/local/corpus.txt
#local=data/local
#ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount -text $local/corpus.txt -lm $local/tmp/lm.arpa

echo
echo "===== DOWNLOADING lm.arpa ====="
echo

local=data/local
tmp=$local/tmp
if [ ! -d "$tmp" ]; then
	mkdir $local/tmp
	wget https://gitlab.com/fb-asr/fb-asr-resources/kaldi-resources/raw/master/lm/lm.arpa -P $local/tmp
fi


echo
echo "===== CONVERTING lm.arpa to  G.fst ====="
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
echo "===== MONO ALIGMENT ====="
echo

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono exp/mono_ali || exit 1




echo
echo "============== TRIPHONE 1 (first triphone pass) DELTA FEATURES =============="
echo
echo
echo "===== TRIPHONE 1 TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" $num_leaves $tot_gauss data/train data/lang exp/mono_ali exp/tri1 || exit 1


echo                                                                                                                                                       
echo "===== TRIPHONE 1 ALIGNMENT ====="
echo

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri1 exp/tri1_ali




echo
echo "============== TRIPHONE 2 (delta + delta-delta) =============="
echo

echo
echo "===== TRIPHONE 2 TRAINING ====="
echo

steps/train_deltas.sh --cmd "$train_cmd" $num_leaves $tot_gauss data/train data/lang exp/tri1_ali exp/tri2|| exit 1  
echo ‘finished training tri2_500-2’ >> log


echo
echo "===== TRIPHONE 2 ALIGMENT ====="
echo

steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri2 exp/tri2_ali




echo
echo "============== TRIPHONE 3 (LDA-MLLT) =============="
echo

echo
echo "===== TRIPHONE 3 TRAINING ====="
steps/train_lda_mllt.sh --cmd "$train_cmd" $num_leaves $tot_gauss data/train data/lang exp/tri2_ali exp/tri3 || exit 1


echo                                                                                                                                                       
echo "===== TRIPHONE 3 (LDA-MLLT with FMLLR) ALIGNMENT ====="
echo

steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3 exp/tri3_ali


echo
echo "===== PREPARING GRAPH DIRECTORY ====="
echo

utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph || exit 1
utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph || exit 1


 
echo
echo "============== DNN TRAINING =============="
echo

steps/nnet2/train_pnorm_fast.sh --stage -10 --num-threads 16 \
	--minibatch-size $minibatch_size --parallel-opts "--num-threads 16" \
	--num-jobs-nnet 4 --num-epochs $num_epochs --num-epochs-extra $num_epochs_extra \
	--add-layers-period 1 --num-hidden-layers $num_hidden_layers --mix-up 4000 \
	--initial-learning-rate $initial_learning_rate --final-learning-rate $final_learning_rate \
	--cmd "$decode_cmd" --pnorm-input-dim $pnorm_input_dim \
	--pnorm-output-dim $pnorm_output_dim data/train data/lang exp/tri3_ali exp/dnn


if $run_decode;then 
	echo
	echo "===== MONO DECODING ====="
	echo

	steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode

	echo
	echo "===== GETTING MONOPHONE RESULTS ====="
	echo

	echo "====== MONOPHONE ======" >> RESULTS
	for x in exp/mono*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
	echo >> RESULTS


	echo
	echo "===== TRIPHONE 1 DECODING====="
	echo

	steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode

	echo
	echo "===== GETTING TRI1 (DELTA FEATURES) RESULTS ====="
	echo

	echo "====== TRI1 (DELTA FEATURES) ======" >> RESULTS
	for x in exp/tri1/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
	echo >> RESULTS



	echo
	echo "===== TRIPHONE 2 DECODING ====="
	echo
 
	steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2/decode 
 
	echo
	echo "===== GETTING TRI2 (DELTA+DELTA-DELTA) RESULTS ====="
	echo
	echo "====== TRI2 (DELTA+DELTA-DELTA) ======" >> RESULTS
	for x in exp/tri2/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
	echo >> RESULTS


	echo
	echo "===== TRIPHONE 3 DECODING ====="
	echo

	steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3/graph data/test exp/tri3/decode

	echo
	echo "===== GETTING TRI3(LDA-MLLT) RESULTS ====="
	echo
	echo "====== TRI3(LDA-MLLT) ======" >> RESULTS
	for x in exp/tri3/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
	echo >> RESULTS


	echo
	echo "============== DNN DECODING =============="
	echo

	steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
	--nj $nj --transform-dir exp/tri3/decode exp/tri3/graph data/test exp/dnn/decode 

	echo
	echo "===== GETTING DNN RESULTS ====="
	echo
	echo "====== DNN ======" >> RESULTS
	for x in exp/dnn/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
fi

echo
echo "============== FINISHED RUNNING =============="
echo 

