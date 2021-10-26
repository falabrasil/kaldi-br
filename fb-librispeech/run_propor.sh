
set -e

rm -rf data exp mfcc

s_time=$(date)

bash run_data_prep.sh \
  --audio-dir $HOME/fb-gitlab/fb-audio-corpora/lapsbm16k \
  --lex-file  $HOME/fb-github/lm-br/data/dict/lexicon.txt.gz \
  --lm-small-file $HOME/fb-github/lm-br/data/lm/3-gram.1e-7.arpa.gz || exit 1
bash run_gmm.sh
bash run_ivector_common.sh

exit 0

bash run_tdnn_mono_chain_lda_ivector_fs3.sh             --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_lda_noivector_fs3.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_lda_ivector_nofs.sh            --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_lda_noivector_nofs.sh          --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok" 
bash run_tdnn_mono_nochain_lda_ivector.sh               --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_nochain_lda_noivector.sh             --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_tdnn_mono_chain_delta_ivector_fs3.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_delta_noivector_fs3.sh         --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_delta_ivector_nofs.sh          --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_chain_delta_noivector_nofs.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok" 
bash run_tdnn_mono_nochain_delta_ivector.sh             --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_mono_nochain_delta_noivector.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_tdnn_trideltas_chain_lda_ivector_fs3.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_lda_noivector_fs3.sh      --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_lda_ivector_nofs.sh       --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_lda_noivector_nofs.sh     --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok" 
bash run_tdnn_trideltas_nochain_lda_ivector.sh          --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_nochain_lda_noivector.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_tdnn_trideltas_chain_delta_ivector_fs3.sh      --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_delta_noivector_fs3.sh    --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_delta_ivector_nofs.sh     --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_chain_delta_noivector_nofs.sh   --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok" 
bash run_tdnn_trideltas_nochain_delta_ivector.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trideltas_nochain_delta_noivector.sh      --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_tdnn_trisat_chain_lda_ivector_fs3.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_lda_noivector_fs3.sh         --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_lda_ivector_nofs.sh          --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_lda_noivector_nofs.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_nochain_lda_ivector.sh             --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_nochain_lda_noivector.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_tdnn_trisat_chain_delta_ivector_fs3.sh         --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_delta_noivector_fs3.sh       --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_delta_ivector_nofs.sh        --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_chain_delta_noivector_nofs.sh      --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_nochain_delta_ivector.sh           --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"
bash run_tdnn_trisat_nochain_delta_noivector.sh         --fb-num-epochs 10 --decode false 2>&1 && echo "[$(date +'%F %T')] $0: ok"

bash run_align.sh 2>&1 && echo "[$(date +'%F %T')] $0: run_align.sh     ok"

e_time=$(date)

echo $s_time
echo $e_time
