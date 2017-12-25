#!/bin/bash

## ffmpeg batch script
## processes all files in a directory recursively

#IFS=$'\n'
shopt -s nullglob # prevent null files
shopt -s globstar # for recursive for loops

# start with map for video, add to it later
using_libx264=false;
using_libx265=false;
autosubs=false;
map_all_eng=false;
audio_metadata=""
indir=false
outdir=false
preview=false
onefile=false
twopass=false
parallel=false
profile=""
mode=""
lopts=""
sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"
video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
other_opts="-nostdin"
# other general options
# -n tells ffmpeg to skip files if completed, not necessary anymore since we
# check in the script before executing, but doesn't hurt to keep
# also silence the initial ffmpeg prints and turn stats back on
verbosity="-hide_banner -v fatal -stats"


# print helpful usage to screen
usage() {
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
echo "12) OCR DVD subs to SRT"
echo "13) OCR DVD subs to SRT in Parallel"
echo " "
echo "enter numerical selection"


read n
case $n in
	1) #Copy Video & Copy Audio1 (embed srt subtitle)"
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v copy"
		amaps="-map 0:a:0"
		aopts="-c:a copy"
		autosubs=true;
		mode="ffmpeg_preset"
		;;
	2) # Copy Video & Encode Audio1 as 5.1 EAC3
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v copy"
		amaps="-map 0:a:0"
		aopts="-c:a eac3 -b:a 640k"
		autosubs=true;
		mode="ffmpeg_preset"
		;;
	3) # 2-pass 10M x264 & Encode Audio1 as 5.1 EAC3 (BR medium preset)
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v libx264 -preset slow -b:v 10M"
		profile="-profile:v high -level 4.1"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="-c:a eac3 -b:a 640k"
		autosubs=true;
		mode="ffmpeg_preset"
		;;
	4) # 2-pass 7M  x264 & Encode Audio1 as 5.1 EAC3 (BR low preset)
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v libx264 -preset slow -b:v 7M"
		profile="-profile:v high -level 4.1"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="-c:a eac3 -b:a 640k"
		autosubs=true;
		mode="ffmpeg_preset"
		;;
	5) # 2-pass 2M  x264 deinterlace & Copy Audio1 (DVD medium)
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v libx264 -preset slow -b:v 2M"
		filters="-vf \"bwdif\""
		profile="-profile:v baseline -level 3.0"
		using_libx264=true;
		twopass="x264";
		amaps="-map 0:a:0"
		aopts="-c:a copy"
		autosubs=true;
		mode="ffmpeg_preset"
		;;
	6) # remux mp4 to mkv
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v copy"
		amaps="-map 0:a"
		aopts="-c:a copy"
		smaps="-map 0:s"
		sopts="-c:s srt"
		mode="ffmpeg_preset"
		;;
	7) # custom mkv
		container="mkv"
		format="matroska"
		sopts="-c:s copy"
		vmaps="-map 0:v:0"
		mode="ffmpeg_custom"
		;;
	8) # custom mp4
		container="mp4"
		format="mp4"
		sopts="-c:s mov_text"
		vmaps="-map 0:v:0"
		mode="ffmpeg_custom"
		;;

	# "MKVEXTRACT options"
	9)  # extract_first_sub
		mode="mkvextract"
		which_sub="first"
		;;
	10 ) # extract_second_sub
		mode="mkvextract"
		which_sub="second"
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

	*)
		echo "invalid option"
		exit;;
esac


