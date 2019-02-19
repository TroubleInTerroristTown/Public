#!/bin/bash
set -ev

COUNT=$(git rev-list --count HEAD)
VERSION=3.$COUNT
HASH="$(git log --pretty=format:%h -n 1)"
FILE=ttt-$2-$1-$VERSION-$HASH-$6.zip
LATEST=ttt-latest-$2-$1.zip
HOST=$3
USER=$4
PASS=$5
URL=$7
KEY=$8
UPDATE="$URL?version=$VERSION&key=$KEY"

echo -e "Go to build folder"
cd build

# echo -e "(LFTP) Upload file"
# lftp -c "open -u $USER,$PASS $HOST; put -O downloads/$2/ $FILE"

echo -e "(CURL) Upload file"
curl -T $FILE -u $USER:$PASS ftp://$HOST/downloads/$2/

echo -e "Add latest build"
mv $FILE $LATEST

# echo -e "(LFTP) Upload latest build"
# lftp -c "open -u $USER,$PASS $HOST; put -O downloads/ $LATEST"

echo -e "(CURL) Upload latest build"
curl -T $LATEST -u $USER:$PASS ftp://$HOST/downloads/

echo -e "Update TTT Version"
wget -q $UPDATE -O version.log
rm version.log
