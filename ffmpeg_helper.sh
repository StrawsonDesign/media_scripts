#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

#IFS=$'\n'
shopt -s nullglob #prevent null files
shopt -s globstar # for recursive for loops


# constant options
video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
# start with map for video, add to it later
maps="-map 0:v:0"
using_libx264=false;
using_external_sub=false;

# other general options
# -n auto-skips files if completed
other="-n"
preview=false

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
		using_libx264=true;
		break;;
	libx264_better_fast )
		vopts="-c:v libx264 -preset fast -crf 18"
		using_libx264=true;
		break;;
	libx264_good_slow )
		vopts="-c:v libx264 -preset slow -crf 21"
		using_libx264=true;
		break;;
	libx264_good_fast )
		vopts="-c:v libx264 -preset fast -crf 21"
		using_libx264=true;
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

# ask video quality question is using libx264
if $using_libx264 ; then
	echo " "
	echo "which h264 level, 4.1 recommended for most bluray"
	select opt in "auto" "3.1_dvd" "4.1_1080_30" "4.2_1080_60"; do
		case $opt in
		auto )
			break;;
		3.1_dvd )
			vopts="$vopts -profile:v baseline -level 3.1"
			break;;
		4.1_1080_30 )
			vopts="$vopts -profile:v high -level 4.1" 
			break;;
		4.2_1080_60 )
			vopts="$vopts -profile:v high -level 4.2" 
			break;;
		*)
			echo "invalid option"
			esac
	done
fi

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

# ask audio codec question
echo " "
echo "Which audio codec to use?"
select opt in  "aac_stereo" "aac_5.1" "copy"; do
	case $opt in
	copy )
		aopts="-c:a copy"
		break;;
	aac_stereo )
		aopts="-c:a aac -b:a 160k"
		break;;
	aac_5.1 )
		aopts="-c:a aac -b:a 480k"
		break;;
	*)
	echo "invalid option"
	esac
done

# ask audio tracks question
echo " "
echo "Which audio tracks to use?"
select opt in  "first" "all" "first+commentary"; do
	case $opt in
	first )
		maps="$maps -map 0:a:0"
		break;;
	all )
		maps="$maps -map 0:a"
		audio_metadata=""
		break;;
	first+commentary )
		maps="$maps -map 0:a:1"
		audio_metadata="$audio_metadata -metadata:s:a:1 Title=\"Commentary\" -metadata:s:a:1 language=eng"
		break;;
	*)
	echo "invalid option"
	esac
done

# ask subtitle question
echo " "
echo "What to do with subtitles?"
select opt in  "keep_all" "keep_first" "use_external_srt" "none"; do
	case $opt in
	keep_all )
		maps="$maps -map 0:s"
		subtitle_metadata=""
		sopts="-c:s copy"
		break;;
	keep_first )
		maps="$maps -map 0:s:0"
		sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
		sopts="-c:s copy"
		break;;
	use_external_srt )
		maps="$maps -map 1:s"
		sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
		sopts="-c:s copy"
		using_external_sub=true;
		break;;
	none )
		subtitle_metadata=""
		sopts=""
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
		preview=true
		break;;
	sample1 )
		lopts="-t 00:00:01.0"
		break;;
	sample60 )
		lopts="-t 00:01:00.0"
		break;;
	sample60_middle )
		lopts="-ss 00:05:00.0 -t 00:01:00.0"
		break;;
	run_now ) 
		lopts=""
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
	out="$outdir/$fname.mkv"

	# skip if file is in the output directory
	if [[ $outdir == $subdir* ]]; then
		continue
	fi
	
	# skip if file is compelete
	if [ -f "$out" ]; then
		echo "skipping: $f"
		continue
	fi
	
	# if using external subtitles, add to inputs
	ins=" -i \"$f\""
	if $using_external_sub; then
		ins="$ins -i \"$fname.srt\""
	fi

	#combine options into ffmpeg string
	metadata="-metadata Title=\"\" $video_metadata $audio_metadata $sub_metadata"
	command="ffmpeg $ins $maps $vopts $lopts $filters $aopts $sopts $other $metadata \"$out\""

	# off we go!!
	if $preview ; then
		echo " "
		echo "preview:"
		echo " "
		echo $command
	else
		mkdir -p "$outdir/$subdir"
		if eval "$command"; then
			echo "ffmpeg success"
		else
			echo " "
			echo "ffmpeg failure: $f"
			exit
		fi
	fi

done


echo " "
echo "DONE"



