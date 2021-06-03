#!/usr/bin/env bash
#
# Check if dependencies are installed
#
# Grupo FalaBrasil (2020)
# Federal University of Pará (UFPA)
#
# author: nov 2020
# cassio batista - https://cassota.gitlab.io

deps_ok=true
for f in wget gzip tar unzip gawk ; do
    if ! type -t "$f" > /dev/null ; then
        echo "$0: error: please install '$f'"
        deps_ok=false
    fi
done

python -c "import scipy" || { echo "$0: error: please install python 'scipy'" && deps_ok=false; }

$deps_ok || exit 1
