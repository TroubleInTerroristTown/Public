#!/bin/bash

echo -e "Download und extract sourcemod\n"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo -e "Give compiler rights for compile\n"
chmod +x addons/sourcemod/scripting/spcomp

echo -e "Compile ttt plugins\n"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  echo -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo -e "Compile 3rd-party-plugins\n"
echo -e -e "\nCompiling addons/sourcemod/scripting/CustomPlayerSkins.sp..."
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/CustomPlayerSkins.sp
echo -e -e "\nCompiling addons/sourcemod/scripting/no_weapon_fix.sp..."
addons/sourcemod/scripting/spcomp -E -v0 addons/sourcemod/scripting/no_weapon_fix.sp
