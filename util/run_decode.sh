#!/bin/bash
#
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Cassio Batista   - cassio.batista.13@gmail.com
# Ter Nov  6 14:11:05 -03 2018
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

echo
echo "===== PREPARING GRAPH DIRECTORY ====="
echo

utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph || exit 1
utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph || exit 1


if [[ $run_decode ]] ; then 
    echo
    echo "===== MONO DECODING ====="
    echo
    steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode
    
    echo "====== MONOPHONE ======" >> RESULTS
    for x in exp/mono*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
    echo >> RESULTS
    
    echo
    echo "===== TRIPHONE 1 DECODING ====="
    echo
    steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode
    
    echo "====== TRI1 (DELTA FEATURES) ======" >> RESULTS
    for x in exp/tri1/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
    echo >> RESULTS
    
    echo
    echo "===== TRIPHONE 2 DECODING ====="
    echo
    steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2/decode 
    
    echo "====== TRI2 (DELTA+DELTA-DELTA) ======" >> RESULTS
    for x in exp/tri2/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
    echo >> RESULTS
    
    echo
    echo "===== TRIPHONE 3 DECODING ====="
    echo
    steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3/graph data/test exp/tri3/decode
    
    echo "====== TRI3(LDA-MLLT) ======" >> RESULTS
    for x in exp/tri3/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
    echo >> RESULTS
    
    echo
    echo "============== DNN DECODING =============="
    echo
    steps/nnet2/decode.sh --config conf/decode.config --cmd "$decode_cmd" \
    --nj $nj --transform-dir exp/tri3/decode exp/tri3/graph data/test exp/dnn/decode 
    
    echo "====== DNN ======" >> RESULTS
    for x in exp/dnn/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
fi
