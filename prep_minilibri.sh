#!/bin/bash
#
# Create environment tree for training acoustic models with Kaldi.
# This scripts used to be called 'fb_00' in the old days.
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# Author: Apr 2020
# Cassio Batista - https://cassota.gitlab.io/
# Last update: Apr 2021


utils/check_dependencies.sh || exit 1

src_dir=$(readlink -f fb-mini_librispeech)

if test $# -ne 1 ; then
  echo "usage: $0 [options] <proj_dir>"
  echo "  <proj_dir> path for your project *within* kaldi/egs dir."
  echo "    e.g.: ./$0 ${HOME}/kaldi/egs/MEUPROJETO"
  exit 1
fi

proj_dir="$1"
if [ -d "$proj_dir" ] ; then
  echo -n "$0: warning: dir '$proj_dir' exists. Overwrite? [y/N] "
  read ans
  if [ "$ans" != "y" ] ; then
    echo "$0: aborted." && exit 0
  else
    rm -rf $proj_dir/s5/{data,exp,mfcc,fblocal,fbutils}
  fi
# https://stackoverflow.com/questions/8426058/getting-the-parent-of-a-directory-in-bash
elif [ $(basename $(readlink -f $(dirname $proj_dir))) != "egs" ] ; then
  echo "$0: error: '$proj_dir' must be inside /path/to/kaldi/egs"
  exit 1
fi

KALDI_ROOT=$(readlink -f $(dirname $(dirname $proj_dir)))
minilibri_dir=$KALDI_ROOT/egs/mini_librispeech/s5
proj_dir=$(readlink -f $proj_dir)/s5
mkdir -p $proj_dir
ln -sf $src_dir/{fblocal,fbutils} $proj_dir
cp -v $src_dir/{fb_commons,path,run*}.sh $proj_dir || exit 1
ln -sf $minilibri_dir/{conf,local,steps,utils} $proj_dir
sed 's/"queue.pl/"run.pl/g' $minilibri_dir/cmd.sh > $proj_dir/cmd.sh

tree -C $proj_dir -I corpus 2> /dev/null
echo "$0: all set up! check out your project at '$proj_dir'" 
