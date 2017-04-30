#!/bin/bash
#
DATEFR=$(date +"%Y-%m-%d")
DATETO=0
OUTBASE=0
HALF=0

while getopts "f:ho:t:" opt; do
  case $opt in
      f)
	  DATEFR=$OPTARG
	  ;;
      h)
	  HALF=1
	  ;;
      o)
	  OUTBASE=$OPTARG
	  ;;
      t)
	  DATETO=$OPTARG
	  ;;
  esac
done

if [[ $DATETO -eq 0 ]]; then
    #DATETO=$(date -j -v+1d -f "%Y-%m-%d" $DATEFR "+%Y-%m-%d")
    # after we fixed epoch comparison
    DATETO=$DATEFR 
fi

if [[ $OUTBASE -eq 0 ]]; then
   OUTBASE=CONC_$(date -j -f "%Y-%m-%d" $DATEFR "+%Y%m%d")
fi

echo $DATEFR $DATETO $OUTBASE

TMPF=$(mktemp concatf.XXXXXX)
TMPL=$(mktemp concatl.XXXXXX)

D0=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATEFR} 00:00:00" +"%s")
D1=$(date -j -f "%Y-%m-%d %H:%M:%S" "${DATETO} 23:59:59" +"%s")

for l in FILE*.LOG; do
    DT=$(grep GPRMC $l | head -n1 | awk -F',' '{print "20" substr($10,5,2) "-" substr($10,3,2) "-" substr($10,1,2)}')
    DX=$(date -j -f "%F" $DT +"%s")
    if [ $DX -ge $D0 -a $DX -le $D1 ]; then
	#echo $D0 $D1 $DX
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

if [ $HALF -eq 1 ]; then
    ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASE}.MP4 -loglevel 8
else
    ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASE}.MP4 -loglevel 8
fi


cat $(cat $TMPL) > ${OUTBASE}.LOG

rm $TMPF
rm $TMPL

T=$(date -j -f '%Y-%m-%d' $DATEFR +'%Y%m%d')1200
touch -t $T ${OUTBASE}.MP4
touch -t $T ${OUTBASE}.LOG

echo "Created ${OUTBASE}.MP4 and ${OUTBASE}.LOG"

