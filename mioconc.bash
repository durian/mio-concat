#!/bin/bash
#
set -o nounset

DATEFR=$(date +"%Y-%m-%d")
DATETO="__NONE__"
OUTBASE="__NONE__"
DRYRUN=0  # skip creation of video file
GPX=0
GPSBABEL=$(which gpsbabel) || GPSBABEL="__NONE__"
SPEEDUP=-1
SIZE=0
COMPACT=0

while getopts "cdf:gho:s:t:q7" opt; do
  case $opt in
      c)
	  COMPACT=1
	  ;;
      d)
	  DRYRUN=1
	  ;;
      f)
	  DATEFR=$OPTARG
	  ;;
      g)
	  GPX=1
	  ;;
      h)
	  SIZE=1
	  ;;
      o)
	  OUTBASE=$OPTARG
	  ;;
      s)
	  SPEEDUP=$OPTARG
	  ;;
      t)
	  DATETO=$OPTARG
	  ;;
      q)
	  SIZE=2
	  ;;
      7)
	  SIZE=3
	  ;;
  esac
done

if [[ "$DATETO" == "__NONE__" ]]; then
    DATETO=$DATEFR 
fi

if [[ "$OUTBASE" == "__NONE__" ]]; then
    OUTBASE=CONC_$(date -j -f "%Y-%m-%d" $DATEFR "+%Y%m%d")
    if [[ "$DATETO" != "$DATEFR" ]]; then
	OUTBASE=${OUTBASE}_$(date -j -f "%Y-%m-%d" $DATETO "+%Y%m%d")
    fi
fi

echo $DATEFR $DATETO $OUTBASE

D0=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATEFR} 00:00:00" +"%s")
if [[ -z $D0 ]]; then
    exit 1
fi
D1=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATETO} 23:59:59" +"%s")
if [[ -z $D1 ]]; then
    exit 1
fi

if [ $D0 -ge $D1 ]; then
    echo "Date error"
    exit 1
fi

TMPF=$(mktemp concatf.XXXXXX)
TMPL=$(mktemp concatl.XXXXXX)

for LF in FILE*.LOG; do
    # $GPRMC,143356.000,A,5617.4795,N,01250.6955,E,0.00,0.00,270417,,,A*6C
    DT=$(grep GPRMC ${LF} | head -n1 | awk -F',' '{print "20" substr($10,5,2) "-" substr($10,3,2) "-" substr($10,1,2)}')
    DX=$(date -j -f "%F" $DT +"%s")
    if [ $DX -ge $D0 -a $DX -le $D1 ]; then
	FN=${LF%LOG}MP4
	if [[ -s $FN ]]; then
	    echo "Found ${LF}, $FN $DT"
	    # Compact first?
	    if [ $DRYRUN -eq 0 ]; then
		if [ $COMPACT -eq 1 ]; then # compact first?
		    eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=height,width $FN)
		    VS=${streams_stream_0_width}x${streams_stream_0_height}
		    if [[ "$VS" == "1920x1080" ]]; then
			echo ffmpeg -i $FN -vf scale=-1:720 ${FN}.7.MP4 -loglevel 16
			ffmpeg -i $FN -vf scale=-1:720 ${FN}.7.MP4 -loglevel 16
			echo mv ${FN}.7.MP4 $FN
			mv ${FN}.7.MP4 $FN
		    else
			echo "Size is $VS, not resizing"
		    fi
		fi
	    fi
	    # Input file for ffmpeg
	    echo "file '$FN'" >> $TMPF
	    echo "${LF}" >> $TMPL
	fi
    fi
done

if [[ ! -s $TMPF ]]; then
    echo "No files to concatenate."
    # Remove temporary files
    rm $TMPF
    rm $TMPL
    exit 1
fi

# Make Mio manager put them on the right date
# in the calendar.
T=$(date -j -f '%Y-%m-%d' $DATEFR +'%Y%m%d')1200

