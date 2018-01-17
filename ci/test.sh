#!/bin/bash
set -ev

echo -e "Download und extract sourcemod\n"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo -e "Give compiler rights for compile\n"
chmod +x addons/sourcemod/scripting/spcomp

echo -e "Compile ttt plugins\n"
for file in addons/sourcemod/scripting/ttt/*.sp
do
  echo -e "\nCompiling $file..." 
  addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 $file
done

echo -e "\nCompile 3rd-party-plugins"
echo -e "Compiling addons/sourcemod/scripting/CustomPlayerSkins.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/CustomPlayerSkins.sp
echo -e "\nCompiling addons/sourcemod/scripting/no_weapon_fix.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/no_weapon_fix.sp
echo -e "\nCompiling addons/sourcemod/scripting/block_messages.sp..."
addons/sourcemod/scripting/spcomp -E -w234 -O2 -v2 addons/sourcemod/scripting/block_messages.sp
