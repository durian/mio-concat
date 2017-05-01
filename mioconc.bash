#!/bin/bash
#
DATEFR=$(date +"%Y-%m-%d")
DATETO=0
OUTBASE="__NONE__"
HALF=0    # half the size of the video
DRYRUN=0  # skip creation of video file
GPX=0
GPSBABEL=$(which gpsbabel) || GPSBABEL="__NONE__"
SPEEDUP=0

while getopts "df:gho:s:t:" opt; do
  case $opt in
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
	  HALF=1
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
  esac
done

if [ $DATETO -eq 0 ]; then
    DATETO=$DATEFR 
fi

if [[ "$OUTBASE" == "__NONE__" ]]; then
   OUTBASE=CONC_$(date -j -f "%Y-%m-%d" $DATEFR "+%Y%m%d")
fi

echo $DATEFR $DATETO $OUTBASE

TMPF=$(mktemp concatf.XXXXXX)
TMPL=$(mktemp concatl.XXXXXX)

D0=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATEFR} 00:00:00" +"%s")
D1=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATETO} 23:59:59" +"%s")

for l in FILE*.LOG; do
    # $GPRMC,143356.000,A,5617.4795,N,01250.6955,E,0.00,0.00,270417,,,A*6C
    DT=$(grep GPRMC $l | head -n1 | awk -F',' '{print "20" substr($10,5,2) "-" substr($10,3,2) "-" substr($10,1,2)}')
    DX=$(date -j -f "%F" $DT +"%s")
    if [ $DX -ge $D0 -a $DX -le $D1 ]; then
	FN=${l%LOG}MP4
	if [[ -s $FN ]]; then
	    echo "Found $l, $FN $DT"
	    echo "file '$FN'" >> $TMPF
	    echo "$l" >> $TMPL
	fi
    fi
done

if [[ ! -s $TMPF ]]; then
    echo "No files to concatenate."
    exit 1
fi

if [ $DRYRUN -eq 0 ]; then
    if [ $HALF -eq 1 ]; then
	OUTBASEF=${OUTBASE}.H
	echo ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASEF}.MP4 
	ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASEF}.MP4 -loglevel 8
    else
	echo ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASEF}.MP4 
	ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASEF}.MP4 -loglevel 8
    fi
    echo "Created ${OUTBASE}.MP4"

    # Hyperlapse x50
    if [ $SPEEDUP -gt 0 ]; then
	echo ffmpeg -i ${OUTBASEF}.MP4 -filter:v "setpts=(1/$SPEEDUP)*PTS" -an ${OUTBASEF}.S$SPEEDUP.MP4
	ffmpeg -i ${OUTBASEF}.MP4 -filter:v "setpts=(1/$SPEEDUP)*PTS" -an ${OUTBASEF}.S$SPEEDUP.MP4 -loglevel 8
	echo "Created ${OUTBASEF}.S$SPEEDUP.MP4"
    fi
fi

# Concatenate the LOG files.
cat $(cat $TMPL) > ${OUTBASE}.LOG
echo "Created ${OUTBASE}.LOG"

if [ $GPX -eq 1 ]; then
    if [[ "$GPSBABEL" == "__NONE__" ]]; then
	echo "No gpsbabel found"
    else
	SIMPL="-x discard,hdop=4 -x simplify,crosstrack,error=0.001k"
	# -x position,distance=4m
	# -x track,pack,sdistance=0.1k,split=10m
	echo $GPSBABEL -w -t -i nmea -f ${OUTBASE}.LOG $SIMPL -o gpx -F ${OUTBASE}.GPX
	X=$($GPSBABEL -w -t -i nmea -f ${OUTBASE}.LOG $SIMPL -o gpx -F ${OUTBASE}.GPX 2>&1 >/dev/null)
	echo "Created ${OUTBASE}.GPX"
    fi
fi
	
# Make Mio manager put them on the right date
# in the calendar.
T=$(date -j -f '%Y-%m-%d' $DATEFR +'%Y%m%d')1200
touch -t $T ${OUTBASE}.MP4
touch -t $T ${OUTBASE}.LOG

# Remove temporary files
rm $TMPF
rm $TMPL
