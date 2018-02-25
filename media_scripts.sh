#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

shopt -s nullglob # prevent null files
shopt -s globstar # for recursive for loops

## escape characters to set console colors
GREEN='\033[0;32m'
NOCOLOUR='\033[0m' # No Color

## common presets
# 4k preset
vopts="-c:v libx265 -preset slow -b:v 30000k -x265-params profile=main10:level=5.0:high-tier=1"
twopass="x265";
#bluray video
br_vopts="-c:v libx264 -preset slow -b:v 10M"
br_vprofile="-profile:v high -level 4.0"
br_twopass="x264"
# dvd video
dvd_vopts="-c:v libx264 -preset slow -b:v 2M"
dvd_vprofile="-profile:v baseline -level 3.0"
dvd_twopass="x264"
# audio presets
surround_aopts="-filter:a loudnorm -c:a eac3 -b:a 640k -ar 48k"
stereo_aopts="-filter:a loudnorm -c:a eac3 -b:a 192k -ar 48k"
# common filter for deinterlacing
deinterlace_filter="-vf \"bwdif\""

## static flags
vmaps="-map 0:v:0"
verbosity="-hide_banner -v fatal -stats"
vobsub_flags="--lang en" # use english language for OCR
# assume subtitle language is english for now
sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
# erase stupid video metadata set by scene groups
video_metadata="-metadata:s:v:0 Title=\"Track 1\""
audio_metadata="-metadata:s:a:0 Title=\"Track 1\""
other_opts="-nostdin -max_muxing_queue_size 1000 -reserve_index_space 200k"
# place to dump original files once complete
old_files="$(readlink -f "old_files")"

## mode and program flow variables
mode=""
autosubs=false;
map_all_eng=false;
using_libx264=false;
using_libx265=false;
lopts="" # length of time to encode
parallel=false
onefile=false
preview=false

## ffmpeg flags, these are base values and are set up
## by user prompts or auto mode logic
vopts="-c:v copy"
vprofile=""
twopass=none
filters=""
aopts="-c:a copy"
amaps="-map 0:a:0"
smaps=""
container="mkv"
format="matroska"
autosubs=true


################################################################################
# function usage()
# print usage to screen
# TODO update this for recently added functions
################################################################################
usage () {
	echo "General Usage:"
	echo "media_scripts <in_dir> <out_dir>"
	echo "if out_dir is omitted then a directory called finished will be created"
	echo "when converting vobsubs to SRT the output files will always be in the same"
	echo "directory as the original files."
	echo " "
	echo "show this help message:"
	echo "media_scripts -h"
	echo "media_scripts --help"
	exit 0
}