# extra questions for custom ffmpeg profile
if [ $mode == "ffmpeg_custom" ]; then
	# ask video codec question
	echo " "
	echo "Which Video codec to use?"
	select opt in "x264_2pass_10M" "x264_2pass_7M" "x264_2pass_3M" "x264_2pass_1.5M" "x264_rf18" "x264_rf20"  "x265_2pass_30M_5.0" "x265_rf21" "copy"; do
		case $opt in
		copy )
			vcopy="true"
			vopts="-c:v copy"
			break;;
		x264_2pass_10M )
			vopts="-c:v libx264 -preset slow -b:v 10000k"
			profile="-profile:v high -level 4.1"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_7M )
			vopts="-c:v libx264 -preset slow -b:v 7000k"
			profile="-profile:v high -level 4.1"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_3M )
			vopts="-c:v libx264 -preset slow -b:v 3000k"
			profile="-profile:v baseline -level 3.1"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_2pass_1.5M )
			vopts="-c:v libx264 -preset slow -b:v 1500k"
			profile="-profile:v baseline -level 3.0"
			using_libx264=true;
			twopass="x264";
			break;;
		x264_rf18 )
			vopts="-c:v libx264 -preset slow -crf 18"
			profile="-profile:v high -level 4.1"
			using_libx264=true;
			break;;
		x264_rf20 )
			vopts="-c:v libx264 -preset slow -crf 20"
			profile="-profile:v high -level 4.1"
			using_libx264=true;
			break;;
		x265_2pass_30M_5.0 )
			vopts="-c:v libx265 -preset slow -b:v 30000k -x265-params profile=main10:level=5.0:high-tier=1"
			twopass="x265";
			break;;
		x265_rf21 )
			vopts="-c:v libx265 -preset slow -x265-params profile=main10:crf=21:high-tier=1"
			break;;
		*)
			echo "invalid option"
			esac
	done

	if [ "$vcopy" -ne "true" ]; then
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
	select opt in "eac3_5.1" "eac3_2.0" "ac3_5.1" "aac_2.0" "copy"; do
		case $opt in
		ac3_5.1 )
			aopts="-c:a ac3 -b:a 640k"
			break;;
		eac3_5.1 )
			aopts="-c:a eac3 -b:a 640k"
			break;;
		aac_stereo )
			aopts="-c:a aac -b:a 128k"
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
			autosubs=true;
			break;;
		keep_all )
			smaps="-map 0:s"
			break;;
		keep_first )
			smaps="-map 0:s:0"
			break;;
		keep_second )
			smaps="-map 0:s:1"
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
	select opt in "preview" "run_now" "run_verbose" "sample1" "sample60" "sample60_middle" "run_now_no_chapters"; do
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
		sample60 )
			lopts="-t 00:01:00.0"
			break;;
		sample60_middle )
			lopts="-ss 00:02:00.0 -t 00:01:00.0"
			break;;
		run_now_no_chapters )
			vmaps="$vmaps -map_chapters -1"
			break;;
		*)
			echo "invalid option"
			esac
	done

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




