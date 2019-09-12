#!/bin/bash
#
# Cassio Batista   - https://cassota.gitlab.io/
# Ana Larissa Dias - larissa.engcomp@gmail.com

TAG="DECODE"
COLOR_B="\e[96m"
COLOR_E="\e[0m"

function usage() {
    echo "usage: (bash) $0 OPTIONS"
    echo "eg.: $0 --nj 2 --run_decode true --use_ivector false"
    echo ""
    echo "OPTIONS"
    echo "  --nj             number of parallel jobs  "
    echo "  --run_decode     specifies whether the decode step should be computed  "
    echo "  --use_ivector    if false, it run the standard DNN decode. If true run the DNN with ivector decode  "
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
run_mkgraph_tri3b=true

echo -e $COLOR_B
echo "===== [$TAG] PREPARING GRAPH DIRECTORY ===== [$(date)]"
echo -e $COLOR_E

if $run_mkgraph_mono ; then
    echo -e $COLOR_B
    echo "[$TAG] CREATING MONO GRAPH ===== [$(date)]"
    echo -e $COLOR_E
    utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
fi

if $run_mkgraph_tri1 ; then
    echo -e $COLOR_B
    echo "[$TAG] CREATING TRI 1 GRAPH (Δ) ===== [$(date)]"
    echo -e $COLOR_E
    utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
fi

#if $run_mkgraph_tri2 ; then
#    echo -e $COLOR_B
#    echo "[$TAG] CREATING TRI 2 GRAPH (Δ+ΔΔ) ===== [$(date)]"
#    echo -e $COLOR_E
#    utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph || exit 1
#fi

if $run_mkgraph_tri3 ; then
    echo -e $COLOR_B
    echo "[$TAG] CREATING TRI 3 GRAPH (LDA-MLLT) ===== [$(date)]"
    echo -e $COLOR_E
    #utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph || exit 1
    utils/mkgraph.sh data/lang exp/tri2b exp/tri2b/graph || exit 1
fi

if $run_mkgraph_tri3b ; then
    echo -e $COLOR_B
    echo "[$TAG] CREATING TRI 3b GRAPH (LDA-MLLT-SAT) ===== [$(date)]"
    echo -e $COLOR_E
    utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1
fi


run_mono_decode=false
run_tri1_decode=false
run_tri2_decode=false
run_tri3_decode=false
run_tri3b_decode=true
run_dnn_decode=true

rm -f RESULTS

if $run_decode ; then 
    echo -e $COLOR_B
    echo "===== [$TAG] STARTING DECODE ===== [$(date)]"
    echo -e $COLOR_E
    if $run_mono_decode ; then
        echo -e $COLOR_B
        echo "[$TAG] MONO DECODING ===== [$(date)]"
        echo -e $COLOR_E
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
        echo -e $COLOR_B
        echo "[$TAG] TRIPHONE 1 DECODING ===== [$(date)]"
        echo -e $COLOR_E
        steps/decode.sh \
            --config conf/decode.config \
            --nj $nj \
            --cmd "$decode_cmd" \
            exp/tri1/graph data/test exp/tri1/decode
        
        echo "====== TRI1 (DELTA FEATURES) ======" >> RESULTS
        for x in exp/tri1/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi

   # if $run_tri2_decode ; then
   #     echo -e $COLOR_B
   #     echo "[$TAG] TRIPHONE 2 DECODING ====="
   #     echo -e $COLOR_E
   #     steps/decode.sh \
   #         --config conf/decode.config \
   #         --nj $nj \
   #         --cmd "$decode_cmd" \
   #         exp/tri2/graph data/test exp/tri2/decode 
   #     
   #     echo "====== TRI2 (DELTA+DELTA-DELTA) ======" >> RESULTS
   #     for x in exp/tri2/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
   #     echo >> RESULTS
   # fi
    
    if $run_tri3_decode ; then
        echo -e $COLOR_B
        echo "[$TAG] TRIPHONE 3 DECODING ===== [$(date)]"
        echo -e $COLOR_E
       # steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3/graph data/test exp/tri3/decode
        steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2b/graph data/test exp/tri2b/decode
       
        echo "====== TRI3b (LDA-MLLT) ======" >> RESULTS
        #for x in exp/tri3/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        for x in exp/tri2b/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi

    if $run_tri3b_decode ; then
        echo -e $COLOR_B
        echo "[$TAG] TRIPHONE 3b DECODING ===== [$(date)]"
        echo -e $COLOR_E
        steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3b/graph data/test exp/tri3b/decode

        echo "====== TRI3b(LDA-MLLT-SAT) ======" >> RESULTS
        for x in exp/tri3b/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        echo >> RESULTS
    fi
    
    if $run_dnn_decode ; then
        if ! $use_ivector ; then
            echo -e $COLOR_B
            echo "[$TAG] DNN DECODING ===== [$(date)]"
            echo -e $COLOR_E
            steps/nnet2/decode.sh \
                --config conf/decode.config \
                --cmd "$decode_cmd" \
                --nj $nj \
                --transform-dir exp/tri3/decode \
                exp/tri3/graph data/test exp/dnn/decode
       
            echo "====== DNN ======" >> RESULTS
            for x in exp/dnn/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
       
        else
            echo -e $COLOR_B
            echo "[$TAG] DNN WITH iVECTORS DECODING ====== [$(date)]"
            echo -e $COLOR_E
            # Note: the iVectors seem to hurt at small amount of data.
            # However, experiments by Haihua Xu on WSJ, show it helping nicely.
            steps/nnet2/decode.sh \
                --config conf/decode.config \
                --cmd "$decode_cmd" \
                --nj $nj \
                --online-ivector-dir exp/nnet2_online/ivectors_test \
                exp/tri3b/graph data/test exp/nnet2_online/nnet/decode
            
            echo "====== DNN WITH IVECTORS ======" >> RESULTS
            for x in exp/nnet2_online/nnet/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >> RESULTS
        fi # close $use_ivect
    fi # close $run_dnn
fi # close $run_decode
### EOF ###
