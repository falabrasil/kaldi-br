#!/usr/bin/env bash
#

if [ -f path.sh ]; then . ./path.sh; fi

mkdir -p data/lang_test

arpa_lm=data/local/lm/lm_tglarge.arpa.gz  # cassota
[ ! -f $arpa_lm ] && echo "$0: No such file $arpa_lm" && exit 1;

cp -rT data/lang data/lang_test

gunzip -c "$arpa_lm" | \
   arpa2fst --disambig-symbol=#0 \
            --read-symbol-table=data/lang_test/words.txt - data/lang_test/G.fst

echo "$0: Checking how stochastic G is (the first of these numbers should be small):"
fstisstochastic data/lang_test/G.fst

## Check lexicon.
## just have a look and make sure it seems sane.
#echo "First few lines of lexicon FST:"
#fstprint   --isymbols=data/lang/phones.txt --osymbols=data/lang/words.txt data/lang/L.fst  | head

echo "$0: Performing further checks"

# Checking that G.fst is determinizable.
fstdeterminize data/lang_test/G.fst /dev/null || echo "$0: Error determinizing G."

# Checking that L_disambig.fst is determinizable.
fstdeterminize data/lang_test/L_disambig.fst /dev/null || echo "$0: Error determinizing L."

# Checking that disambiguated lexicon times G is determinizable
# Note: we do this with fstdeterminizestar not fstdeterminize, as
# fstdeterminize was taking forever (presumbaly relates to a bug
# in this version of OpenFst that makes determinization slow for
# some case).
fsttablecompose data/lang_test/L_disambig.fst data/lang_test/G.fst | \
   fstdeterminizestar >/dev/null || echo "$0: Error"

# Checking that LG is stochastic:
fsttablecompose data/lang/L_disambig.fst data/lang_test/G.fst | \
   fstisstochastic || echo "$0: [log:] LG is not stochastic"

echo "$0: build const arpa"
utils/build_const_arpa_lm.sh $arpa_lm data/lang data/lang_test_fg

echo "$0: succeeded"
