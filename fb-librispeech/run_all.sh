
bash run_data_prep.sh || exit 1

bash run_gmm.sh || exit 1

bash run_ivector_common.sh || exit 1

# now you might wanna choose which TDNN recipe you wish to run
