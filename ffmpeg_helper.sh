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
vmaps="-map 0:v:0"
using_libx264=false;
using_external_sub=false;
auto_subs=false;
map_all_eng=false;
audio_metadata=""
sopts="-c:s copy"
subtitle_metadata=""

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
select opt in "x264_rf18_slow" "x264_rf20_slow" "x264_rf20_fast" "x264_18_fast" "nvenc_h264" "h265_8bit" "h265_8bit_fast" "h265_10bit" "copy"; do
	case $opt in
	copy )
		vopts="-c:v copy"
		break;;
	x264_rf18_slow )
		vopts="-c:v libx264 -preset slow -crf 18"
		using_libx264=true;
		break;;
	x264_rf18_fast )
		vopts="-c:v libx264 -preset fast -crf 18"
		using_libx264=true;
		break;;
	x264_rf20_slow )
		vopts="-c:v libx264 -preset slow -crf 20"
		using_libx264=true;
		break;;
	x264_rf20_fast )
		vopts="-c:v libx264 -preset fast -crf 20"
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
	select opt in "4.1_1080" "3.1_dvd" "auto" "4.2_1080"; do
		case $opt in
		auto )
			break;;
		3.1_dvd )
			vopts="$vopts -profile:v baseline -level 3.1"
			break;;
		4.1_1080 )
			vopts="$vopts -profile:v high -level 4.1" 
			break;;
		4.2_1080 )
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

# ask audio tracks question
echo " "
echo "Which audio tracks to use?"
echo "note, mapping all english audio tracks also maps all english subtitles"
echo "and subtitle mode is forced to auto"
select opt in  "all_english" "first" "all" "first+commentary" ; do
	case $opt in
	all_english)
		amaps="-map 0:a:m:language:eng"
		map_all_english=true
		break;;
	first )
		amaps="-map 0:a:0"
		break;;
	all )
		amaps="-map 0:a"
		break;;
	first+commentary )
		amaps="-map 0:a:0 -map 0:a:1"
		audio_metadata="-metadata:s:a:1 Title=\"English\" -metadata:s:a:1 Title=\"Commentary\" -metadata:s:a language=eng"
		break;;
	*)
	echo "invalid option"
	esac
done

# ask audio codec question
echo " "
echo "Which audio codec to use?"
select opt in  "aac_stereo" "aac_stereo_downmix" "aac_5.1" "copy"; do
	case $opt in
	aac_stereo )
		aopts="-c:a aac -b:a 160k"
		break;;
	aac_stereo_downmix )
		aopts="-c:a aac -b:a 160k"
		aopts="$aopts -af \"pan=stereo|FL < 1.0*FL + 0.707*FC + 0.707*BL|FR < 1.0*FR + 0.707*FC + 0.707*BR\""
		test="testing $aopts"
		echo "$test"
		break;;
	aac_5.1 )
		aopts="-c:a aac -b:a 480k"
		break;;
	copy )
		aopts="-c:a copy"
		break;;
	*)
	echo "invalid option"
	esac
done

# ask subtitle question only if english audio maps haven't been set
# if it was set, english subtitles will be pulled automatically too
# along with an external srt if it exists
echo " "
echo "What to do with subtitles?"
select opt in "keep_first" "use_external_srt" "keep_all" "none"; do
	case $opt in
	keep_all )
		smaps="-map 0:s"
		break;;
	keep_first )
		smaps="-map 0:s:0"
		# force english language metadata since it is sometimes "unknown"
		sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
		break;;
	use_external_srt )
		force_external_sub=true;
		# force english language metadata since it is sometimes "unknown"
		sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
		smaps="-map 1:s"
		break;;
	none )
		break;;
	*)
	echo "invalid option"
	esac
done


# ask run options
echo " "
echo "preview ffmpeg command, do a 1 minute sample, 60 second sample, or run everything now?"
select opt in "preview" "run_now" "sample1" "sample60" "sample60_middle" "exit"; do
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
		lopts="-ss 00:02:00.0 -t 00:01:00.0"
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

################################################################################
# loop through all input files
################################################################################
for f in **/*.mkv **/*.MKV **/*.MP4 **/*.mp4 **/*.avi **/*.AVI
do
	# get new file name with extention stripped
	fname="${f%.*}"
	subdir=$(dirname "${f}")
	out="$outdir/$fname.mkv"

	# arguments that must be reset each time since they may change between files
	ins=" -i \"$f\""

	# skip if file is in the output directory or already complete
	if [[ $outdir == ${subdir%/*} ]]; then
		echo "file in outdir: $f"
		continue
	fi
	if [ -f "$out" ]; then
		echo "completed: $f"
		continue
	fi

	# if using external subtitles, add to inputs
	if $forced_external_subs; then
		ins="$ins -i \"$fname.srt\""
	fi

	#combine options into ffmpeg string
	maps="$vmaps $amaps $smaps"
	metadata="-metadata Title=\"\" $video_metadata $audio_metadata $sub_metadata"
	command="ffmpeg $ins $maps $vopts $lopts $filters $aopts $sopts $other $metadata \"$out\""

	# off we go!!
	if $preview ; then
		echo " "
		echo "preview:"
		echo " "
		echo "$command"
	else
		mkdir -p "$outdir/$subdir"
		echo " "
		echo "executing:"
		echo "$command"
		echo " "
		if eval "$command"; then
			echo "ffmpeg success running:"
			echo "$command"
			echo " "
		else
			echo " "
			echo "ffmpeg failure: $f"
			echo "while trying to execute:"
			echo "$command"
			echo " "
			exit
		fi
	fi

done


echo " "
echo "DONE"



