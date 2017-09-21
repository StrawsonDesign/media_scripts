#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

#IFS=$'\n'
shopt -s nullglob # prevent null files
shopt -s globstar # for recursive for loops


# start with map for video, add to it later
using_libx264=false;
force_external_sub=false;
autosubs=false;
map_all_eng=false;
audio_metadata=""
subtitle_metadata=""
indir=false
outdir=false
preview=false
onefile=false
twopass=false
sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"

# other general options
# -n tells ffmpeg to skip files if completed, not necessary anymore since we 
# check in the script before executing, but doesn't hurt to keep
# also silence the initial ffmpeg prints and turn stats back on
other="-hide_banner -v fatal -stats"


#print helpful usage to screen
usage() { echo "Usage: ffmpeg_helper -i <in_dir> -o <out_dir>" 1>&2; exit 1; }

# parse arguments
while getopts ":i:o:" opt; do
	case "${opt}" in
	i)
		indir=$(realpath -L --relative-base . "${OPTARG}")
		;;
	o)
		outdir=$(realpath -L --relative-base . "${OPTARG}")
		;;
	*)
		usage
		;;
	esac
done

# check arguments were given
if [ $indir == false ]; then
	echo "missing input directory"
	usage
fi
if [ $outdir == false ]; then
	echo "missing output directory"
	usage
fi

echo "input directory:"
echo $indir
echo "output directory:"
echo $outdir

# ask container options
echo " "
echo "what output container?"
select opt in "mkv" "mp4" "srt"; do
	case $opt in
	mkv ) 
		container="mkv"
		sopts="-c:s copy"
		vmaps="-map 0:v:0"
		video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
		audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
		break;;
	mp4 )
		container="mp4"
		sopts="-c:s mov_text"
		vmaps="-map 0:v:0"
		video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
		audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
		break;;
	srt )
		container="srt"
		sopts="-c:s srt"
		smaps="-map 0:s:0"
		force_external_sub=false;
		break;;
	*)
		echo "invalid option"
		esac
done

if ! [ $container == "srt" ]; then
	# ask video codec question
	echo " "
	echo "Which Video codec to use?"
	select opt in "twopass_12M" "x264_rf19_10M" "x264_rf18_10M" "x264_rf18_slow" "x264_rf20_slow" "x264_rf20_fast" "x264_18_fast" "nvenc_h264" "h265_8bit" "h265_8bit_fast" "h265_10bit" "copy"; do
		case $opt in
		copy )
			vopts="-c:v copy"
			break;;
		twopass_12M )
			vopts="-c:v libx264 -preset slow -b:v 12288k"
			using_libx264=true;
			twopass=true;
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
		x264_rf19_10M )
			vopts="-c:v libx264 -preset slow -crf 19 -maxrate 10M -bufsize 20M"
			using_libx264=true;
			break;;
		x264_rf18_10M )
			vopts="-c:v libx264 -preset slow -crf 18 -maxrate 10M -bufsize 20M"
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
		select opt in "auto" "4.1_1080" "3.1_dvd"  "4.2_1080"; do
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
	#echo "note, mapping all english audio tracks also maps all english subtitles"
	#echo "and subtitle mode is forced to auto"
	select opt in  "first" "second" "all_english" "all" "first+commentary" ; do
		case $opt in
		all_english)
			amaps="-map 0:a:m:language:eng"
			map_all_english=true
			break;;
		first )
			amaps="-map 0:a:0"
			break;;
		second )
			amaps="-map 0:a:1"
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
	select opt in "aac_5.1" "aac_stereo" "aac_stereo_downmix" "copy"; do
		case $opt in
		aac_stereo )
			aopts="-c:a aac -b:a 192k"
			break;;
		aac_stereo_downmix )
			aopts="-c:a aac -b:a 192k"
			aopts="$aopts -af \"pan=stereo|FL < 1.0*FL + 0.707*FC + 0.707*BL|FR < 1.0*FR + 0.707*FC + 0.707*BR\""
			break;;
		aac_5.1 )
			aopts="-c:a aac -b:a 576k"
			break;;
		copy )
			aopts="-c:a copy"
			break;;
		*)
		echo "invalid option"
		esac
	done

	# ask subtitle question
	echo " "
	echo "What to do with subtitles?"
	echo "Auto will select external srt if available"
	echo "otherwise will grab first embedded sub"
	select opt in "auto" "use_external_srt" "keep_first" "keep_all" "none"; do
		case $opt in
		auto)
			autosubs=true;
			break;;
		keep_all )
			smaps="-map 0:s"
			break;;
		keep_first )
			smaps="-map 0:s:0"
			break;;
		use_external_srt )
			force_external_sub=true;
			smaps="-map 1:s"
			break;;
		none )
			break;;
		*)
		echo "invalid option"
		esac
	done
