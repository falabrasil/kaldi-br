
set -e

rm -rf data exp mfcc

s_time=$(date)

bash run_data_prep.sh
bash run_gmm.sh
bash run_ivector_common.sh

bash run_tdnn_mono_chain_lda_ivector_fs3.sh       --fb-num-epochs 1 && echo "$0: run_tdnn_mono_chain_lda_ivector_fs3.sh    ok"
bash run_tdnn_mono_chain_lda_noivector_fs3.sh     --fb-num-epochs 1 && echo "$0: run_tdnn_mono_chain_lda_noivector_fs3.sh  ok"
bash run_tdnn_mono_nochain_lda_ivector.sh         --fb-num-epochs 1 && echo "$0: run_tdnn_mono_nochain_lda_ivector.sh      ok"
bash run_tdnn_mono_nochain_lda_noivector.sh       --fb-num-epochs 1 && echo "$0: run_tdnn_mono_nochain_lda_noivector.sh    ok"

bash run_tdnn_trisat_chain_lda_ivector_fs3.sh     --fb-num-epochs 1 && echo "$0: run_tdnn_trisat_chain_lda_ivector_fs3.sh       ok"
bash run_tdnn_trisat_chain_lda_noivector_fs3.sh   --fb-num-epochs 1 && echo "$0: run_tdnn_trisat_chain_lda_noivector_fs3.sh     ok"
bash run_tdnn_trisat_nochain_lda_ivector.sh       --fb-num-epochs 1 && echo "$0: run_tdnn_trisat_nochain_lda_ivector.sh         ok"
bash run_tdnn_trisat_nochain_lda_noivector.sh     --fb-num-epochs 1 && echo "$0: run_tdnn_trisat_nochain_lda_noivector.sh       ok"

e_time=$(date)

echo $s_time
echo $e_time
