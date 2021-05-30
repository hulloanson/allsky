#!/bin/bash
source $ALLSKY_HOME/config.sh
source $ALLSKY_HOME/scripts/filename.sh
source $ALLSKY_HOME/scripts/ftp-settings.sh

cd $ALLSKY_HOME/

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -en "* ${GREEN}Creating symlinks to generate timelapse${NC}\n"
id="$( date +%Y%m%d%H%M%S )"
mkdir -p $ALLSKY_HOME/images/$id/sequence/

# find images, make symlinks sequentially and start avconv to build mp4; upload mp4 and move directory
images="$( find "$ALLSKY_HOME/images" -type f -iname 'image-*.jpg' -mmin -15 -size +0 | grep -v thumbnails | sort )"
if [[ -z "$images" ]]; then
    echo "No image to generate timelapse"
    exit 
fi
echo -n $images |
gawk 'BEGIN{ RS=" "; a=1 }{ printf "ln -sv %s $ALLSKY_HOME/images/'$id'/sequence/%04d.'$EXTENSION'\n", $0, a++ }' |
bash

SCALE=""
TIMELAPSEWIDTH=${TIMELAPSEWIDTH:-0}

if [ "${TIMELAPSEWIDTH}" != 0 ]
  then
    SCALE="-filter:v scale=${TIMELAPSEWIDTH:0}:${TIMELAPSEHEIGHT:0}"
    echo "Using video scale ${TIMELAPSEWIDTH} * ${TIMELAPSEHEIGHT}"
fi

ffmpeg -y -f image2 \
	-r $FPS \
	-i images/$id/sequence/%04d.$EXTENSION \
	-vcodec libx264 \
	-b:v 2000k \
	-pix_fmt yuv420p \
	-movflags +faststart \
	$SCALE \
	images/$id/allsky-$id.mp4

if [ "$UPLOAD_VIDEO" = true ] ; then
        if [[ "$PROTOCOL" == "S3" ]] ; then
                if [[ ! -z "$S3_ENDPOINT" ]]; then
                  endpoint="--endpoint-url $S3_ENDPOINT"
                fi
                $AWS_CMD $endpoint --profile default s3 cp images/$id/allsky-$id.mp4 s3://$S3_BUCKET${MP4DIR}timelapse-current.mp4 --acl $S3_ACL
	elif [[ $PROTOCOL == "local" ]] ; then
                cp $FILENAME-resize.$EXTENSION /var/www/html/$MP4DIR &
        else
                lftp "$PROTOCOL"://"$USER":"$PASSWORD"@"$HOST":"$MP4DIR" -e "set net:max-retries 1; put images/$id/allsky-$id.mp4; bye" &
        fi
fi

echo -en "* ${GREEN}Deleting sequence${NC}\n"
rm -rf $ALLSKY_HOME/images/$id

echo -en "* ${GREEN}Timelapse was created${NC}\n"