################################################################################
# function main()
# top level function, serves to prompt user for what to do, then run a loop
# to process all files in indir
################################################################################
main () {
	# check arguments
	if [ "$1" == "-h" ]; then
		usage
		exit 0
	elif [ "$1" == "--help" ]; then
		usage
		exit 0
	elif [ "$#" -eq 2 ]; then
		outdir="$(readlink -f "$2")"
	else
		outdir="$(readlink -f "finished")"
	fi

	# grab input and output directories
	indir="$(readlink -f "$1")"

	echo ""
	# check arguments were given
	if [ -f "$indir" ]; then
		echo "acting on just one file"
		echo "$indir"
		onefile=true
	elif [ -d "$indir" ]; then
		echo "acting on input directory:"
		echo "$indir"
		onefile=false
	else
		echo "error, input is neither file nor directory"
		echo "$indir"
		exit 1
	fi

	echo "output directory:"
	echo $outdir


	# ask container options
	echo " "
	echo "what do you want to do?"
	echo " "
	echo "FFMPEG options, all auto-embed SRT subtitles if available:"
	echo "1) Copy Video & Copy Audio1 (embed srt subtitle)"
	echo "2) Copy Video & Encode Audio1 as 5.1 EAC3"
	echo "3) 2-pass 10M x264 & Encode Audio1 as 5.1 EAC3 (BR medium preset)"
	echo "4) 2-pass 7M  x264 & Encode Audio1 as 5.1 EAC3 (BR low preset)"
	echo "5) 2-pass 2M  x264 deinterlace & Copy Audio1 (DVD preset)"
	echo "6) remux mp4 to mkv"
	echo "7) custom mkv"
	echo "8) custom mp4"
	echo " "
	echo "MKVEXTRACT options"
	echo "9) extract first subtitle"
	echo "10) extract second subtitle"
	echo "11) extract all subtitles"
	echo " "
	echo "VOBSUB2SRT options"
	echo "12) OCR DVD idx/sub to SRT"
	echo "13) OCR DVD idx/sub to SRT in Parallel"
	echo " "
	echo "BDSUP2SUB options"
	echo "14) Convert BR sup to idx/sub"
	echo "15) Extract and OCR BluRay sup 1"
	echo "16) Extract and OCR BluRay sub 2"
	echo ""
	echo "17) FULL AUTO (experimental)"
	echo "enter numerical selection"


	read n
	case $n in
	1) #Copy Video & Copy Audio1 (embed srt subtitle)"
		vopts="-c:v copy"
		amaps="-map 0:a:0"
		aopts="-c:a copy"
		mode="ffmpeg_preset"
		;;
	2) # Copy Video & Encode Audio1 as 5.1 EAC3
		vopts="-c:v copy"
		amaps="-map 0:a:0"
		aopts="$surround_aopts"
		mode="ffmpeg_preset"
		;;
	3) # 2-pass 10M x264 & Encode Audio1 as 5.1 EAC3 (BR medium preset)
		vopts="$br_vopts"
		vprofile="$br_vprofile"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="$surround_aopts"
		mode="ffmpeg_preset"
		;;
	4) # 2-pass 7M  x264 & Encode Audio1 as 5.1 EAC3 (BR low preset)
		vopts="-c:v libx264 -preset slow -b:v 7M"
		vprofile="$br_vprofile"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="$surround_aopts"
		mode="ffmpeg_preset"
		;;
	5) # 2-pass 2M  x264 deinterlace & Copy Audio1 (DVD medium)
		vopts="$dvd_vopts"
		filters="-vf \"bwdif\""
		vprofile="$dvd_profile"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="-c:a copy"
		mode="ffmpeg_preset"
		;;
	6) # remux mp4 to mkv
		vopts="-c:v copy"
		amaps="-map 0:a"
		aopts="-c:a copy"
		autosubs=false
		smaps="-map 0:s"
		sopts="-c:s srt"
		mode="ffmpeg_preset"
		;;
	7) # custom mkv
		mode="ffmpeg_custom"
		;;
	8) # custom mp4
		container="mp4"
		format="mp4"
		sopts="-c:s mov_text"
		mode="ffmpeg_custom"
		;;

	# "MKVEXTRACT options"
	9)  # extract_first_sub
		mode="mkvextract"
		which_sub="1"
		;;
	10 ) # extract_second_sub
		mode="mkvextract"
		which_sub="2"
		;;
	11 ) # extract_all_subs
		mode="mkvextract"
		which_sub="all"
		;;

	# "VOBSUB2SRT options"
	12) # OCR DVD subs to SRT
		mode="vobsub2srt"
		;;
	13) # OCR DVD subs to SRT in parallel
		mode="vobsub2srt"
		parallel=true
		;;
	# "BDSUP2SUB options"
	14) # convert BR sup to idx/sub
		mode="bdsup2sub"
		;;
	15) # Extract and OCR BluRay sub 1
		mode="bd2srt1"
		;;
	16) # Extract and OCR BluRay sub 1
		mode="bd2srt2"
		;;
	17) # full auto
		mode="full_auto"
		;;

	*)
		echo "invalid option"
		exit;;
	esac


	# extra questions for custom ffmpeg profile
	if [ $mode == "ffmpeg_custom" ]; then
		# ask video codec question
		echo " "
		echo "Which Video codec to use?"
		select opt in "x264_2pass_10M" "x264_2pass_7M" "x264_2pass_2M" "x264_2pass_1M" "x264_rf18" "x264_rf20"  "x265_2pass_30M_5.0" "x265_rf21" "copy"; do
		case $opt in
		copy )
			vcopy="true"
			vopts="-c:v copy"
			break;;
		x264_2pass_10M )
			vopts="-c:v libx264 -preset slow -b:v 10000k"
			vprofile="$br_vprofile"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_7M )
			vopts="-c:v libx264 -preset slow -b:v 7000k"
			vprofile="$br_vprofile"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_2M )
			vopts="-c:v libx264 -preset slow -b:v 2000k"
			vprofile="$dvd_vprofile"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_1M )
			vopts="-c:v libx264 -preset slow -b:v 1000k"
			vprofile="$dvd_vprofile"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_rf18 )
			vopts="-c:v libx264 -preset slow -crf 18"
			vprofile="$br_vprofile"
			using_libx264=true;
			break;;
		x264_rf20 )
			vopts="-c:v libx264 -preset slow -crf 20"
			vprofile="$br_vprofile"
			using_libx264=true;
			break;;
		x265_2pass_30M_5.0 )
			vopts="-c:v libx265 -preset slow -b:v 30000k -x265-params profile=main10:level=5.0:high-tier=1"
			twopass="x265";
			break;;
		x265_rf21 )
			vopts="-c:v libx265 -preset slow -x265-params profile=main10:crf=21:high-tier=1"
			vprofile=""
			break;;
		*)
			echo "invalid option"
			esac
		done

		if [ "$vcopy" != "true" ]; then
			# ask delinterlacing filter question
			echo " "
			echo "use videofilter?"
			echo "bwdif is a better deinterlacing filter but only works on newer ffmpeg"
			echo "cropping takes off 2 pixels from top and bottom which removes"
			echo "some interlacing artifacts from old dvds"
			select opt in "none" "scale_to_1080" "scale_to_720" "w3fdif" "w3fdif_crop" "bwdif" "bwdif_crop" "hflip"; do
			case $opt in
			none )
				filters=""
				break;;
			scale_to_1080 )
				filters="-vf scale=1920:-1"
				break;;
			scale_to_720 )
				filters="-vf scale=1280:-1"
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
		fi

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
		select opt in "eac3_5.1" "eac3_2.0" "copy"; do
		case $opt in
		eac3_5.1 )
			aopts="$surround_aopts"
			break;;
		eac3_2.0 )
			aopts="$stereo_aopts"
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
		select opt in "auto" "keep_first" "keep_second" "keep_all" "none"; do
		case $opt in
		auto)
			autosubs=true
			break;;
		keep_all )
			smaps="-map 0:s"
			autosubs=false
			break;;
		keep_first )
			smaps="-map 0:s:0"
			autosubs=false
			break;;
		keep_second )
			smaps="-map 0:s:1"
			autosubs=false
			break;;
		none )
			smaps=""
			autosubs=false
			break;;
		*)
			echo "invalid option"
			esac
		done

		# ask run options
		echo " "
		echo "preview ffmpeg command, do a 1 minute sample, 60 second sample, or run everything now?"
		select opt in "preview" "run_now" "run_verbose" "sample1" "sample10" "sample_60" "sample60_middle" "run_now_no_chapters"; do
		case $opt in
		preview )
			preview=true
			break;;
		run_now )
			break;;
		run_verbose )
			verbosity="-stats"
			break;;
		sample1 )
			lopts="-t 00:00:01.0"
			break;;
		sample10 )
			lopts="-t 00:00:10.0"
			break;;
		sample60 )
			lopts="-t 00:01:00.0"
			break;;
		sample60_middle )
			lopts="-ss 00:10:00.0 -t 00:01:00.0"
			break;;
		run_now_no_chapters )
			vmaps="$vmaps -map_chapters -1"
			break;;
		*)
			echo "invalid option"
			esac
		done
	## /end if [ $ffmpeg_custom == true ]
	## for all other modes just ask if we want to run or not
	else
		# ask run options when extracting just subtitles
		echo " "
		echo "preview command, or run now?"
		select opt in "preview" "run_now" "run_verbose"; do
		case $opt in
		preview )
			preview=true
			break;;
		run_now )
			break;;
		run_verbose )
			verbosity="-stats"
			vobsub_flags="$vobsub_flags --verbose"
			break;;
		*)
			echo "invalid option"
			esac
		done
	fi


	## Finally do stuff!!!
	time_start_all=$(date +%s)
	## process one file or loop through all input files
	if [ $onefile == true ]; then
		echo "onefile mode"
		process_one_file "$indir"
	else
		#set IFS to fix spaces in file names
		SAVEIFS=$IFS
		#IFS=$(echo -en "\n\b")
		IFS=$(echo -en "\n\b")

		if [ $mode == "vobsub2srt" ]; then
			FILES="$(find "$indir" -type f -iname \*.idx | sort)"
		elif [ $mode == "bdsup2sub" ]; then
			FILES="$(find "$indir" -type f -iname \*.sup | sort)"
		else
			FILES="$(find "$indir" -type f -iname \*.mkv -o -iname \*.mp4 -o -iname \*.avi | sort)"
		fi

		echo "files to be processed:"
		echo "$FILES"

		if [ $parallel == true ]; then
			echo "starting parallel"
			find "$indir" -type f -iname \*.idx | cut -f 1 -d '.' | parallel vobsub2srt
		else
			while read ffull; do
				process_one_file "$ffull"
			done < <(echo "$FILES")
		fi
		IFS=$SAVEIFS
	fi

	time_end_all=$(date +%s)
	dt_all=$(($time_end_all-$time_start_all))
	echo ""
	print_exec_time "total execution time:" "$dt_all"
} # end main()

