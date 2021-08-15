#!/bin/bash
#
# author: may 2020
# cassio batista - https://cassota.gitlab.io/

python -c "import vosk" || { echo "$0: please install vosk" && exit 1; }

MODEL_PATH=$HOME/Downloads/vosk-model-small-pt-0.3/
for wav in $(find . -name "*.wav") ; do
    txt=$(echo $wav | sed 's/\.wav/.txt/g')
    (play -q $wav)&
    printf "%-20s: " "$wav"
    cat $txt | lolcat
    printf "%-20s: " "Vosk"
    python test_vosk_simple.py $MODEL_PATH $wav 2>/dev/null | \
      grep -w '"text"' | cut -d ':' -f 2 | sed 's/"//g' | sed 's/^ //g'
    wait
done
