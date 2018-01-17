#!/bin/bash
set -ev

COUNT=$(git rev-list --count HEAD)
VERSION=2.3.$COUNT
HASH="$(git log --pretty=format:%h -n 1)"
FILE=ttt-$2-$1-$VERSION-$HASH-$6.zip
LATEST=ttt-latest-$2-$1.zip
HOST=$3
USER=$4
PASS=$5

echo -e "Go to build folder\n"
cd build

echo -e "Upload file\n"
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/$2/ $FILE"

echo -e "Add latest build\n"
mv $FILE $LATEST

echo -e "Upload latest build"
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/ $LATEST"
