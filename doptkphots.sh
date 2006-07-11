# doptkphots.sh
awk -f /mnt/win_d/hattyu/tyuk/dtest/txt2speech/txt2pho/tts-magyar/segedeszkozok/szam.awk <$1 >/tmp/x1.txt
perl /mnt/win_d/hattyu/tyuk/dtest/txt2speech/txt2pho/tts-magyar/segedeszkozok/xttp.pl f1 < /tmp/x1.txt >/tmp/x.pho

