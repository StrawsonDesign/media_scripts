#!/bin/bash

ffull="test.mkv"
orig_vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_vbitrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_acodec0=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_acodec1=$(ffprobe -v error -select_streams a:1 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $ffull)
orig_scodec=$(ffprobe -v error -select_streams s:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $ffull)


## detect DVD video
if [ $orig_vcodec -eq "mpeg2video" ]; then
	vopts="-c:v libx264 -preset slow -b:v 2M"
	filters="-vf \"bwdif\""
	profile="-profile:v baseline -level 3.0"
	using_libx264=true;
	twopass="x264";

## detect h264 (bluray, webdl)
elif [ $orig_vcodec -eq "h264" ]; then
	## catch videos larger than 1920x1080
	## these videos should be dealt with manually
	if [ $orig_width -gt "1930"]; then
