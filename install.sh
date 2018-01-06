#!/bin/bash



if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit 1
fi

install -m 755 media_scripts.sh /usr/local/bin/media_scripts

#chmod +x media_scripts.sh
#sudo rm -f /usr/local/bin/media_scripts
#sudo ln -s  media_scripts.sh /usr/local/bin/media_scripts 
#sudo chmod +x /usr/local/bin/media_scripts
sudo apt install ffmpeg mkvtoolnix liblept5 libtesseract-data libtesseract-dev libtesseract3
sudo dpkg -i BDSup2Sub.deb vobsub2srt-1.0pre7-11-g0ba6e25-Linux.deb

echo "DONE!"