################################################################################
# print_exec_timeprint_eprint_e
# for printing how long it took to execute a segment, prints seconds and h/m/s
# first argument is the prefix string, second is the time in seconds
################################################################################
print_exec_time () {
	dt="$2"
	((h=$dt/3600))
	((m=($dt%3600)/60))
	((s=$dt%60))
	printf "%s %02d:%02d:%02d\n" "$1" $h $m $s
}

################################################################################
# runs ffmpeg with all settings from variables defined by parent functions
# called by process_one_file()
################################################################################
run_ffmpeg () {
	# skip if file is already complete
	if [ -f "$outfull" ]; then
		echo "WARNING already exists: $outfull"
		echo "erasing and starting again"
		rm -f "$outfull"
	fi

	local ins=" -i \"$ffull\""

	# if using autosubs, check if externals exist
	if [ $autosubs == true ]; then
		if [ -f "$fpath.srt" ]; then
			ins="$ins -i \"$fpath.srt\""
			local smaps="-map 1:s"
			local sopts="-c:s srt"
		else
			local smaps="-map 0:s:0"
			local sopts="-c:s srt"
		fi
	fi

	#combine options into ffmpeg string
	local maps="$vmaps $amaps $smaps"
	local metadata="-metadata title=\"\" $video_metadata $audio_metadata $sub_metadata"

	# construct ffmpeg command depending on mode
	if [ "$twopass" == "x264" ]; then
		local command1="nice -n 19 ffmpeg -y -an -sn $verbosity $ins $other_opts $vmaps $vopts $vprofile -pass 1 -passlogfile \"/tmp/$fname\" $lopts $filters -f $format /dev/null"
		local command2="nice -n 19 ffmpeg -n         $verbosity $ins $other_opts $maps  $vopts $vprofile -pass 2 -passlogfile \"/tmp/$fname\" $lopts $filters $aopts $sopts $metadata \"$outfull\""
	elif [ "$twopass" == "x265" ]; then
		local command1="nice -n 19 ffmpeg -y -an -sn $verbosity $ins $other_opts $vmaps $vopts:pass=1:stats=\"/tmp/$fname\" $lopts $filters -f $format /dev/null"
		local command2="nice -n 19 ffmpeg -n         $verbosity $ins $other_opts $maps  $vopts:pass=2:stats=\"/tmp/$fname\" $lopts $filters $aopts $sopts $metadata \"$outfull\""
	elif [ "$twopass" == "none" ]; then
		local command1="nice -n 19 ffmpeg -n $verbosity $ins $other_opts $maps $vopts $vprofile $lopts $filters $aopts $sopts $metadata \"$outfull\""
	else
		echo "ERROR, twopass variable should be none, x264, or x265"
		exit 1
	fi

	# off we go!!
	if [ "$preview" == true ]; then
		if [ "$twopass" == none ]; then
			echo "ffmpeg command:"
			echo "$command1"
		else
			echo "pass 1 command:"
			echo "$command1"
			echo "pass 2 command"
			echo "$command2"
		fi
	else
		mkdir -p "$outdirfull" # make sure output directory exists
		echo " "
		echo "starting:"
		echo "in:  $ffull"
		echo "out: $outfull"
		echo " "
		time_start_ffmpeg=$(date +%s)
		## single pass execution
		if [ "$twopass" == "none" ]; then
			if eval "$command1"; then
				echo "success!"
				echo " "
			else
				echo " "
				echo "ffmpeg failure"
				echo " "
				exit 1
			fi
		else
			echo "starting pass 1 of 2"
			if eval "$command1"; then
				echo "finished pass 1"
			else
				echo " "
				echo "ffmpeg failure"
				echo " "
				exit 1
			fi
			echo "starting pass 2 of 2"
			if eval "$command2"; then
				# finished, remove log file
				rm "/tmp/$fname"*
				echo "finished pass 2"
			else
				echo " "
				echo "ffmpeg failure"
				echo " "
				exit 1
			fi
		fi
		## cleanup by moving completed original files
		mkdir -p "$old_files_full" 2> /dev/null
		for f in "$fpath"*
		do
			echo "moving $f to $old_files_full"
			mv "$f" "$old_files" 2> /dev/null
		done

		time_end_ffmpeg=$(date +%s)
		dt_ffmpeg=$((time_end_ffmpeg-time_start_ffmpeg))
		print_exec_time "ffmpeg execution time:" "$dt_ffmpeg"
		echo "done with $fname"
		echo " "
	fi

} ## end run_ffmpeg()

