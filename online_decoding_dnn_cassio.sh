#!/bin/bash
# Note: you have to do 'make ext' in $kaldi_path/src/ before running this.
#
# This script is meant to demonstrate how an existing DNN-HMM acoustic model (AM) can be used to decode new audio files.
#
# USAGE:
#    $ ./online_decoding_dnn.sh
#
# Directory tree:
#    KALDI_ROOT/egs/YOUR_PROJECT_NAME   
# 
#
#    audio/
#       test1.wav
#       test2.wav
#       test3.wav
#
#
# OUTPUT:
#    decode_dir/
#       input.scp
#       spk2utt
#       transcriptions.txt


. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


# Decoding results are saved in this directory
decode_dir="./online_decoding_dnn"

# Change this to "live" either here or using command line switch like:
# --test-mode live
test_mode="simulated"

# Set the path to the audio files
audio=${HOME}/fb_env/kaldi-resources/audio

# path to the lang directory
lang=data/lang

# path to extractor
extractor=exp/nnet2_online/extractor

# path to dnn model trained with iVector
nnet_am=exp/nnet2_online/nnet

# output path to online decoding config files
nnet_online=exp/nnet2_online/nnet_online

# path to the graph directory of the triphone training
tri_graph=exp/tri3/graph



# create the config files to online decoding
steps/online/nnet2/prepare_online_decoding.sh $lang $extractor $nnet_am $nnet_online

case $test_mode in
    live)
        echo
        echo -e "  LIVE DEMO MODE - you can use a microphone and say something\n"
        echo
        echo "We still working at this funcionality";;

    simulated)
        echo
        echo -e "  SIMULATED ONLINE DECODING - pre-recorded audio is used\n"
        echo
        echo "  You can type \"./run.sh --test-mode live\" to try it using your"
        echo "  own voice!"
        echo
        mkdir -p $decode_dir
        # make an input.scp file
        > $decode_dir/input.scp
        for f in $audio/*.wav; do
            bf=`basename $f`
            bf=${bf%.wav}
            echo $bf $f >> $decode_dir/input.scp
        done
        # make a spk2utt file
	awk -F" " '{print $1,$1}' $decode_dir/input.scp  >> $decode_dir/utt2spk.tmp
	utils/utt2spk_to_spk2utt.pl $decode_dir/utt2spk.tmp > $decode_dir/spk2utt
	# online decoding
        src/online2bin/online2-wav-nnet2-latgen-faster --do-endpointing=false \
    		--online=false \
    		--config=$nnet_online/conf/online_nnet2_decoding.conf \
    		--max-active=7000 --beam=15.0 --lattice-beam=6.0 \
   		--acoustic-scale=0.1 --word-symbol-table=$tri_graph/words.txt \
   		$nnet_online/final.mdl $tri_graph/HCLG.fst "ark:$decode_dir/spk2utt" "scp:$decode_dir/input.scp" \
   		ark:|src/latbin/lattice-best-path --acoustic-scale=0.1 ark:- ark,t:- | utils/int2sym.pl -f 2- $tri_graph/words.txt > $decode_dir/transcriptions.txt;;

    *)
        echo "Invalid test mode! Should be either \"live\" or \"simulated\"!";
        exit 1;;
esac

rm $decode_dir/*.tmp

