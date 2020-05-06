#!/bin/bash
#
# A script that creates the language files inside the data/local/dict/ dir
# (lexicon, nonsilence_phones, silence_phones and optional_silence)
# This scripts was used to be called 'fb_02' in the old days.
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: apr 2020
# cassio batista - https://cassota.gitlab.io/
#
# Reference:
# http://kaldi-asr.org/doc/kaldi_for_dummies.html

nj=2  # TODO CB: speed up lexiconp.txt?

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if test $# -ne 1 ; then
    echo "Usage: $0 <nlp-dir> <data-dir>" 
    echo "  <data-dir> is the folder to store the files create."
    echo "    e.g.: $0 ${HOME}/fb-gitlab/fb-nlp/nlp-generator ./data/local/dict"
    exit 1
elif [ ! -d $1 ] ; then
    echo "Error: '$1' must be a dir"
    exit 1
fi

if [ -z "$(locale -a | grep ^pt_BR)" ] ; then
    echo "$0: please enable 'pt_BR' in your linux locale"
    exit 1
fi

export LC_ALL=pt_BR.UTF-8

data_dir=$1

# 0) create wordlist
# eight
# five
# four
# nine
# one
function create_wordlist() {
    # FIXME CB: this is bad!
    for corpus in $(find ${1}/../.. -name corpus.txt) ; do
        echo "$0: creating wordlist from ${corpus}..."
        for word in $(cat $corpus | dos2unix | tr '[A-Z]' '[a-z]' | tr "\'" " " | sed 's/[,.;<>:?!1234"567890()@%]/ /g') ; do
            echo $word >> wlist.tmp
        done 
    done
    sort wlist.tmp | uniq > wordlist.tmp
}

# a.) lexicon.txt
# !SIL sil
# <UNK> spn
# eight ey t
# five f ay v
# four f ao r
function create_lexicon() {
    echo "$0: adding UNK and SIL to lexicon.txt..."
    echo -e "!SIL\tsil"   > dict.tmp
    echo -e "<UNK>\tspn" >> dict.tmp
    cat $1/lexicon.txt   >> dict.tmp
    mv dict.tmp $1/lexicon.txt
}

# b.) create nonsilence_phones.txt
# ah
# ao
# ay
# eh
function create_nonsilence_phones() {
    echo "$0: creating nonsilence_phones.txt file... "
    tail -n +3 $1/lexicon.txt | awk '{$1="" ; print}' > plist.tmp
    for phone in $(cat plist.tmp) ; do
        echo $phone >> phonelist.tmp
    done
    sort phonelist.tmp | uniq > $1/nonsilence_phones.txt
}

# c.) create silence_phones.txt
# sil
# spn
function create_silence_phones() {
    echo "$0: creating silence_phones.txt file... "
    echo "sil"  > $1/silence_phones.txt
    echo "spn" >> $1/silence_phones.txt
}

# d.) create optional_silence.txt
# sil
function create_optional_silence() {
    echo "$0: creating optional_silence.txt file... "
    echo "sil"  > $1/optional_silence.txt
}

# copied from local/prepare_dict.sh -- CB
function create_extra_questions() {
    cat $1/silence_phones.txt | perl -e \
        'while(<>){
            foreach $p (split(" ", $_)) {
                $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; 
                $q{$2} .= "$p ";
            }
        }
        foreach $l (values %q) {
            print "$l\n";
        }' >> $1/extra_questions.txt || exit 1;
}

mkdir -p $data_dir
rm -f *.tmp
create_wordlist $data_dir || exit 1
create_lexicon $data_dir || exit 1
create_nonsilence_phones $data_dir || exit 1
create_silence_phones $data_dir || exit 1
create_optional_silence $data_dir || exit 1
create_extra_questions $data_dir || exit 1

rm -f *.tmp
exit 0
