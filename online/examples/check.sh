#!/bin/bash
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

for wav in $(find . -name "*.wav") ; do
    txt=$(echo $wav | sed 's/\.wav/.txt/g')
    (play -q $wav)&
    echo -n "$wav: "
    cat $txt | lolcat
    python3 test_vosk_simple.py $wav 2>/dev/null | grep "text"
    wait
done
