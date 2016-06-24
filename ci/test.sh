#!/bin/bash

echo "Download und extract sourcemod"
wget -q "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
# wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

echo "Set plugins version"
for file in addons/sourcemod/scripting/include/ttt.inc
do
  sed -i "s/<ID>/$COUNT/g" $file > output.txt
  rm output.txt
done

echo "Compile ttt plugins"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo "Compile 3rd-party-plugins"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/CustomPlayerSkins.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/no_weapon_fix.sp
