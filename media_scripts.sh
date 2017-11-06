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
profile=""
mode=""
sub_metadata="-metadata:s:s:0 Title=\"English\" -metadata:s:s:0 language=eng"

# other general options
# -n tells ffmpeg to skip files if completed, not necessary anymore since we
# check in the script before executing, but doesn't hurt to keep
# also silence the initial ffmpeg prints and turn stats back on
verbosity="-hide_banner -v fatal -stats"


#print helpful usage to screen
usage() { echo "Usage: media_scripts <in_dir> <out_dir>" 1>&2; exit 1; }

# check arguments
if [ "$#" -ne 2 ]; then
	echo "expected two arguments"
	usage
fi

# grab input and output directories
indir="$(readlink -f "$1")"
outdir="$(readlink -f "$2")"
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
echo "what do you want to make?"
echo "mkv and mp4 options enocde a video with ffmpeg"
echo "first_sub and all_subs will use mkvextract to extract subtitles in any format"
select opt in "mkv" "mp4" "first_sub" "second_sub" "all_subs" "remux_mp4_to_mkv"; do
	case $opt in
	mkv )
		container="mkv"
		format="matroska"
		sopts="-c:s copy"
		vmaps="-map 0:v:0"
		video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
		audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
		mode="ffmpeg"
		break;;
	mp4 )
		container="mp4"
		format="mp4"
		sopts="-c:s mov_text"
		vmaps="-map 0:v:0"
		video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
		audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
		mode="ffmpeg"
		break;;
	first_sub )
		mode="mkvextract"
		which_sub="first"
		break;;
	second_sub )
		mode="mkvextract"
		which_sub="second"
		break;;
	all_subs )
		mode="mkvextract"
		which_sub="all"
		break;;
	remux_mp4_to_mkv )
		container="mkv"
		format="matroska"
		vmaps="-map 0:v:0"
		vopts="-c:v copy"
		amaps="-map 0:a"
		aopts="-c:a copy"
		smaps="-map 0:s"
		sopts="-c:s srt"
		video_metadata="-metadata:s:v:0 Title=\"Track 1\" -metadata:s:v:0 language=eng"
		audio_metadata="-metadata:s:a:0 Title=\"Track 1\" -metadata:s:a:0 language=eng"
		mode="remux"
		break;;
	*)
		echo "invalid option"
		esac
done

if [ $mode == "ffmpeg" ]; then
	# ask video codec question
	echo " "
	echo "Which Video codec to use?"
	select opt in "x264_2pass_10M" "x264_2pass_7M" "x264_2pass_3M" "x264_rf18" "x264_rf20"  "x265_2pass_25M_main10" "x265_rf21" "copy"; do
		case $opt in
		copy )
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
		x265_2pass_25M_main10 )
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
	select opt in "ac3_5.1" "aac_5.1" "aac_stereo" "copy"; do
		case $opt in
		ac3_5.1 )
			aopts="-c:a ac3 -b:a 640k -ac 6"
			break;;
		aac_stereo )
			aopts="-c:a aac -b:a 128k"
			break;;
		aac_5.1 )
			aopts="-c:a aac -b:a 384k"
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
fi #end check for non-srt containers

if [ $mode == "ffmpeg" ]; then
	# ask run options
	echo " "
	echo "preview ffmpeg command, do a 1 minute sample, 60 second sample, or run everything now?"
	select opt in "preview" "run_now" "run_verbose" "sample1" "sample60" "sample60_middle" "run_now_no_chapters"; do
		case $opt in
		preview )
			lopts=""
			preview=true
			break;;
		run_now )
			lopts=""
			break;;
		run_verbose )
			lopts=""
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
			lopts=""
			vmaps="$vmaps -map_chapters -1"
			break;;
		*)
			echo "invalid option"
			esac
	done

else
	# ask run options when extracting just subtitles
	echo " "
	echo "preview command, or run now?"
	select opt in "preview" "run_now"; do
		case $opt in
		preview )
			lopts=""
			preview=true
			break;;
		run_now )
			lopts=""
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
process () {
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
		outdirfull="$outdir"
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
	if [ $mode == "mkvextract" ]; then

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
			else
				smaps="-map 0:s:0"
			fi
		fi

		#combine options into ffmpeg string
		maps="$vmaps $amaps $smaps"
		metadata="-metadata title=\"\" $video_metadata $audio_metadata $sub_metadata"
		if [ $twopass == "x264" ]; then
			command="echo \"pass 1 of 2\" && < /dev/null ffmpeg -y $verbosity $ins $maps $vopts -pass 1 -passlogfile /tmp/ffmpeg2pass $profile $lopts $filters $aopts $sopts $metadata -f $format /dev/null && echo \"pass 2 of 2\" && < /dev/null ffmpeg -n $verbosity $ins $maps $vopts -pass 2 -passlogfile /tmp/ffmpeg2pass $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
		elif [ $twopass == "x265" ]; then
			command="echo \"pass 1 of 2\" && < /dev/null ffmpeg -y $verbosity $ins $maps $vopts:pass=1 -passlogfile /tmp/ffmpeg2pass $profile $aopts -f $format /dev/null && echo \"pass 2 of 2\" && < /dev/null ffmpeg -n $verbosity $ins $maps $vopts:pass=2 -passlogfile /tmp/ffmpeg2pass $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
		else
			command="< /dev/null ffmpeg -n $verbosity $ins $maps $vopts $profile $lopts $filters $aopts $sopts $metadata \"$outfull\""
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
	fi
}



################################################################################
# process one file or loop through all input files
################################################################################
if [ $onefile == true ]; then
	echo "onefile mode"
	process "$indir"
else
	#set IFS to fix spaces in file names
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	FILES="$(find "$indir" -type f -iname \*.mkv -o -iname \*.mp4 -o -iname \*.avi | sort)"
	echo "files to be processed:"
	echo "$FILES"
	for ffull in $FILES
	do
		process "$ffull"
	done
	IFS=$SAVEIFS

	# while IFS= read -d $'\0' -r ffull ; do
	# 	#echo "starting: $ffull"
	# 	process "$ffull"
	# done < <(find $indir -iname \*.mp4 -print0)
	# while IFS= read -d $'\0' -r ffull ; do
	# 	#echo "starting: $ffull"
	# 	process "$ffull"
	# done < <(find $indir -iname \*.mkv -print0)
	# while IFS= read -d $'\0' -r ffull ; do
	# 	#echo "starting: $ffull"
	# 	process "$ffull"
	# done < <(find $indir -iname \*.avi -print0)


fi





echo " "
echo "DONE"



