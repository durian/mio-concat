#!/bin/bash
#
DATEFR=$(date +"%Y-%m-%d")
DATETO=0
OUTBASE="__NONE__"
HALF=0
DRYRUN=0

while getopts "df:ho:t:" opt; do
  case $opt in
      d)
	  DRYRUN=1
	  ;;
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
	ffmpeg -f concat -safe 0 -i $TMPF -vf scale=iw/2:-2 ${OUTBASE}.MP4 -loglevel 8
    else
	ffmpeg -f concat -safe 0 -i $TMPF -c copy ${OUTBASE}.MP4 -loglevel 8
    fi
    
    # Concatenate the LOG files.
    cat $(cat $TMPL) > ${OUTBASE}.LOG

    # Make Mio manager put them on the right date
    # in the calendar.
    T=$(date -j -f '%Y-%m-%d' $DATEFR +'%Y%m%d')1200
    touch -t $T ${OUTBASE}.MP4
    touch -t $T ${OUTBASE}.LOG

    echo "Created ${OUTBASE}.MP4 and ${OUTBASE}.LOG"
fi

rm $TMPF
rm $TMPL



