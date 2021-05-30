#!/bin/bash
source $ALLSKY_HOME/config.sh
source $ALLSKY_HOME/scripts/filename.sh
source $ALLSKY_HOME/scripts/darkCapture.sh
source $ALLSKY_HOME/scripts/ftp-settings.sh

cd $ALLSKY_HOME

# If we are in darkframe mode, we only save to the dark file
DARK_MODE=$(jq -r '.darkframe' "$CAMERA_SETTINGS")

if [ $DARK_MODE = "1" ] ; then
        exit 0
fi

IMAGE_TO_USE="$FULL_FILENAME"

# Resize the image if required
if [[ $IMG_RESIZE == "true" ]]; then
        convert "$IMAGE_TO_USE" -resize "$IMG_WIDTH"x"$IMG_HEIGHT" $IMAGE_TO_USE
fi

# Crop the image around the center if required
if [[ $CROP_IMAGE == "true" ]]; then
        convert "$IMAGE_TO_USE" -gravity Center -crop "$CROP_WIDTH"x"$CROP_HEIGHT"+"$CROP_OFFSET_X"+"$CROP_OFFSET_Y" +repage "$IMAGE_TO_USE";
fi

cp $IMAGE_TO_USE "liveview-$FILENAME.$EXTENSION"


# If 24 hour saving is desired, save the current image in today's directory
if [ "$CAPTURE_24HR" = true ] ; then
	CURRENT=$(date +'%Y%m%d')

	mkdir -p images/$CURRENT
	mkdir -p images/$CURRENT/thumbnails

	# Save image in images/current directory
	cp $IMAGE_TO_USE "images/$CURRENT/$FILENAME-$(date +'%Y%m%d%H%M%S').$EXTENSION"

	# Create a thumbnail of the image for faster load in web GUI
    	if identify $IMAGE_TO_USE >/dev/null 2>&1; then
		convert "$IMAGE_TO_USE" -resize 100x75 "images/$CURRENT/thumbnails/$FILENAME-$(date +'%Y%m%d%H%M%S').$EXTENSION";
    	fi
fi

# If upload is true, create a smaller version of the image and upload it
if [ "$UPLOAD_IMG" = true ] ; then
	echo -e "Resizing"
	echo -e "Resizing $FULL_FILENAME \n" >> log.txt

	# Create a thumbnail for live view
	convert "$IMAGE_TO_USE" -resize 962x720 -gravity East -chop 2x0 "$FILENAME-resize.$EXTENSION";

	echo -e "Uploading\n"
	echo -e "Uploading $FILENAME-resize.$EXTENSION \n" >> log.txt
       if [[ $PROTOCOL == "S3" ]] ; then
                if [[ ! -z "$S3_ENDPOINT" ]]; then
                  endpoint="--endpoint-url $S3_ENDPOINT"
                fi
                $AWS_CLI_DIR/aws s3 $endpoint cp $FILENAME-resize.$EXTENSION s3://$S3_BUCKET$IMGDIR --acl $S3_ACL &
        elif [[ $PROTOCOL == "local" ]] ; then
		cp $FILENAME-resize.$EXTENSION $IMGDIR &
	else
                lftp "$PROTOCOL"://"$USER":"$PASSWORD"@"$HOST":"$IMGDIR" -e "set net:max-retries 1; set net:timeout 20; put $FILENAME-resize.$EXTENSION; bye" &
        fi
fi
