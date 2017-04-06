#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

#IFS=$'\n'
shopt -s nullglob #prevent null files
shopt -s globstar # for recursive for loops


# declare variables
inputs=""
maps=""
vopts=""
aopts=""
filters=""

# If no directory argument is given, put output in subfolder
if [ "$1" = "" ]; then
	outdir="completed"
else
	outdir="$1"
fi

# ask video codec question
echo " "
echo "Which Video codec to use?"
select opt in "copy" "h264" "h264_fast" "h265_8bit" "h265_8bit_fast" "h265_10bit" "exit"; do
	case $opt in
	copy )
		vopts="-c:v copy"
		break;;
	h264 )
		vopts="-c:v libx264 -preset veryslow -crf 18"
		break;;
	h264_fast )
		vopts="-c:v libx264 -preset fast -crf 18"
		break;;
	h265_8bit )
		vopts="-c:v libx265 -preset slow -crf 21 -x265-params profile=main"
		break;;
	h265_8bit_fast )
		vopts="-c:v libx265 -preset fast -crf 21 -x265-params profile=main"
		break;;
	h265_10bit )
		vopts="-c:v libx265 -preset slow -crf 21 -x265-params profile=main10"
		break;;
	exit )
		exit;;
	*)
		echo "invalid option"
		esac
done

# ask audio codec question
echo " "
echo "Which audio codec to use?"
echo "libfdk_aac is better but only available on newer ffmpeg"
echo "both assume 160kbps stereo, and dts5.1 should be copied"
echo "this is really just for encoding mp3 and ac3 stereo"
select opt in "copy" "aac" "libfdk_aac" "exit"; do
	case $opt in
	copy )
		aopts="-c:a copy"
		break;;
	aac )
		aopts="-c:a aac -b:a 160k"
		break;;
	libfdk_aac )
		aopts="-c:a libfdk_aac -b:a 160k"
		break;;
	exit )
		exit;;
	*)
	echo "invalid option"
	esac
done

# ask delinterlacing filter question
echo " "
echo "use delinterlacing filter?"
echo "bwdif is a better filter but only works on newer ffmpeg"
echo "cropping takes off 2 pixels from top and bottom which removes"
echo "some interlacing artifacts from old dvds"
select opt in "none" "w3fdif" "w3fdif_crop" "bwdif" "bwdif_crop" "hflip" "exit"; do
	case $opt in
	none )
		filters=""
		break;;
	w3fdif )
		filters="-vf \"w3fdif\""
		break;;
	w3fdif_crop )
		filters="-vf \"crop=in_w:in_h-4:0:2, w3fdif\""
		break;;
	bwdif )
		filters="-vf \"bwdif\""
		break;;
	bwdif_crop )
		filters="-vf \"crop=in_w:in_h-4:0:2, bwdif\""
		break;;
	hflip )
		filters="-vf \"hflip\""
		break;;
	exit )
		exit;;
	*)
		echo "invalid option"
		esac
done

# ask run options
echo " "
echo "preview ffmpeg command, do a 1 minute sample, or run everything now?"
select opt in "preview" "sample" "run_now" "exit"; do
	case $opt in
	preview ) 
		lengthopts=""
		preview="yes"
		break;;
	sample )
		lengthopts="-t 00:01:00.0"
		preview="no"
		break;;
	run_now ) 
		lengthopts=""
		preview="no"
		break;;
	exit )
		exit;;
	*)
		echo "invalid option"
		esac
done


# loop through all input files
for f in **/*.mkv **/*.MKV **/*.MP4 **/*.mp4 **/*.avi **/*.AVI
do
	# get new file name with extention stripped
	fname="${f%.*}"
	subdir=$(dirname "${f}")
	outfile="\"$outdir/$fname.mkv\""

	# skip if file is in the output directory
	if [[ $outdir == $subdir* ]]; then
		continue
	fi
	
	# if an associated sub exists, embed it and ignore subs in video
	if [ -e "$fname.srt" ]; then # add subs if they exist
		inputs=" -i \"$f\" -i \"$fname.srt\""
		subopts="-c:s copy -metadata:s:s:0 language=eng"
		maps=" -map 0:v -map 0:a -map 1:s"
	else
		inputs=" -i \"$f\""
		subopts="-c:s copy"
		maps=""
	fi

	#combine options into ffmpeg string
	command="ffmpeg $inputs $maps $vopts $lengthopts $filters $aopts $subopts $outfile"

	# off we go!!
	if [ $preview == "yes" ]; then
		echo " "
		echo $command
	else
		mkdir -p "$outdir/$subdir"
		eval $command
	fi

done


echo " "
echo "DONE"



