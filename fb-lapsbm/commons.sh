PRF="took %E (user: %U secs, system: %S secs)\tRAM: %M KB"
function msg { echo -e "\e[$(shuf -i 92-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }
