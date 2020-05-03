#!/bin/bash
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

if test $# -lt 1 ; then
    echo "usage: $0 <wav-prefix>"
    echo "  <wav-prefix> can be either a dir or a prefix for a group of files"
    exit 1
fi

prefix=$1
[ -d $prefix ] && prefix=$prefix/

n=$(find $prefix*.wav 2>/dev/null | wc -l)
if [ $n -eq 0 ] ; then
    echo "$0: error: no wav files found"
    exit 1
elif [ $n -eq 1 ] ; then
    echo "$prefix*: $(soxi -d $prefix*.wav)"
else
    echo "$prefix*: $(soxi $prefix*.wav | tail -n 1 | awk '{print $NF}')"
fi

exit 0
