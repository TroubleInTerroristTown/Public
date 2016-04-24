#!/bin/bash

COUNT="$(git rev-list --count HEAD)"
HASH="$(git log --pretty=format:%h -n 1)"
FILE=ttt-$2-$1-$COUNT-$HASH.zip
LATEST=ttt-latest-$2-$1.zip
HOST=$3
USER=$4
PASS=$5

# Download und extract sourcemod
wget -q "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
# wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

# Give compiler rights for compile
chmod +x addons/sourcemod/scripting/spcomp

# Compile plugins
for file in addons/sourcemod/scripting/ttt/*.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

# Remove plugins folder if exists
if [ -d "addons/sourcemod/plugins" ]; then
  rm -r addons/sourcemod/plugins
fi

# Create clean plugins folder
mkdir addons/sourcemod/plugins
mkdir addons/sourcemod/plugins/ttt

# Move all binary files to plugins folder
for file in ttt*.smx
do
  mv $file addons/sourcemod/plugins/ttt
done

# Move all binary files to plugins folder
for file in *.smx
do
  mv $file addons/sourcemod/plugins
done


# Remove api test plugin
rm addons/sourcemod/plugins/ttt_api_test.smx

# Remove build folder if exists
if [ -d "build" ]; then
  rm -r build
fi

# Create clean build folder
mkdir build

# Move addons, materials and sound folder
mv addons materials sound build/

# Remove sourcemod folders
rm -r build/addons/metamod
rm -r build/addons/sourcemod/bin
rm -r build/addons/sourcemod/configs/geoip
rm -r build/addons/sourcemod/configs/sql-init-scripts
rm build/addons/sourcemod/configs/*
rm -r build/addons/sourcemod/data
rm -r build/addons/sourcemod/extensions
rm -r build/addons/sourcemod/gamedata
rm -r build/addons/sourcemod/logs
rm -r build/addons/sourcemod/scripting
rm -r build/addons/sourcemod/translations
rm build/addons/sourcemod/*.txt

# Create clean plugins folder
mkdir build/addons/sourcemod/translations

# Download und unzip translations files
wget -q -O translations.zip http://translator.mitchdempsey.com/sourcemod_plugins/158/download/ttt.translations.zip
unzip -qo translations.zip -d build/

# Clean root folder
rm sourcemod.tar.gz
rm translations.zip

# Go to build folder
cd build

# Compress directories and files
zip -9rq $FILE addons materials sound

# Upload file
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/$2/ $FILE"

# Add latest build
mv $FILE $LATEST

# Upload latest build
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/ $LATEST"