fi #end check for non-srt containers

# ask run options
echo " "
echo "preview ffmpeg command, do a 1 minute sample, 60 second sample, or run everything now?"
select opt in "preview" "run_now" "sample1" "sample60" "sample60_middle" "run_now_no_chapters"; do
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
	run_now_no_chapters ) 
		lopts=""
		vmaps="$vmaps -map_chapters -1"
		break;;
	*)
		echo "invalid option"
		esac
done

################################################################################
# loop through all input files
################################################################################
# see if one file instead of a directory was given
if [[ -f $indir ]]; then
	echo "acting on just one file"
	echo " "
	onefile=true
	FILES=$indir
else
	FILES="$(find "$indir" -type f -iname \*.mkv -o -iname \*.MKV -o -iname \*.mp4 -o -iname \*.MP4 -o -iname \*.AVI -o -iname \*.avi | sort)"
fi

#set IFS to fix spaces in file names
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

# big loop!
for ffull in $FILES
#for ffull in $indir/**/*.mkv **/*.MKV **/*.MP4 **/*.mp4 **/*.avi **/*.AVI
do
	if [ $onefile == false ]; then
		#ffull is complete path from root
		fpath="${ffull%.*}" # strip extension, still includes subdir!
		fname=$(basename "$fpath") # strip all path to get juts the name
		subdir="${fpath%$fname}" # to get subdir, start by stripping the name
		subdir="${subdir#$indir}" # then strip indir to get realtive path
		indirbase=$(basename "$indir") # final directory of indir to keep in output
		outdirfull="$outdir/$indirbase$subdir" # directory to make later
		outfull="$outdir/$indirbase$subdir$fname.$container" # place in outdir with mkv extension
	else
		fpath="${ffull%.*}" # strip extension, still includes subdir!
		fname=$(basename "$fpath") # strip all path to get juts the name
		outdirfull="$outdir" # directory to make later
		outfull="$outdir/$fname.$container" # place in outdir with mkv extension
	fi
	
	##debugging stuff
	#echo "paths:"
	#echo "$indir"
	#echo "$outdir"
	#echo "$ffull"
	#echo "$fpath"
	#echo "$fname"
	#echo "$subdir"
	#echo "$indirbase"
	#echo "$outdirfull"
	#echo "$outfull"
	
	# arguments that must be reset each time since they may change between files
	ins=" -i \"$ffull\""

	# skip if file is already complete
	if [ -f "$outfull" ]; then
		echo "completed: $ffull"
		echo "already exists: $outfull"
		continue
	fi

	# if using external subtitles, add to inputs
	if [ $force_external_sub == true ]; then
		ins="$ins -i \"$fpath.srt\""

	# if using autosubs, check if externals exist
	else if [ $autosubs == true ]; then
		if [ -f "$fpath.srt" ]; then
			ins="$ins -i \"$fpath.srt\""
			smaps="-map 1:s"
		else
			smaps="-map 0:s:0"
		fi
	fi

	#combine options into ffmpeg string
	maps="$vmaps $amaps $smaps"
	metadata="-metadata title=\"$fname\" $video_metadata $audio_metadata $sub_metadata"
	#metadata="$video_metadata $audio_metadata $sub_metadata"
	if [ $twopass == true ]; then
		command="ffmpeg -y $other $ins $maps $vopts -pass 1 $aopts -f $container /dev/null && ffmpeg -n $other $ins $maps $vopts -pass 2 $lopts $filters $aopts $sopts $metadata \"$outfull\""
	else
		command="ffmpeg -n $other $ins $maps $vopts $lopts $filters $aopts $sopts $metadata \"$outfull\""
	fi
	
	# off we go!!
	if $preview ; then
		echo " "
		echo "preview:"
		echo " "
		echo "would make directory:"
		echo "$outdirfull"
		echo "command:"
		echo "$command"
		
	else
		mkdir -p "$outdirfull" # make sure output directory exists
		echo " "
		echo "starting:"
		echo "in:  $ffull"
		echo "out: $outfull"
		echo " "
		if eval "$command"; then
			echo "success!"
			echo " "
		else
			echo " "
			echo "ffmpeg failure: $f"
			echo " "
			exit
		fi
	fi

done
# restore $IFS
IFS=$SAVEIFS

echo " "
echo "DONE"