################################################################################
# vobsub2srt for OCR converting dvd idx/sub vonsubs to srt
################################################################################
run_vobsub2srt () {
	command="vobsub2srt $vobsub_flags \"$fpath\""
	if [ $preview == true ]; then
		echo "would run:"
		echo "$command"
		echo " "
	else
		echo "running vobsub2srt"
		# skip if file is already complete
		if [ -f "$fpath.srt" ]; then
			echo "WARNING already exists: $fpath.srt"
			echo "erasing and starting again"
			rm -f "fpath.srt"
		fi
		if eval "$command"; then
			# cleanup
			rm -f "$fpath.idx"
			rm -f "$fpath.sub"
			echo " vobsub2srt success!"
			echo " "
		else
			echo " "
			echo "vobsub2srt failure"
			echo " "
			exit 1
		fi
	fi
}

################################################################################
# bdsup2sub converts bluray image subtitles (sup) to dvd subtitles idx/sub
################################################################################
run_bdsup2sub () {
	command="bdsup2sub \"$fpath.sup\" -o \"$fpath.idx\" > /dev/null"
	if [ $preview == true ]; then
		echo "would run:"
		echo "$command"
		echo " "
	else
		echo "running bdsup2sub"
		# skip if file is already complete
		if [ -f "$fpath.idx" ]; then
			echo "WARNING already exists: $fpath.idx"
			echo "erasing and starting again"
			rm -f "fpath.idx"
		fi
		if [ -f "$fpath.sub" ]; then
			echo "WARNING already exists: $fpath.sub"
			echo "erasing and starting again"
			rm -f "fpath.sub"
		fi
		if eval "$command"; then
			# done, remove old sup fie
			rm "$fpath.sup"
			echo "bdsup2sub success!"
			echo " "
		else
			echo " "
			echo "bdsup2sub failure"
			echo " "
			exit
		fi
	fi
}

