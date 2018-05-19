#!/bin/bash



if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit 1
fi


echo ""
echo "Do you want to install just media_scripts.sh or its dependencies too?"
#echo "note, mapping all english audio tracks also maps all english subtitles"
#echo "and subtitle mode is forced to auto"
select opt in  "script" "dependencies" ; do
case $opt in
script )
	break;;

dependencies )
	echo "installing dependencies"
	apt install ffmpeg mkvtoolnix liblept5 libtesseract-data tesseract-ocr libtesseract-dev libtesseract3 openjdk-8-jre
	dpkg -i BDSup2Sub.deb vobsub2srt-1.0pre7-11-g0ba6e25-Linux.deb
* )
	echo "invalid option"
	esac
done


echo "installing media_scripts.sh"
install -m 755 media_scripts.sh /usr/local/bin/media_scripts

echo "DONE!"
