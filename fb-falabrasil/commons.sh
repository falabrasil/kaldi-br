function prf { /usr/bin/time -f "[perf] cmd '${1} ... ${!#}' took %E (user: %U secs, system: %S secs, wall-clock: %e secs)\tRAM: %M KB" "$@" ; }
function msg { echo -e "\e[$(shuf -i 92-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }
