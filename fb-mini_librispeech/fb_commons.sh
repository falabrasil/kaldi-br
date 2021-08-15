PRF="took %E secs (user: %U. system: %S).\tRAM: %M KB"
function msg { echo -e "\e[$(shuf -i 92-96 -n 1)m[$(date +'%F %T')] $1\e[0m" ; }
