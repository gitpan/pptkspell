cp doptkphots.sh /usr/bin
cp pptkspell.pl /usr/local/bin/pptkspell
chmod +x /usr/local/bin/pptkspell
cp lib/libhunspell.so.1.0.1 /usr/local/lib
# to link (otherwise ld does not find .so):
ln -s /usr/local/lib/libhunspell.so.1.0.1 /usr/local/lib/libhunspell.so
# to execute: (otherwise .so library not found):
ln -s /usr/local/lib/libhunspell.so.1.0.1 /usr/lib/libhunspell.so.1