################################################################################
# bd2srt extracts bluray sub and converts to srt
# first argument is which subtitle to extract
################################################################################
run_bd2srt() {
	run_mkvextract $1
	run_bdsup2sub
	run_vobsub2srt
}

################################################################################
# mkvextract for extracting subtitles
# first arguemnt is which to extract, "first" "second" or "all"
################################################################################
run_mkvextract () {
	echo "running mkvextract tracks: $1"

	case "$1" in
	1)
		which_sub="1"
		;;
	2)
		which_sub="2"
		;;
	all)
		which_sub=""
		;;
	*)
		echo "error: run_mkvextract needs first argument 1,2 or all"
		echo "received $1"
		exit 1
	esac


	command="mkvextract tracks \"$ffull\""

	# count number of each type of sub so we know if it's necessary
	# to number the output files
	local numpgs=0
	local numsrt=0
	local numvob=0
	local numother=0
	local counter=0
	if [ "$which_sub" == "all" ]; then
		while read subline
		do
			if [[ "$subline" == *"SRT"* ]]; then
				numsrt=$((numsrt+1))
			elif [[ "$subline" == *"PGS"* ]]; then
				numpgs=$((numpgs+1))
			elif [[ "$subline" == *"VobSub"* ]]; then
				numvob=$((numvob+1))
			else
				numother=$((numother+1))
			fi
		done < <(mkvmerge -i "$ffull" | grep 'subtitles' ) # process substitution
	fi

	# Find out which tracks contain the subtitles
	while read subline
	do
		counter=$((counter+1))
		# if extracting the second sub, skip the first
		if [ "$which_sub" == "2" ]; then
			if [ $counter -eq 1 ]; then
				continue;
			fi
		fi

		# Grep the number of the subtitle track
		tracknumber=`echo $subline | egrep -o "[0-9]{1,2}" | head -1`
		# add track to the command
		if [[ $subline == *"SRT"* ]]; then
			if [[ "$numsrt" -lt 2 ]]; then
				command="$command $tracknumber:\"$fpath.srt\""
			else
				command="$command $tracknumber:\"$fpath.$tracknumber.srt\""
			fi
		elif [[ "$subline" == *"PGS"* ]]; then
			if [[ "$numpgs" -lt 2 ]]; then
				command="$command $tracknumber:\"$fpath.sup\""
			else
				command="$command $tracknumber:\"$fpath.$tracknumber.sup\""
			fi
		elif [[ "$subline" == *"VobSub"* ]]; then
			if [[ "$numvob" -lt 2 ]]; then
				command="$command $tracknumber:\"$fpath\""
			else
				command="$command $tracknumber:\"$fpath.$tracknumber\""
			fi
		else
			if [[ "$numsrt" -lt 2 ]]; then
				command="$command $tracknumber:\"$fpath.subtitle\""
			else
				command="$command $tracknumber:\"$fpath.$tracknumber.subtitle\""
			fi
		fi


		# if only getting the first sub we can stop here
		if [ "$which_sub" == "1" ]; then
			break;
		elif [ "$which_sub" == "2" ]; then
			if [ "$counter" == "2" ]; then
				break;
			fi
		fi

	done < <(mkvmerge -i "$ffull" | grep 'subtitles' ) # process substitution

	# finished constructing command by silencing mkvextract
	command="$command > /dev/null 2>&1"

	if [ "$preview" == true ]; then
		echo "would run:"
		echo "$command"
		echo " "
	else
		echo "starting $ffull"
		mkdir -p "$outdirfull" # make sure output directory exists
		if eval "$command"; then
			echo "success!"
			echo " "
		else
			echo " "
			echo "mkvextract failure"
			echo " "
			exit
		fi
	fi
}

