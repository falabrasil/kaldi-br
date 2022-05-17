#!/usr/bin/env bash
#
# Downloads stuff beforehand.
# Useful for AWS setup, to stop wasting time
# download data and compiling stuff by hand.
#
# author: jun 2021
# cassio batista - https://cassota.gitlab.io

# download data
ROOT_DIR=$HOME/fb-gitlab/fb-audio-corpora
mkdir -p $ROOT_DIR

for dir in male-female-aligned alcaim16k-DVD1de4 ; do
  [ -d $ROOT_DIR/$dir ] || \
    git clone https://cassota@gitlab.com/fb-audio-corpora/$dir.git $ROOT_DIR/$dir
done

# download and compile M2M-aligner
ROOT_DIR=$HOME/git-all
mkdir -p $ROOT_DIR

dir=m2m-aligner
[ -d $ROOT_DIR/$dir ] || \
  git clone https://github.com/letter-to-phoneme/$dir.git $ROOT_DIR/$dir
cd $ROOT_DIR/$dir
make
cd -
