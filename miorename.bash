#!/bin/bash
#
#
# Goes through the photo's, reads their timestamp, and tries to find the timestamp
# in the relevant log file. Tries to parse position and velocity from the
# log file, and draws it on the image. Renames the image.
#
for FILE in IMG????.jpg;
do
    PRE="${FILE%.jpg}"
    # Note that the following statements use the OSX (BSD) version of stat
    DT=`stat -f "%Sm" -t "%Y%m%d_%H%M%S" "${FILE}"` # full date_time stamp
    PDT=`stat -f "%Sm" -t "%Y/%m/%d %H:%M:%S" "${FILE}"` # pretty date to put on image
    LTM=`stat -f "%Sm" -t "%H%M%S" "${FILE}"` # local time
    DAT=`stat -f "%Sm" -t "%d%m%y" "${FILE}"` # date, without century, for GPRMC parsing
    YM=`stat -f "%Sm" -t "%Y%m" "${FILE}"` # year-month for directory
    TZ=`stat -f "%Sm" -t "%z" "${FILE}"` # time zone, like +0200
    OFF=${TZ:2:1} # offset in hours, third character from TZ (fix for half hour offsets)
    UTC=$(date -j -v -${OFF}H -f "%H%M%S" $LTM +%H%M%S) # UTC, which is in log files
    #echo "$DAT $LTM $TZ $OFF $UTC"
    # The renamed file
    JPG="MIO_${DT}.jpg"
    # The annotated renamed file
    JPG_ANNO="MIO_${DT}_A.jpg"
    echo $FILE $JPG
    # Renamed file does not exist, create it
    if [ ! -e "${JPG}" ]; then
	#echo convert "${FILE}" -resize 1280 -quality ${Q} "${JPG}"
	#convert "${FILE}" -resize 1280 -quality ${Q} "${JPG}"
	echo cp "${FILE}" "${JPG}"
	cp "${FILE}" "${JPG}"
	# Find LOG file. On my system, the files are organised per month in YYYYMM
	# directories. We only look in the relevant directory. Not efficient, but it
	# works.
	echo find ../${YM} -name 'FILE*LOG' -print0 \| xargs -0 grep "${UTC}.*${DAT}"
	X=$(find ../${YM} -name 'FILE*LOG' -print0 | xargs -0 grep "${UTC}.*${DAT}") # slow
	if [ ${#X} -gt 10 ];
	then
	    # Extract and convert lat/lon to decimal notation, speed is in knots
	    N=$(echo $X | awk -F',' '{printf "%.4f%s", substr($4,0,2)+(substr($4,3)/60),$5 }') #lat
	    E=$(echo $X | awk -F',' '{printf "%.4f%s", substr($6,0,3)+(substr($6,4)/60),$7 }') #lon
	    S=$(echo $X | awk -F',' '{printf "%.1f", $8*1.852 }') #speed
	    # The string to draw on the image
	    INFO=\""${N} ${E}   ${S} km/h"\"
	    echo $INFO
	    # Draw the text
	    echo convert -pointsize 20 -fill yellow -draw \'text 80,1040 ${INFO}\' ${JPG} ${JPG_ANNO}
	    convert -pointsize 20 -fill yellow -draw "text 80,1040 ${INFO}" ${JPG} ${JPG_ANNO}
	    # And draw the date/time
	    INFO=\""${PDT}"\"
	    mogrify -pointsize 20 -fill yellow -draw "text 80,1064 ${INFO}" ${JPG_ANNO}
	fi
    fi
done
