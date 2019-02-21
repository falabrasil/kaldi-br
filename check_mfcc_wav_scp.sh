
if test $# -ne 1
then
	echo "Usage: $0 <proj_dir>"
	echo -e "\t<proj_dir> must be the path for your project folder *within* kaldi/egs parent dirs."
	echo -e "\te.g.: /home/cassio/kaldi/egs/MEUPROJETO"
	exit 1
fi

echo "checking on train folder..."
awk '{print $1}' ${1}/data/train/wav.scp    > train.scp
awk '{print $1}' ${1}/data/train/feats.scp >> train.scp
if [[ $(sort train.scp | uniq -u | wc -l) == 0  ]] ; then
	echo "no problems in train folder."
else
	echo "problems occured with these files below: "
	sort train.scp | uniq -u 
fi

echo "checking on test folder..."
awk '{print $1}' ${1}/data/test/wav.scp    > test.scp
awk '{print $1}' ${1}/data/test/feats.scp >> test.scp
if [[ $(sort test.scp | uniq -u | wc -l) == 0  ]] ; then
	echo "no problems in test folder."
else
	echo "problems occured with these files below: "
	sort test.scp | uniq -u 
fi

rm -f {train,test}.scp
echo "done"
### EOF ###
