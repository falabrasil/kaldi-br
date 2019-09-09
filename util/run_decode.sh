#!/bin/bash
#
# Cassio Batista   - https://cassota.gitlab.io/
# Ana Larissa Dias - larissa.engcomp@gmail.com

TAG="DECODE"
COLOR_B="\e[96m"
COLOR_E="\e[0m"

function usage() {
    echo "usage: (bash) $0 OPTIONS"
    echo "eg.: $0 --XX x --XX x --XX x"
    echo "OPTIONS"
    echo "  -- "
    echo "  -- "
    echo "  -- "
    echo "  -- "
}

if test $# -eq 0 ; then
    usage
    exit 1
fi

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        --nj)
            nj="$2"
            shift # past argument
            shift # past value
        ;;
        --run_decode)
            run_decode="$2"
            shift # past argument
            shift # past value
        ;;
    --use_ivector)
            use_ivector="$2"
            shift # past argument
            shift # past value
        ;;
        *)  # unknown option
            echo "[$TAG] unknown flag $1"
            usage
            shift # past argument
            exit 0
        ;;
    esac
done

if [[ -z $nj || -z $run_decode ]] ; then
    echo "[$TAG] a problem with the arg flags has been detected"
    exit 1
fi

. ./cmd.sh || exit 1

run_mkgraph_mono=false
run_mkgraph_tri1=false
run_mkgraph_tri2=false
run_mkgraph_tri3=true

echo
echo "===== [$TAG] PREPARING GRAPH DIRECTORY ====="
echo

if $run_mkgraph_mono ; then
    echo
    echo "[$TAG] CREATING MONO GRAPH ====="
    echo
    utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
fi

if $run_mkgraph_tri1 ; then
    echo
    echo "[$TAG] CREATING TRI 1 GRAPH (Δ) ====="
    echo
    utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
fi

if $run_mkgraph_tri2 ; then
    echo
    echo "[$TAG] CREATING TRI 2 GRAPH (Δ+ΔΔ) ====="
    echo
    utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph || exit 1
fi

if $run_mkgraph_tri3 ; then
    echo
    echo "[$TAG] CREATING TRI 3 GRAPH (LDA-MLLT) ====="
    echo
    utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph || exit 1
fi

run_mono_decode=false
run_tri1_decode=false
run_tri2_decode=false
run_tri3_decode=true
run_dnn_decode=true

rm -f RESULTS

if $run_decode ; then 
    echo
    echo "===== [$TAG] STARTING DECODE ====="
    echo
    if $run_mono_decode ; then
        echo
        echo "[$TAG] MONO DECODING ====="
        echo
        steps/decode.sh \
            --config conf/decode.config \
            --nj $nj \
            --cmd "$decode_cmd" \
            exp/mono/graph data/test exp/mono/decode
        
        echo "====== MONOPHONE ======" >> RESULTS
        for x in exp/mono*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi
    
    if $run_tri1_decode ; then
        echo
        echo "[$TAG] TRIPHONE 1 DECODING ====="
        echo
        steps/decode.sh \
            --config conf/decode.config \
            --nj $nj \
            --cmd "$decode_cmd" \
            exp/tri1/graph data/test exp/tri1/decode
        
        echo "====== TRI1 (DELTA FEATURES) ======" >> RESULTS
        for x in exp/tri1/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi
    
    if $run_tri2_decode ; then
        echo
        echo "[$TAG] TRIPHONE 2 DECODING ====="
        echo
        steps/decode.sh \
            --config conf/decode.config \
            --nj $nj \
            --cmd "$decode_cmd" \
            exp/tri2/graph data/test exp/tri2/decode 
        
        echo "====== TRI2 (DELTA+DELTA-DELTA) ======" >> RESULTS
        for x in exp/tri2/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi
    
    if $run_tri3_decode ; then
        echo
        echo "[$TAG] TRIPHONE 3 DECODING ====="
        echo
        steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3/graph data/test exp/tri3/decode
        
        echo "====== TRI3(LDA-MLLT) ======" >> RESULTS
        for x in exp/tri3/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi
    
    if $run_dnn_decode ; then
        if ! $use_ivector ; then
            echo
            echo "[$TAG] DNN DECODING ====="
            echo    
            steps/nnet2/decode.sh \
                --config conf/decode.config \
                --cmd "$decode_cmd" \
                --nj $nj \
                --transform-dir exp/tri3/decode \
                exp/tri3/graph data/test exp/dnn/decode
       
            echo "====== DNN ======" >> RESULTS
            for x in exp/dnn/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
       
        else
            echo
            echo "[$TAG] DNN WITH iVECTORS DECODING ======"
            echo    
            # Note: the iVectors seem to hurt at small amount of data.
            # However, experiments by Haihua Xu on WSJ, show it helping nicely.
            steps/nnet2/decode.sh \
                --config conf/decode.config \
                --cmd "$decode_cmd" \
                --nj $nj \
                --online-ivector-dir exp/nnet2_online/ivectors_test \
                exp/tri3/graph data/test exp/nnet2_online/nnet/decode
            
            echo "====== DNN WITH IVECTORS ======" >> RESULTS
            for x in exp/nnet2_online/nnet/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        fi # close $use_ivect
    fi # close $run_dnn
fi # close $run_decode
### EOF ###
