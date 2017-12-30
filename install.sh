#!/bin/bash



if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit 1
fi

#install -m 755 media_scripts.sh /usr/local/bin/media_scripts

sudo ln -s media_scripts.sh /usr/local/bin/media_scripts
sudo apt install ffmpeg mkvtoolnix
sudo dpkg -i bdsup2sub-5.1.2.deb vobsub2srt-1.0pre7-11-g0ba6e25-Linux.deb

echo "DONE!"
