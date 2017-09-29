#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

install -m 755 media_scripts.sh /usr/local/bin/media_scripts
echo "DONE!"
