#
# posi.sh creates sorted error file for coloring/TKLSpell
# first parameter: languagetool's home directory
# second parameter: pathname of file to be checked
# third parameter: language (en, de or hu)
# result goes into languagetool/tools/checkout.txt
# calling example:
#sh posi.sh 
#/mnt/win_d/hattyu/tyuk/dtest/python/danielnaber/cvs3/languagetool #/home/en/tyuk/dtest/qt/examples/richedit2/lang/work/chk.txt
# hu
#
# this file will be used by TKLSpell
#
cd $1
base=`basename $2`
perl $1/tools/xml1.pl $1 $2 $3  >/tmp/1_$base
sort -n /tmp/1_$base >$1/tools/checkout.txt
rm -f /tmp/1_$base
