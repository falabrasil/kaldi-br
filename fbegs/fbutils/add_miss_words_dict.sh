#!/bin/bash
#
# A script that add the transcription of words unseen during acoustic model 
# train to the lexicon file
#
# Grupo FalaBrasil (2018)
# Federal University of Pará (UFPA)
#
# Author: September 2019
# Cassio Batista - cassio.batista.13@gmail.com

function print_fb_ascii() {
	echo -e "\033[94m  ____                         \033[93m _____     _           \033[0m"
	echo -e "\033[94m / ___| _ __ _   _ _ __   ___  \033[93m|  ___|_ _| | __ _     \033[0m"
	echo -e "\033[94m| |  _ | '__| | | | '_ \ / _ \ \033[93m| |_ / _\` | |/ _\` |  \033[0m"
	echo -e "\033[94m| |_| \| |  | |_| | |_) | (_) |\033[93m|  _| (_| | | (_| |    \033[0m"
	echo -e "\033[94m \____||_|   \__,_| .__/ \___/ \033[93m|_|  \__,_|_|\__,_|    \033[0m"
	echo -e "                  \033[94m|_|      \033[32m ____                _ _\033[0m\033[91m  _   _ _____ ____    _   \033[0m"
	echo -e "                           \033[32m| __ ) _ __ __ _ ___(_) |\033[0m\033[91m| | | |  ___|  _ \  / \          \033[0m"
	echo -e "                           \033[32m|  _ \| '_ / _\` / __| | |\033[0m\033[91m| | | | |_  | |_) |/ ∆ \        \033[0m"
	echo -e "                           \033[32m| |_) | | | (_| \__ \ | |\033[0m\033[91m| |_| |  _| |  __// ___ \        \033[0m"
	echo -e "                           \033[32m|____/|_|  \__,_|___/_|_|\033[0m\033[91m \___/|_|   |_|  /_/   \_\       \033[0m"
	echo -e ""
}

if test $# -ne 3
then
    print_fb_ascii
    echo "Usage: (bash) $0 <nlp_jarpath> <word_list> <huge_lexicon>"
    echo -e "\t<nlp_jarpath> is the path to the 'fb_nlplib.jar' file which contains the g2p software."
    echo -e "\t<word_list> is a text file containing a list of words, one word per line."
    echo -e "\t<huge_lexicon> must be the 'lexicon.txt' file under the 'kaldi/egs' project dir."
    echo -e "\te.g.: ${HOME}/kaldi/egs/MEUPROJETO"
    exit 1
elif [[ ! -f $1 ]] || [[ "$(basename $1)" != "fb_nlplib.jar" ]]
then
    echo "'$1' is not the FalaBrasil's NLP lib jar file."
    exit 1
elif [[ ! -f $2 ]] 
then
    echo "'$2' is not a valid file. remember the first arg must be a list of " \
        "words missing at the 'lexicon.txt' file." 
    exit 1
elif [[ ! -f $3 ]] 
then
    echo "'$3' is not a valid file. remember the second arg must be the full " \
        "lexicon dictionary generated during the acoustic model training."
    exit 1
fi 

if [[ "$(basename $3)" != "lexicon.txt" ]] 
then
    echo -e "\033[91mWARNING\033[0m: '$3' should be named 'lexicon.txt'. beware!"
fi

java -jar $1 -iog $2 dict.tmp 
cat dict.tmp >> $3
sort $3 | uniq > dict.tmp
mv dict.tmp $3

echo "done. check '$(readlink -f $3)' to check whether those words were correctly included."
### EOF ###
