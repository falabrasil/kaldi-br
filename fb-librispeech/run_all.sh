
bash run_data_prep.sh || exit 1

bash run_gmm.sh || exit 1

bash run_ivector_common.sh || exit 1

bash run_tdnn_chain_1d.sh || exit 1
