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
	outdir="./completed"
else
	outdir="$1"
fi

# ask questions
echo " "
echo "Which Video codec to use?"
select opt in "copy" "h264" "h265_8bit" "h265_10bit" "exit"; do
	case $opt in
	copy )
		vopts="-c:v copy"
		break;;
	h264 )
		vopts="-c:v libx264 -preset veryslow -crf 18"
		break;;
	h265_8bit )
		vopts="-c:v libx265 -preset slow -crf 21 -x265-params profile=main"
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

echo " "
echo "use filters?"
select opt in "none" "deinterlace_w3fdif" "deinterlace_bwdif" "exit"; do
	case $opt in
	none )
		iopts=""
		break;;
	deinterlace_w3fdif )
		filters="-vf w3fdif"
		break;;
	deinterlace_bwdif )
		filters="-vf bwdif"
		break;;
	exit )
		exit;;
	*)
		echo "invalid option"
		esac
done

echo " "
echo "Which audio codec to use?"
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

echo " "
echo "preview ffmpeg command, do a 1 minute sample, or run everything now?"
select opt in "preview" "sample" "run_now" "exit"; do
	case $opt in
	preview ) 
		lengthopt=""
		preview="yes"
		break;;
	sample )
		lengthopt="-t 00:01:00.0"
		preview="no"
		break;;
	run_now ) 
		lengthopt=""
		preview="no"
		break;;
	exit )
		exit;;
	*)
		echo "invalid option"
		esac
done




## loop through all input files
for f in **/*.mkv **/*.MKV **/*.MP4 **/*.mp4 **/*.avi **/*.AVI
do
	# get new file name with extention stripped
	fname="${f%.*}"
	subdir=$(dirname "${f}")
	outfile="\"$outdir/$fname.mkv\""
	
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



