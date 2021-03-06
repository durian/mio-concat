#!/bin/bash
#
# OSX+Linux version 2019-05-05
#
set -o nounset

function dt_conv() {
    if [ $OSX -eq 1 ]; then
	TS=$(date -j -f "%Y-%m-%d" $1 $2) #osx
    else
	TS=$(date --date=$1 $2) # UNIX?
    fi
    echo "$TS"
    return 0
}

DATEFR=$(date +"%Y-%m-%d")
DATETO="__NONE__"
OUTBASE="__NONE__"
DRYRUN=0  # skip creation of video file
GPX=0
GPSBABEL=$(which gpsbabel) || GPSBABEL="__NONE__"
SPEEDUP=-1
SIZE=0
COMPACT=0
DATELOOP=0

OSX=0
if [[ "$(uname)" == "Darwin" ]];then
    OSX=1
fi

while getopts "cdf:gho:s:t:q7L" opt; do
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
      L)
	  DATELOOP=1
	  ;;
  esac
done

# date loop, generate individual mioconc commands
if [ $DATELOOP -eq 1 ]; then
    #DATEFR="2017-10-01"
    #DATETO="2017-10-31"
    echo "# -L -f $DATEFR -t $DATETO"
    CURDATETS=$(dt_conv $DATEFR "+%s")
    ENDDATETS=$(dt_conv $DATETO "+%s")
    offset=86400
    while [ "$CURDATETS" -le "$ENDDATETS" ]
    do
	date=$(dt_conv "@${CURDATETS}" "+%Y-%m-%d")
	# check if we have filenames like CONC_20170810_AccuBiltemaJet.MP4
	OUTBASE=CONC_$(dt_conv $date "+%Y%m%d")
	if [ "`echo $OUTBASE*`" == "$OUTBASE*" ]; then
	    echo "bash mioconc.bash -g -c -f $date"
	else
	    echo "# exists `echo $OUTBASE*`"
	fi
	CURDATETS=$(($CURDATETS+$offset))
    done
    exit 0
fi

if [[ "$DATETO" == "__NONE__" ]]; then
    DATETO=$DATEFR 
fi

if [[ "$OUTBASE" == "__NONE__" ]]; then
    OUTBASE=CONC_$(dt_conv $DATEFR "+%Y%m%d")
    if [[ "$DATETO" != "$DATEFR" ]]; then
	OUTBASE=${OUTBASE}_$(dt_conv $DATETO "+%Y%m%d") #two dates in filename
    fi
fi

echo $DATEFR $DATETO $OUTBASE

if [ $OSX -eq 1 ]; then
    D0=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATEFR} 00:00:00" +"%s") #osx
else
    D0=$(date --date="${DATEFR} 00:00:00" +"%s")
fi
if [[ -z $D0 ]]; then
    exit 1
fi
if [ $OSX -eq 1 ]; then
    D1=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATETO} 23:59:59" +"%s") #osx
else
    D1=$(date --date="${DATETO} 23:59:59" +"%s")
fi
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
    if [ $OSX -eq 1 ]; then
	FSIZE=$(stat -f%z ${LF}) #osx
    else
	FSIZE=$(stat  --printf="%s" ${LF})
    fi
    if [[ "${FSIZE}" == "0" ]]; then
	echo "Skipping 0 byte file ${LF}"
	continue
    fi
    # $GPRMC,143356.000,A,5617.4795,N,01250.6955,E,0.00,0.00,270417,,,A*6C
    DT=$(grep GPRMC ${LF} | head -n1 | awk -F',' '{print "20" substr($10,5,2) "-" substr($10,3,2) "-" substr($10,1,2)}')
    DX=$(dt_conv $DT +"%s")
    if [ $DX -ge $D0 -a $DX -le $D1 ]; then
	FN=${LF%LOG}MP4
	if [ -s $FN -o $DRYRUN -ne 0 ] ; then
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
T=$(dt_conv $DATEFR +'%Y%m%d')1200
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

#find . -name 'E*LOG' -print | xargs -I % sh -c 'X=$(grep GPRMC % | tail -n1);Y=$(grep GPRMC % | head -n1);echo %, $Y' | awk -F, '{print $1, substr($11,5,4)substr($11,3,2)substr($11,1,2) "-" $3}' | sort -n -k2

# MONTHLY GPX TRACK
#Peters-iMac:vid3 pberck
#  bash mioconc.bash -g -c -f 2017-07-01 -t 2017-07-31 -d
#Found FILE0134.LOG, FILE0134.MP4 2017-07-28
#/usr/local/bin/gpsbabel -w -t -i nmea -f CONC_20170701_20170731.LOG -x discard,hdop=4 -x simplify,crosstrack,error=0.001k -x track,split=20m -o gpx -F CONC_20170701_20170731.GPX
#Created CONC_20170701_20170731.GPX
#  cp CONC_20170701_20170731.GPX /Volumes/Luna/Web/Oderland/berck.se/dash/2017/

# hand speed
# ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  CONC_20171221_BilprovLakareTastarp.MP4
#3746.917000
# bc
#3746.917000 / 60
#62
# ffmpeg -i CONC_20171221_BilprovLakareTastarp.MP4 -filter:v "setpts=(1/62)*PTS" -an S62.MP4 -loglevel 8
#
# time ffmpeg -i CONC_20171221_BilprovLakareTastarp.MP4 -filter:v "setpts=(1/24)*PTS" -an S62.MP4 -loglevel 8
#real	2m44.326s
#user	19m14.235s
#sys	0m9.823s
