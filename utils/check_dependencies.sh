#!/usr/bin/env bash
#
# Check if dependencies are installed
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: nov 2020
# cassio batista - https://cassota.gitlab.io
# last update: apr 2022


ok=true
[ ! -f /usr/bin/time ] && echo "$0: please install time" && ok=false
for f in wget gzip tar unzip gawk opusdec sox python3; do
  ! type -f "$f" > /dev/null 2>&1 && ok=false && \
    echo "$0: error: please install '$f'"
done

[ -z "$(locale -a | grep ^pt_BR)" ] && ok=false && \
  echo "$0: please enable 'pt_BR' in your linux locale"

for f in dvc pandas ; do
  ! python3 -c "import $f" > /dev/null 2>&1 && ok=false && \
    echo "$0: error: please install python package '$f'"
done

$ok || exit 1
