#if defined _cfloader_included
 #endinput
#endif
#define _cfloader_included

/*
 *	All credit for this handy config-loading method goes to
 *	Bara, and his efforts in the TTT project. To use, before
 * 	loading set the KeyValues branch name (for example, TTT uses "TTT")
 *	and the config file (build the path first).
 
 *	Example:
 *		BuildPath(Path_SM, myfile, sizeof(myfile), "configs/rpgsettings.cfg");
 *		Config_Setup("RPG-Settings", myfile);
 *		Config_LoadBool("my_setting", false, "Description: My example setting");
 *
 *
 *	TTT Implementation -
 *		http://git.tf/TTT/Plugin/blob/3d3bd4e549aed1109f51111318436e98c919f23c/addons/sourcemod/scripting/ttt/ttt.sp#L4324
 *		From the highlighted line below
 * 	Bara -
 *		http://git.tf/u/Bara
 *		https://github.com/Bara20
 */



char __g_sConfigFile[PLATFORM_MAX_PATH];
char __g_sConfigName[128];

stock bool Config_Setup(const char[] name, const char[] file){
	FormatEx(__g_sConfigFile, PLATFORM_MAX_PATH, "%s", file);
	FormatEx(__g_sConfigName, sizeof(__g_sConfigName), "%s", name);
}

stock int Config_LoadInt(const char[] name, int value, const char[] description){
	KeyValues kv = CreateKeyValues(__g_sConfigName);
	
	if(!kv.ImportFromFile(__g_sConfigFile))
		LogMessage("[CONFIG LOADER] Couldn't read file %s! Will be built now!", __g_sConfigFile);
	
	if(kv.JumpToKey(name, false))
		value = kv.GetNum("value");
	else
	{
		LogMessage("[CONFIG LOADER] Can't find setting '%s' in %s! Adding default value.", name, __g_sConfigFile);
		kv.JumpToKey(name, true);
		kv.SetNum("value", value);
		kv.SetString("description", description);
		kv.Rewind();
		kv.ExportToFile(__g_sConfigFile);
	}
	
	delete kv;
	return value;
}

stock bool Config_LoadBool(const char[] name, bool value, const char[] description){
	KeyValues kv = CreateKeyValues(__g_sConfigName);
	
	if(!kv.ImportFromFile(__g_sConfigFile))
		LogMessage("[CONFIG LOADER] Couldn't read file %s! Will be built now!", __g_sConfigFile);

	if(kv.JumpToKey(name, false))
		value = view_as<bool>(kv.GetNum("value"));
	else
	{
		LogMessage("[CONFIG LOADER] Can't find setting '%s' in %s! Adding default value.", name, __g_sConfigFile);
		kv.JumpToKey(name, true);
		kv.SetNum("value", value);
		kv.SetString("description", description);
		kv.Rewind();
		kv.ExportToFile(__g_sConfigFile);
	}

	delete kv;
	return value;
}

stock float Config_LoadFloat(const char[] name, float value, const char[] description){
	KeyValues kv = CreateKeyValues(__g_sConfigName);
	
	if(!kv.ImportFromFile(__g_sConfigFile))
		LogMessage("[CONFIG LOADER] Couldn't read file %s! Will be built now!", __g_sConfigFile);
	
	if(kv.JumpToKey(name, false))
		value = view_as<float>(kv.GetFloat("value"));
	else
	{
		LogMessage("[CONFIG LOADER] Can't find setting '%s' in %s! Adding default value.", name, __g_sConfigFile);
		kv.JumpToKey(name, true);
		kv.SetFloat("value", value);
		kv.SetString("description", description);
		kv.Rewind();
		kv.ExportToFile(__g_sConfigFile);
	}
	
	delete kv;
	return value;
}

stock void Config_LoadString(const char[] name, const char[] value, const char[] description, char[] output, int size){
	strcopy(output, size, value);
	
	KeyValues kv = CreateKeyValues(__g_sConfigName);
	
	if(!kv.ImportFromFile(__g_sConfigFile))
		LogMessage("[CONFIG LOADER] Couldn't read file %s! Will be built now!", __g_sConfigFile);
	
	if(kv.JumpToKey(name, false))
		kv.GetString("value", output, size);
	else
	{
		LogMessage("[CONFIG LOADER] Can't find setting '%s' in %s! Adding default value.", name, __g_sConfigFile);
		kv.JumpToKey(name, true);
		kv.SetString("value", value);
		kv.SetString("description", description);
		kv.Rewind();
		kv.ExportToFile(__g_sConfigFile);
	}
	
	delete kv;
}