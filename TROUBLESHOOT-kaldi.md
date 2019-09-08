# Troubleshooting with Kaldi

**Problem log**: 
```text
[./run_gmm.sh 08/09/19 13:17] TRIPHONE 1 TRAINING =====

steps/train_deltas.sh --cmd run.pl 500 2000 data/train data/lang exp/mono_ali exp/tri1
steps/train_deltas.sh: accumulating tree stats
steps/train_deltas.sh: getting questions for tree-building, via clustering
steps/train_deltas.sh: building the tree
WARNING (gmm-init-model[5.5.452-3f95]:InitAmGmm():gmm-init-model.cc:55) Tree has pdf-id 1 with no stats; corresponding phone list: 6 7 8 9 10 
** The warnings above about 'no stats' generally mean you have phones **
** (or groups of phones) in your phone set that had no corresponding data. **
** You should probably figure out whether something went wrong, **
** or whether your data just doesn't happen to have examples of those **
** phones. **
```

**Solution**: 
```text
Probably in your setup you had no OOV words in training so nothing got mapped to OOV.
I wouldn't worry about this.
Dan
```

**Source**:   
https://sourceforge.net/p/kaldi/mailman/message/32111273/
