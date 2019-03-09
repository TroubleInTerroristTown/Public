#!/bin/bash
set -ev

git fetch --unshallow
COUNT=$(git rev-list --count HEAD)
VERSION=3.$COUNT
HASH="$(git log --pretty=format:%h -n 1)"
FILE=ttt-$2-$1-$VERSION-$HASH-$6.zip

echo -e "Download und extract sourcemod"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz --exclude='addons/sourcemod/translations'

echo -e "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

echo -e "Set plugins version"
for file in addons/sourcemod/scripting/include/ttt_stock.inc
do
  sed -i "s/<VERSION>/$VERSION/g" $file > output.txt
  rm output.txt
done

echo -e "Compile ttt plugins"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  echo -e -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 $file
done

echo -e "\nCompile 3rd-party-plugins"
echo -e "\nCompiling addons/sourcemod/scripting/no_weapon_fix.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/no_weapon_fix.sp
echo -e "\nCompiling addons/sourcemod/scripting/block_messages.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/block_messages.sp
echo -e "\nCompiling addons/sourcemod/scripting/tripmines.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/tripmines.sp
echo -e "\nCompiling addons/sourcemod/scripting/turret_core.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/turret_core.sp

echo -e "Remove plugins folder if exists"
if [ -d "addons/sourcemod/plugins" ]; then
  rm -r addons/sourcemod/plugins
fi

echo -e "Create clean plugins folder"
mkdir addons/sourcemod/plugins
mkdir addons/sourcemod/plugins/disabled
mkdir addons/sourcemod/plugins/ttt

echo -e "Move all ttt binary files to plugins folder"
for file in ttt*.smx
do
  mv $file addons/sourcemod/plugins/ttt
done

echo -e "Move all other binary files to plugins folder"
for file in *.smx
do
  mv $file addons/sourcemod/plugins
done

echo -e "Move optional plugins into disabled folder"
mv addons/sourcemod/scripting/README.md addons/sourcemod/plugins/disabled
mv addons/sourcemod/plugins/ttt/ttt_dronescameras.smx addons/sourcemod/plugins/disabled
mv addons/sourcemod/plugins/ttt/ttt_futuristicgrenades.smx addons/sourcemod/plugins/disabled
mv addons/sourcemod/plugins/ttt/ttt_parachute.smx addons/sourcemod/plugins/disabled
mv addons/sourcemod/plugins/ttt/ttt_tactical_shield.smx addons/sourcemod/plugins/disabled

echo -e "Remove build folder if exists"
if [ -d "build" ]; then
  rm -r build
fi

echo -e "Create clean build folder"
mkdir build

echo -e "Move addons, materials, models and sound folder"
mv addons materials models sound build/

echo -e "Remove sourcemod folders"
rm -r build/addons/metamod
rm -r build/addons/sourcemod/bin
rm -r build/addons/sourcemod/configs/geoip
rm -r build/addons/sourcemod/configs/sql-init-scripts
rm -r build/addons/sourcemod/configs/*.txt
rm -r build/addons/sourcemod/configs/*.ini
rm -r build/addons/sourcemod/configs/*.cfg
rm -r build/addons/sourcemod/data
rm -r build/addons/sourcemod/extensions
rm -r build/addons/sourcemod/gamedata
rm -r build/addons/sourcemod/scripting
rm build/addons/sourcemod/*.txt

echo -e "Add LICENSE, CREDITS.md, CVARS.txt and adminmenu_custom.txt to build package"
cp LICENSE CREDITS.md CVARS.txt adminmenu_custom.txt build/

echo -e "Clean root folder"
rm sourcemod.tar.gz

echo -e "Go to build folder"
cd build

echo -e "Compress directories and files"
zip -9rq $FILE addons materials models sound CREDITS.md LICENSE CVARS.txt adminmenu_custom.txt
