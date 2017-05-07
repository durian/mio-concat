# mio-concat
Concatenates MIO Dashcam files into daily video files.

Scans directory for FILE*LOG files, and parses the date from the first $GPRMC message.

## Options

* -c: Compact *original* video files to 720p first
* -d: Dry run, don't create video files
* -d: Specify date (default is today), format YYYY-MM-DD
* -g: Create GPX track from concatenated LOG files
* -h: Resize concatenated video to half size
* -o: Specify other output filename 
* -s: Speed up video by factor ARG
* -t: Specify end date of concatenated video
* -q: Resize the concatenated video to one third size
* -7: Resize the concatenated file to 720p
