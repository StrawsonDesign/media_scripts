#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

#IFS=$'\n'
shopt -s nullglob #prevent null files
shopt -s globstar # for recursive for loops


# constant options
video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
metadata="-metadata Title=\"\" $video_metadata $audio_metadata $sub_metadata"

# other general options
# -n auto-skips files if completed
other="-n"

# If no directory argument is given, put output in subfolder
if [ "$1" = "" ]; then
	outdir="completed"
else
	outdir="$1"
fi

# ask video codec question
echo " "
echo "Which Video codec to use?"
select opt in "libx264_good_slow" "libx264_good_fast" "libx264_better_fast" "libx264_better_slow"  "nvenc_h264" "h265_8bit" "h265_8bit_fast" "h265_10bit" "copy"; do
	case $opt in
	copy )
		vopts="-c:v copy"
		break;;
	libx264_better_slow )
		vopts="-c:v libx264 -preset slow -crf 18"
		break;;
	libx264_better_fast )
		vopts="-c:v libx264 -preset fast -crf 18"
		break;;
	libx264_good_slow )
		vopts="-c:v libx264 -preset slow -crf 21"
		break;;
	libx264_good_fast )
		vopts="-c:v libx264 -preset fast -crf 21"
		break;;
	nvenc_h264 )
		vopts="-c:v h264_nvenc -cq 18 -preset slow"
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
	*)
		echo "invalid option"
		esac
done

# ask audio codec question
echo " "
echo "Which audio codec to use?"
echo "libfdk_aac is better but only available on newer ffmpeg"
echo "128k for stereo, 384k for 5.1 surround"
select opt in  "aac_128" "aac_384" "libfdk_aac_128" "libfdk_aac_384" "copy"; do
	case $opt in
	copy )
		aopts="-c:a copy"
		break;;
	aac_128 )
		aopts="-c:a aac -b:a 128k"
		break;;
	aac_384 )
		aopts="-c:a aac  -b:a 384k"
		break;;
	libfdk_aac_128 )
		aopts="-c:a libfdk_aac -b:a 128k"
		break;;
	libfdk_aac_384 )
		aopts="-c:a libfdk_aac -b:a 384k"
		break;;
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
select opt in "none" "w3fdif" "w3fdif_crop" "bwdif" "bwdif_crop" "hflip"; do
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
	*)
		echo "invalid option"
		esac
done

# ask run options
echo " "
echo "preview ffmpeg command, do a 1 minute sample, 60 second sample, or run everything now?"
select opt in "run_now" "preview" "sample1" "sample60" "sample60_middle" "exit"; do
	case $opt in
	preview ) 
		lopts=""
		preview="yes"
		break;;
	sample1 )
		lopts="-t 00:00:01.0"
		preview="no"
		break;;
	sample60 )
		lopts="-t 00:01:00.0"
		preview="no"
		break;;
	sample60_middle )
		lopts="-ss 00:05:00.0 -t 00:01:00.0"
		preview="no"
		break;;
	run_now ) 
		lopts=""
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
	out="\"$outdir/$fname.mkv\""

	# skip if file is in the output directory
	if [[ $outdir == $subdir* ]]; then
		continue
	fi
	
	# if an associated sub exists, embed it and ignore subs in video
	if [ -e "$fname.srt" ]; then # add subs if they exist
		ins=" -i \"$f\" -i \"$fname.srt\""
		sopts="-c:s srt"
		maps=" -map 0:v:0 -map 0:a:0 -map 1:s"
	else
		ins=" -i \"$f\""
		sopts="-c:s copy"
		maps="-map 0:v:0 -map 0:a:0 -map 0:s:0"
	fi

	#combine options into ffmpeg string
	command="ffmpeg $ins $maps $vopts $lopts $filters $aopts $sopts $other $metadata $out"

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