################################################################################
# function for processing one file
# first argument is the file name
################################################################################
process_one_file () {
	## common processing of filename
	ffull=$1
	if [ $onefile == false ]; then
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
		else
			outdirfull="$outdir$subdir"
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
		outdirfull="$outdir"echo "waiting for parallel jobs to finished"
		sem --wait
		out_no_ext="$outdir/$fname"
		# place in outdir with mkv extension
		outfull="$out_no_ext.$container"
	fi

	# #debugging stuff
	# echo "indir:"
	# echo "$indir"
	# echo "outdir:"
	# echo "$outdir"
	# echo "ffull:"
	# echo "$ffull"
	# echo "fpath:"
	# echo "$fpath"
	# echo "fname:"
	# echo "$fname"
	# echo "subdirtmp:"
	# echo "$subdirtmp"
	# echo "subdir:"
	# echo "$subdir"
	# echo "outdirfull:"
	# echo "$outdirfull"
	# echo "outfull:"
	# echo "$outfull"

################################################################################
# mkvextract stuff, ffmpeg stuff below
################################################################################
	if [ $mode == "vobsub2srt" ]; then
		command="vobsub2srt $vobsub_flags \"$fpath\""
		if [ $preview == true ]; then
			echo "would run:"
			echo "$command"
			echo " "
		else
			echo "starting $ffull"
			if eval "$command"; then
				echo "success!"
				echo " "
			else
				echo " "
				echo "vobsub2srt failure"
				echo " "
				exit
			fi
		fi


################################################################################
# mkvextract stuff, ffmpeg stuff below
################################################################################
	elif [ $mode == "mkvextract" ]; then

		command="mkvextract tracks \"$ffull\""

		# count number of each type of sub so we know if it's necessary
		# to number the output files
		numpgs=0
		numsrt=0
		numvob=0
		numother=0
		counter=0
		if [ $which_sub == "all" ]; then
			while read subline
			do
				if [[ $subline == *"SRT"* ]]; then
					numsrt=$((numsrt+1))
				elif  [[ $subline == *"PGS"* ]]; then
					numpgs=$((numpgs+1))
				elif  [[ $subline == *"VobSub"* ]]; then
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
			if [ $which_sub == "second" ]; then
				if [ $counter -eq 1 ]; then
					continue;
				fi
			fi

			# Grep the number of the subtitle track
			tracknumber=`echo $subline | egrep -o "[0-9]{1,2}" | head -1`
			# add track to the command
			if [[ $subline == *"SRT"* ]]; then
				if [[ $numsrt -lt 2 ]]; then
					command="$command $tracknumber:\"$out_no_ext.srt\""
				else
					command="$command $tracknumber:\"$out_no_ext.$tracknumber.srt\""
				fi
			elif  [[ $subline == *"PGS"* ]]; then
				if [[ $numpgs -lt 2 ]]; then
					command="$command $tracknumber:\"$out_no_ext.sup\""
				else
					command="$command $tracknumber:\"$out_no_ext.$tracknumber.sup\""
				fi
			elif  [[ $subline == *"VobSub"* ]]; then
				if [[ $numvob -lt 2 ]]; then
					command="$command $tracknumber:\"$out_no_ext\""
				else
					command="$command $tracknumber:\"$out_no_ext.$tracknumber\""
				fi
			else
				if [[ $numsrt -lt 2 ]]; then
					command="$command $tracknumber:\"$out_no_ext.subtitle\""
				else
					command="$command $tracknumber:\"$out_no_ext.$tracknumber.subtitle\""
				fi
			fi


			# if only getting the first sub we can stop here
			if [ $which_sub == "first" ]; then
				break;
			elif [ $which_sub == "second" ]; then
				if [ $counter -eq 2 ]; then
					break;
				fi
			fi

		done < <(mkvmerge -i "$ffull" | grep 'subtitles' ) # process substitution

		# finished constructing command by silencing mkvextract
		command="$command > /dev/null 2>&1"

		if [ $preview == true ]; then
			echo "available subs for $ffull"
			mkvmerge -i "$ffull" | grep 'subtitles'
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



################################################################################
# ffmpeg stuff, mkvextract above
################################################################################
	else
		# arguments that must be reset each time since they may change between files
		ins=" -i \"$ffull\""

		# skip if file is already complete
		if [ -f "$outfull" ]; then
			echo "already exists: $outfull"
			return
		fi

		# if using autosubs, check if externals exist
		if [ $autosubs == true ]; then
			if [ -f "$fpath.srt" ]; then
				ins="$ins -i \"$fpath.srt\""
				smaps="-map 1:s"
				sopts="-c:s srt"
			else
				smaps="-map 0:s:0"
				sopts="-c:s srt"
			fi
		fi

		#combine options into ffmpeg string
		maps="$vmaps $amaps $smaps"
		metadata="-metadata title=\"\" $video_metadata $audio_metadata $sub_metadata"

		# construct ffmpeg command depending on mode
		if [ $twopass == "x264" ]; then
			command1="nice -n 19 ffmpeg -y $verbosity $other_opts $ins $maps $vopts -pass 1 -passlogfile \"/tmp/$fname\" $profile $lopts $filters $aopts $sopts $metadata -f $format /dev/null"
			command2="nice -n 19 ffmpeg -n $verbosity $other_opts $ins $maps $vopts -pass 2 -passlogfile \"/tmp/$fname\" $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
		elif [ $twopass == "x265" ]; then
			command1="nice -n 19 ffmpeg -y $verbosity $other_opts $ins $maps $vopts:pass=1:stats=\"/tmp/$fname\" $profile $aopts -f $format /dev/null"
			command2="nice -n 19 ffmpeg -n $verbosity $other_opts $ins $maps $vopts:pass=2:stats=\"/tmp/$fname\" $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
		else
			command="nice -n 19 ffmpeg -n $verbosity $other_opts $ins $maps $vopts $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
		fi

		# off we go!!
		if $preview ; then
			echo " "
			echo "preview:"
			echo " "
			echo "would make directory:"
			echo "$outdirfull"
			if [ $twopass == false ]; then
				echo "command:"
				echo "$command"
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
			## single pass execution
			if [ $twopass == false ]; then
				if eval "$command"; then
					echo "success!"
					echo " "
				else
					echo " "
					echo "ffmpeg failure: $f"
					echo " "
					exit
				fi
			else
				echo "starting pass 1 of 2"
				if eval "$command1"; then
					echo "finished pass 1"
				else
					echo " "
					echo "ffmpeg failure: $f"
					echo " "
					exit
				fi
				echo "starting pass 2 of 2"
				if eval "$command2"; then
					echo "finished pass 2"
				else
					echo " "
					echo "ffmpeg failure: $f"
					echo " "
					exit
				fi
			fi
		fi
	fi
}

# export process_one_file function so it can be run
export -f process_one_file


################################################################################
# process one file or loop through all input files
################################################################################
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





echo " "
echo "DONE"



