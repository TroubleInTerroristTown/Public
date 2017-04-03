#!/bin/bash

echo "Download und extract sourcemod"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

echo "Compile ttt plugins"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  echo -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo "Compile 3rd-party-plugins"
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/CustomPlayerSkins.sp
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/no_weapon_fix.sp
