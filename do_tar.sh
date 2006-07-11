cp /mnt/win_d/hattyu/tyuk/dtest/python/danielnaber/cvs1/languagetool/tools/* gramchk
rm -rf gramchk/*~
rm -rf *~
tar cvf pptkspell.tar pptkspell.pl do_tar.sh doptkphots.sh install.sh readme  gramchk/* lib/*
gzip pptkspell.tar
cp pptkspell.tar.gz /mnt/win_d/hattyu/tyuk/homepages/tkltrans.sourceforge/magyar
cp pptkspell.tar.gz /mnt/floppy