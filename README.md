# mio-concat
Concatenates MIO Dashcam files into daily video files.

Scans directory for FILE*LOG files, and parses the date from the first $GPRMC message.

## Options

* `-c      `: Compact *original* video files to 720p first
* `-d      `: Dry run, don't create video files
* `-d DATE `: Specify date (default is today), format YYYY-MM-DD
* `-g      `: Create GPX track from concatenated LOG files
* `-h      `: Resize concatenated video to half size
* `-o NAME `: Specify other output filename 
* `-s N    `: Speed up video by factor N
* `-t DATE `: Specify end date of concatenated video
* `-q      `: Resize the concatenated video to one third size
* `-7      `: Resize the concatenated file to 720p

## Examples

`bash mioconcat.sh`
Takes todays files and concatenates them into one video file.

`bash micoconcat-sh -f 2017-04-01 -g`
Concatenate the files from 2017-04-01, concatenate them, and also create a GPX track file.

`bash mioconcat.sh -f 2017-04-01 -t 2017-04-05`
Concatenate all files from the 1st of April to the 5th (inclusive).

`bash micoconcat-sh -c`
Take all todays files, resize them to 720p, then concatenate them. This resizes the original files!
