#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

install -m 755 ffmpeg_helper.sh /usr/local/bin/ffmpeg_helper
install -m 755 extract_subs.sh /usr/local/bin/extract_subs
echo "DONE!"
