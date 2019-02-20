
if test $# -ne 1
then
	echo "usage: bash ${0} <audio_dataset_dir>"
	echo -e "\t<audio_dataset_dir> is the folder that contains all your audio base (wav + transcript.)."
	exit 1
fi

find $1 -name "*.wav" > wavlist.orig
cat wavlist.orig | sed 's/\// /g' | awk '{print $NF}' > wavlist.uniq

wc -l wavlist.*
rm wavlist.*
