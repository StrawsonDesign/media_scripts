# media scripts
bash script for batch media processing.
This is purely for personal use

media_scripts.sh recursively finds video files in the input directory provided or will act on a single file. It asks the user a series of questions to determine which presets to use. The output files are placed in the output directory provided. eg:


./media_scripts.sh ~/videos/movies ~/finished

./media_scripts.sh ~/videos/movies/movie.mkv ~/finished


Install the script to /usr/local/bin with the install script. Then media_scripts can be run from anywhere


sudo ./install.sh

media_scripts ~/videos/movies ~/finished

