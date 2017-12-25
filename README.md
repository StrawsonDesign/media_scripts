# media scripts
bash script for batch media processing.
This is purely for personal use

media_scripts.sh recursively finds video files in the input directory provided or will act on a single file. It asks the user a series of questions to determine which presets to use. The output files are placed in the output directory provided. eg:


./media_scripts.sh ~/videos/movies ~/finished

./media_scripts.sh ~/videos/movies/movie.mkv ~/finished


Install the script to /usr/local/bin with the install script. Then media_scripts can be run from anywhere

presets for encoding videos and audio only need ffmpeg installed.
Extracting subtitles requires mkvextract. 

converting dvd vobsubs to srt subs requires the vobsub2srt deb package to be installed
along with the following dependencies:


sudo apt-get install libtiff5-dev libtesseract-dev tesseract-ocr-eng build-essential cmake pkg-config
sudo dpkg -i vobsub2srt-1.0pre7-11-g0ba6e25-Linux.deb


Thanks so much to ruediger for making the vobsub2srt tool. The deb here is compiled from his source here
https://github.com/ruediger/VobSub2SRT