if [ $DRYRUN -eq 0 ]; then
    if [ $SIZE -eq 1 ]; then # half
	OUTBASEF=${OUTBASE}.H
	echo ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASEF}.MP4 
	ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASEF}.MP4 -loglevel 16
    elif [ $SIZE -eq 2 ]; then
	OUTBASEF=${OUTBASE}.Q # third (quarter)
	echo ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/3:-2 ${OUTBASEF}.MP4 
	ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/3:-2 ${OUTBASEF}.MP4 -loglevel 16
    elif [ $SIZE -eq 3 ]; then
	OUTBASEF=${OUTBASE}.7 # 720p
	echo ffmpeg -f concat -safe 0 -i $TMPF -vf scale=-1:720 ${OUTBASEF}.MP4 
	ffmpeg -f concat -safe 0 -i $TMPF -vf scale=-1:720 ${OUTBASEF}.MP4 -loglevel 16
    else
	OUTBASEF=${OUTBASE}
	echo ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASEF}.MP4 
	X=$(ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASEF}.MP4 -loglevel 16)
	echo "X=$X"
    fi
    touch -t $T ${OUTBASEF}.MP4
    echo "Created ${OUTBASEF}.MP4"

    # Hyperlapse, can be done on the output from above
    if [ ${SPEEDUP} -eq 0 ]; then #Calculate speedup needed to make it one minute
	SECS=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ${OUTBASEF}.MP4)
	#  60.394000
	echo "Video length $SECS seconds."
	SPEEDUP=$(awk -v SECS=$SECS 'BEGIN { print (SECS / 60.0) }')
	SPEEDUP=${SPEEDUP%.*} #remove floating part
	echo "Calculated speedup is $SPEEDUP"
    fi
    if [ ${SPEEDUP} -gt 0 ]; then
	echo ffmpeg -i ${OUTBASEF}.MP4 -filter:v "setpts=(1/${SPEEDUP})*PTS" -an ${OUTBASEF}.S${SPEEDUP}.MP4
	ffmpeg -i ${OUTBASEF}.MP4 -filter:v "setpts=(1/${SPEEDUP})*PTS" -an ${OUTBASEF}.S${SPEEDUP}.MP4 -loglevel 8
	echo "Created ${OUTBASEF}.S${SPEEDUP}.MP4"
	touch -t $T ${OUTBASEF}.S${SPEEDUP}.MP4
    fi
fi

# Concatenate the LOG files.
cat $(cat $TMPL) > ${OUTBASE}.LOG
echo "Created ${OUTBASE}.LOG"
touch -t $T ${OUTBASE}.LOG

# Remove temporary files
rm $TMPF
rm $TMPL

# Create GPX file
if [ $GPX -eq 1 ]; then
    if [[ "$GPSBABEL" == "__NONE__" ]]; then
	echo "No gpsbabel found"
    else
	SIMPL="-x discard,hdop=4 -x simplify,crosstrack,error=0.001k -x track,split=20m"
	# -x position,distance=4m
	# -x track,pack,sdistance=0.1k,split=10m
	echo $GPSBABEL -w -t -i nmea -f ${OUTBASE}.LOG $SIMPL -o gpx -F ${OUTBASE}.GPX
	X=$($GPSBABEL -w -t -i nmea -f ${OUTBASE}.LOG $SIMPL -o gpx -F ${OUTBASE}.GPX 2>&1 >/dev/null)
	echo "Created ${OUTBASE}.GPX"
    fi
fi
	

#for i in 2017-04-{01..30}; do bash mioconc.bash -d -g -f $i;done
#cp *GPX /Volumes/Luna/Web/Oderland/berck.se/dash/2017/
#ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 FILE0028.S4.MP4
#  60.394000

#find . -name '*LOG' -print | xargs -I % sh -c 'X=$(grep GPRMC % | tail -n1);echo %, $X' | awk -F, '{print $1, $3}' | sort -n -k2

#find . -name 'FI*LOG' -print | xargs -I % sh -c 'X=$(grep GPRMC % | tail -n1);echo %, $X' | awk -F, '{print $1, substr($11,5,4)substr($11,3,2)substr($11,1,2) "-" $3}' | sort -n -k2
