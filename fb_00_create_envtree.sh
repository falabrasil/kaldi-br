#!/bin/bash
#
# Create environment tree for training acoustic models with CMU Sphinx
#
# Copyleft Grupo FalaBrasil (2018)
#
# Authors: Mar 2018
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# Federal University of Pará (UFPA)
#
# Reference: 
# http://kaldi-asr.org/doc/kaldi_for_dummies.html
# https://www.eleanorchodroff.com/tutorial/kaldi/kaldi-training.html

if test $# -ne 1
then
	echo "A script to create the environment tree for training acoustic models"
	echo "according to Kaldi's pattern."
	echo "Ref.: http://kaldi-asr.org/doc/kaldi_for_dummies.html"
	echo "Ref.: https://www.eleanorchodroff.com/tutorial/kaldi/kaldi-training.html"
	echo
	echo "Usage: $0 <proj_dir>"
	echo -e "\t<proj_dir> must be the path for your project folder *within* kaldi/egs parent dirs."
	echo -e "\te.g.: /home/cassio/kaldi/egs/MEUPROJETO"
	exit 1
elif [ -d $1 ]
then
	echo -n "'$1' exists as dir. Override? [y/N] "
	read ans
	if [[ "$ans" != "y" ]] 
	then
		echo "aborted."
		exit 0
	else
		echo "removing..."
		rm -rf $1
	fi
# https://stackoverflow.com/questions/8426058/getting-the-parent-of-a-directory-in-bash
elif [[ "$(basename $(readlink -f $(dirname "$1")))" != "egs" ]]
then
	echo "Error: '$1' must be inside /path/to/kaldi/egs"
	exit 1
fi

fb_dir=$(pwd)
DATA_DIR="$1"
KALDI_ROOT="$(readlink -f $(dirname "$(dirname "$1")"))"

mkdir -p $DATA_DIR
cd $DATA_DIR

mkdir local
#cp ../voxforge/s5/local/score.sh ./local
#cp ../rm/s5/local/score.sh ./local # larissa's suggestion - CB
cp ../wsj/s5/local/score.sh ./local # larissa's suggestion - CB

mkdir conf
echo \
"first_beam=10.0
beam=13.0
lattice_beam=6.0" > conf/decode.config

echo \
"--use-energy=false" > conf/mfcc.conf

mkdir -p data/train
touch data/train/{spk2gender,wav.scp,text,utt2spk,corpus.txt}

mkdir -p data/test
touch data/test/{spk2gender,wav.scp,text,utt2spk,corpus.txt}

mkdir -p data/local/dict
touch data/local/dict/{lexicon.txt,nonsilence_phones.txt,silence_phones.txt,optional_silence.txt}

echo \
"#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# $(date)
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

# Setting local system jobs (local CPU - no external clusters)
export train_cmd=run.pl
export decode_cmd=run.pl" > cmd.sh
chmod +x cmd.sh

echo \
"#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# $(date)
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

# Defining Kaldi root directory
export KALDI_ROOT=$KALDI_ROOT # TODO: check correctness -- CB

# Setting paths to useful tools 
export PATH=\$PWD/utils/:\$KALDI_ROOT/src/bin:\$KALDI_ROOT/tools/openfst/bin:\$KALDI_ROOT/src/fstbin/:\$KALDI_ROOT/src/gmmbin/:\$KALDI_ROOT/src/featbin/:\$KALDI_ROOT/src/lmbin/:\$KALDI_ROOT/src/sgmm2bin/:\$KALDI_ROOT/src/fgmmbin/:\$KALDI_ROOT/src/latbin/:\$KALDI_ROOT/src/nnet2bin/:\$PWD:\$PATH

# Defining audio data directory (TODO modify it for your installation directory!)
export DATA_ROOT=\"/home/{user}/kaldi-trunk/egs/digits/digits_audio\"

# Enable SRILM 
. \$KALDI_ROOT/tools/env.sh
 
# Variable needed for proper data sorting
export LC_ALL=C" > path.sh
chmod +x path.sh

echo \
"#!/bin/bash
#
# Cassio Batista   - cassio.batista.13@gmail.com
# Ana Larissa Dias - larissa.engcomp@gmail.com
# $(date)
# http://kaldi-asr.org/doc/kaldi_for_dummies.html
" | cat - ${fb_dir}/util/run.sh > run.sh
chmod +x run.sh

#cp -r ../wsj/s5/utils .
#cp -r ../wsj/s5/steps .
ln -s ../wsj/s5/utils . 
ln -s ../wsj/s5/steps . 
ln -s ../../src . 

[[ -z $(which tree) ]] || \
	(tree -FL 1 | grep -v '/$' | head -n -2 && \
	tree local conf data | head -n -1)
echo "check out your project dir at '$(readlink -f $DATA_DIR)'"

echo "'$0' finished"

### EOF ###