################################################################################
# run_full_auto
# reads file ffull set by parent function process_one_file and does what it
# sees fit to make it plex-friendly
################################################################################
run_full_auto () {
	## grab info
	#local probe_opts="-v error -of default=noprint_wrappers=1:nokey=1" # common options for ffprobe
	local orig_vcodec=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=codec_name`
	local orig_width=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=width`
	local orig_field_order=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries stream=field_order`
	local orig_vbr=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 -show_entries format=bit_rate`

	local orig_acodec1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 -show_entries stream=codec_name`
	local orig_acodec2=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams a:1 -show_entries stream=codec_name`
	local orig_alang1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 -show_entries stream_tags=language`
	local orig_alang2=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams a:1 -show_entries stream_tags=language`
	local orig_achan1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams a:0 -show_entries stream=channels`


	local orig_scodec1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:0 -show_entries stream=codec_name`
	local orig_scodec2=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:1 -show_entries stream=codec_name`
	local orig_slang1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:0 -show_entries stream_tags=language`
	local orig_slang2=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:1 -show_entries stream_tags=language`
	local orig_sforced1=`ffprobe -i "$ffull" -v error -of default=noprint_wrappers=1:nokey=1 -select_streams s:1 -show_entries disposition=forced`

	if [ "$orig_scodec1" == "" ]; then orig_scodec1="none"; fi
	if [ "$orig_acodec2" == "" ]; then orig_acodec2="none"; fi
	if [ "$orig_scodec2" == "" ]; then orig_scodec2="none"; fi


	#decide interlace mode
	if [ "$orig_field_order" == "tt" ] || [ "$orig_field_order" == "bb" ]; then
		interlaced=true;
	elif [ "$orig_field_order" == "progressive" ]; then
		interlaced=false;
	else
		echo "ERROR unknown field order: $orig_field_order"
		echo "cant determine interlace mode"
		exit 1
	fi

	## print info in preview mode
	if [ "$preview" == "true" ]; then
		echo "vcodec:  $orig_vcodec"
		echo "width:   $orig_width"
		echo "f order: $orig_field_order"
		echo "interlaced: $interlaced"
		echo "bitrate: $(("$orig_vbr"/1000000)) Mb/s"
		echo "acodec1: $orig_acodec1"
		echo "acodec2: $orig_acodec2"
		echo "alang1: $orig_alang1"
		echo "alang2: $orig_alang2"
		echo "achannels1: $orig_achan1"
		echo "scodec1: $orig_scodec1"
		echo "scodec2: $orig_scodec2"
		echo "slang1: $orig_slang1"
		echo "slang2: $orig_slang2"
		echo "sforced1: $orig_sforced1"
		echo ""
	fi


	# put all options back to starting point before configuring
	vopts="-c:v copy"
	vprofile=""
	twopass="none"
	filters=""
	aopts="-c:a copy"
	amaps="-map 0:a:0"
	auto_subs=true
	ocr_mode="none"
	which_ocr=""

	#################################################################
	## figure out what to do with video stream here
	## first throw errors for conditions we can't handle yet
	## then check if video can be copied
	## otherwise pick bitrate by resolution
	#################################################################

	## catch videos larger than 1920x1080
	## these videos should be dealt with manually for now
	if [ "$orig_width" -gt "1920" ]; then
		echo "ERROR with $fname"
		echo "Videos wider than 1920 not supported in Auto mode"
		exit 1
	fi

	## catch h265
	## these videos should be dealt with manually for now
	if [ "$orig_vcodec" == "h265" ]; then
		echo "ERROR with $fname"
		echo "x265 video not supported in auto mode"
		exit 1
	fi

	## copying video is ideal, but most restrictive conditions so check first
	if [ "$interlaced" == "false" ] && [ "$orig_vcodec" == "h264"   ] && \
	   [ "$orig_width" == "1920"  ] && [ "$orig_vbr" -le "14000000" ]; then
		vopts="-c:v copy"
		vprofile=""
		twopass="none"

	## everything in this else statement requires encoding
	else
		##  start by checking if we need an interlacing filter
		# don't need an else since "filters" is reset above for each video
		if [ "$interlaced" == "true" ]; then
			filters="$deinterlace_filter"
		fi

		# now set bitrate and profile by resolution for BR and DVD
		if [ "$orig_width" == "1920" ]; then
			vopts="$br_vopts"
			vprofile="$br_vprofile"
			twopass="x264"
		elif [ "$orig_width" == "720" ]; then
			vopts="$dvd_vopts"
			vprofile="$dvd_vprofile"
			twopass="x264"
		else
			echo "ERROR, don't know how to handle video width: $orig_width"
			exit 1
		fi
	fi

	## now to decide audio
	# if already aac, ac3, or eac3, just copy
	if [ "$orig_acodec1" == "eac3" ] || [ "$orig_acodec1" == "ac3" ]; then
		amaps="-map 0:a:0"
		aopts="-c:a copy"

	# if first codec is truehd, there is probably a compatability track to copy
	elif [ "$orig_acodec1" == "truehd" ]; then
		if [ "$orig_acodec2" == "eac3" ] || [ "$orig_acodec2" == "ac3" ]; then
			# yay, compatability track, copy that!
			amaps="-map 0:a:1"
			aopts="-c:a copy"
		else
			# no compatablity track, give in a transcode truehd
			amaps="-map 0:a:0"
			aopts="$surround_aopts"
		fi

	# if we got here the audio is probably DTS or AAC, in either case transcode
	# after selecting right language
	elif [ "$orig_alang1" == "eng" ] || [ "$orig_alang1" == "" ]; then
		amaps="-map 0:a:0"
		if [ "$orig_achan1" == "2" ] || [ "$orig_achan1" == "3" ]; then
			aopts="$stereo_aopts"
		else
			aopts="$surround_aopts"
		fi
	elif [ "$orig_alang2" == "eng" ]; then
		amaps="-map 0:a:1"
		aopts="$surround_aopts"
	else
		echo "ERROR can't find english audio track"
		exit 1
	fi

	# now decide subtitles
	# if srt already placed manually, use that
	if [ -f "$fpath.srt" ]; then
		ocr_mode="none"
	elif [ "$orig_scodec1" == "none" ]; then
		echo "ERROR, no subs found for $fname"
		exit 1
	elif [ "$orig_sforced1" == "1" ]; then
		echo "ERROR, detected forced subs, don't know how to handle this yet"
		exit 1
	else
		# english subs found in ch 1
		if [ "$orig_slang1" == "eng" ] || [ "$orig_slang1" == "" ]; then
			# if embedded subs are text formatted, use that
			if [ "$orig_scodec1" == "subrip" ] || [ "$orig_scodec1" == "ass" ]; then
				ocr_mode="none"
				auto_subs=false
				smaps="-map 0:s:0"
				sopts="-c:s srt"
			# if dvd subs, ocr those
			elif [ "$orig_scodec1" == "dvd_subtitle" ]; then
				ocr_mode="dvd"
				which_ocr="1"
			# if bluray subs, there is a chance of forced track, so check
			elif [ "$orig_scodec1" == "hdmv_pgs_subtitle" ]; then
				ocr_mode="bluray"
				which_ocr="1"
			else
				echo "unknown subtitle format: $orig_scodec1"
				exit 1
			fi

		elif [ "$orig_slang2" == "eng" ]; then
			# if embedded subs are text formatted, use that
			if [ "$orig_scodec2" == "subrip" ] || [ "$orig_scodec2" == "ass" ]; then
				ocr_mode="none"
				auto_subs=false
				smaps="-map 0:s:1"
				sopts="-c:s srt"
			# if dvd subs, ocr those
			elif [ "$orig_scodec2" == "dvd_subtitle" ]; then
				ocr_mode="dvd"
				which_ocr="2"
			# if bluray subs, there is a chance of forced track, so check
			elif [ "$orig_scodec2" == "hdmv_pgs_subtitle" ]; then
				ocr_mode="bluray"
				which_ocr="2"
			else
				echo "unknown subtitle format: $orig_scodec1"
				exit 1
			fi
		else
			echo "ERROR can't find english subs"
			exit 1
		fi

	fi

	## print info in preview mode
	if [ "$preview" == "true" ]; then
		echo "auto mode configured settings:"
		echo "vopts: $vopts"
		echo "vprofile: $vprofile"
		echo "twopass: $twopass"
		echo "filters: $filters"
		echo "aopts: $aopts"
		echo "amaps: $amaps"
		echo "smaps: $smaps"
		echo "ocr_mode: $ocr_mode"
		echo "which_ocr: $which_ocr"
		echo ""
	fi

	## now process video with auto configure settings!
	# start with OCR if needed, start by extracing the sub
	if [ "$ocr_mode" == "dvd" ]; then
		run_mkvextract "$which_ocr"
		run_vobsub2srt
	# for bluray subs need to convert to dvd idx format for ocr
	elif [ "$ocr_mode" == "bluray" ]; then
		run_mkvextract "$which_ocr"
		run_bdsup2sub
		run_vobsub2srt
	fi

	# now just run ffmpeg
	run_ffmpeg
}

################################################################################
# function for processing one file
# first argument is the file name
# mostly serves to deconstruct the path, name, and subdirectory of the file
# then call the appropriate processes
################################################################################
process_one_file () {
	## common processing of filename
	ffull="$1"
	if [ "$onefile" == false ]; then
		# ffull is complete path from root
		# strip extension, still includes subdir!
		fpath="${ffull%.*}"
		# strip all path to get just the name
		fnametmp=$(basename "$ffull") # strip directories
		fname="${fnametmp%.*}" #strip extension
		# to get subdir, start by stripping the name
		subdirtmp="$(dirname "$ffull")"
		# then strip indir to get realtive path
		subdir="${subdirtmp#"$indir"}"
		# final directory of indir to keep in output
		#indirbase=$(basename "$indir")
		# directory to make later
		if [ -z "$subdir" ]; then
			outdirfull="$outdir"
			old_files_full="$old_files"
		else
			outdirfull="$outdir$subdir"
			old_files_full="$old_files$subdir"

		fi
		# place in outdir with mkv extension
		out_no_ext="$outdirfull/$fname"
		outfull="$out_no_ext.$container"
	else
		# strip extension, still includes subdir
		fpath="${ffull%.*}"
		# strip all path to get just the name
		fnametmp=$(basename "$ffull")
		fname="${fnametmp%.*}"
		# directory to make later
		outdirfull="$outdir"
		out_no_ext="$outdir/$fname"
		# place in outdir with mkv extension
		outfull="$out_no_ext.$container"
		old_files_full="$old_files"
	fi

	# #debugging stuff
	# echo "indir: $indir"
	# echo "outdir: $outdir"
	# echo "ffull: $ffull"
	# echo "fpath: $fpath"
	# echo "fname: $fname"
	# echo "subdirtmp: $subdirtmp"
	# echo "subdir: $subdir"
	# echo "outdirfull: $outdirfull"
	# echo "outfull: $outfull"

	if [ "$preview" == true ]; then
		echo ""
		echo -e "${GREEN}preview: $fname${NOCOLOUR}"
	fi

	case $mode in
	full_auto )
		run_full_auto
		;;
	vobsub2srt )
		run_vobsub2srt
		;;
	bdsup2sub )
		run_bdsup2sub
		;;
	bd2srt1 )
		run_bd2srt 1
		;;
	bd2srt2 )
		run_bd2srt 2
		;;
	mkvextract )
		run_mkvextract "$which_sub"
		;;
	* )
		run_ffmpeg
	esac
} # end process_one_file()


## actually run main now
main "$@"



