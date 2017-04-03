#!/bin/bash

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
HASH="$(git log --pretty=format:%h -n 1)"
FILE=ttt-$2-$1-$COUNT-$HASH.zip
LATEST=ttt-latest-$2-$1.zip
HOST=$3
USER=$4
PASS=$5

echo -e "Download und extract sourcemod\n"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo -e "Give compiler rights for compile\n"
chmod +x addons/sourcemod/scripting/spcomp

echo -e "Set plugins version\n"
for file in addons/sourcemod/scripting/include/ttt.inc
do
  sed -i "s/<ID>/$COUNT/g" $file > output.txt
  rm output.txt
done

echo -e "Compile ttt plugins"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  echo -e -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo -e "Compile 3rd-party-plugins\n"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/CustomPlayerSkins.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/no_weapon_fix.sp

echo -e "Remove plugins folder if exists\n"
if [ -d "addons/sourcemod/plugins" ]; then
  rm -r addons/sourcemod/plugins
fi

echo -e "Create clean plugins folder\n"
mkdir addons/sourcemod/plugins
mkdir addons/sourcemod/plugins/ttt

echo -e "Move all ttt binary files to plugins folder\n"
for file in ttt*.smx
do
  mv $file addons/sourcemod/plugins/ttt
done

echo -e "Move all other binary files to plugins folder\n"
for file in *.smx
do
  mv $file addons/sourcemod/plugins
done

echo -e "Remove api test plugin\n"
rm addons/sourcemod/plugins/ttt/ttt_api_test.smx

echo -e "Remove build folder if exists\n"
if [ -d "build" ]; then
  rm -r build
fi

echo -e "Create clean build folder\n"
mkdir build

echo -e "Move addons, materials and sound folder\n"
mv addons materials sound build/

echo -e "Remove sourcemod folders\n"
rm -r build/addons/metamod
rm -r build/addons/sourcemod/bin
rm -r build/addons/sourcemod/configs/geoip
rm -r build/addons/sourcemod/configs/sql-init-scripts
rm build/addons/sourcemod/configs/* 2> /dev/null
rm -r build/addons/sourcemod/data
rm -r build/addons/sourcemod/extensions
rm -r build/addons/sourcemod/gamedata
rm -r build/addons/sourcemod/scripting
rm -r build/addons/sourcemod/translations
rm build/addons/sourcemod/*.txt

echo -e "Add LICENSE to build package\n"
cp LICENSE CVARS.txt build/

echo -e "Create clean plugins folder\n"
mkdir build/addons/sourcemod/translations

echo -e "Download und unzip translations files\n"
wget -q -O translations.zip http://translator.mitchdempsey.com/sourcemod_plugins/158/download/ttt.translations.zip
unzip -qo translations.zip -d build/

echo -e "Clean root folder\n"
rm sourcemod.tar.gz
rm translations.zip

echo -e "Go to build folder\n"
cd build

echo -e "Compress directories and files\n"
zip -9rq $FILE addons materials sound LICENSE CVARS.txt

echo -e "Upload file\n"
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/$2/ $FILE"

echo -e "Add latest build\n"
mv $FILE $LATEST

echo -e "Upload latest build"
lftp -c "open -u $USER,$PASS $HOST; put -O downloads/ $LATEST"
