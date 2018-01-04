#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Models"
#define CONFIG_FILE "addons/sourcemod/configs/ttt/models.ini"

bool g_bEnable = false;

int g_iDCount = 0;
int g_ITCount = 0;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();
}

public void OnMapStart()
{
	if (!FileExists(CONFIG_FILE))
	{
		SetFailState("[TTT-Models] '%s' not found!", CONFIG_FILE);
		return;
	}
	
	Handle hConfig = CreateKeyValues("TTT-Models");
	
	FileToKeyValues(hConfig, CONFIG_FILE);
	if (KvJumpToKey(hConfig, "Models"))
	{
		g_bEnable = view_as<bool>(KvGetNum(hConfig, "Enable", 0));
		g_iDCount = KvGetNum(hConfig, "DModelCount", 1);
		g_ITCount = KvGetNum(hConfig, "ITModelCount", 1);

		if (!g_bEnable)
		{
			return;
		}

		if (g_iDCount > 0)
		{
			for(int i = 1; i <= g_iDCount; i++)
			{
				char sName[64];
				char sBuffer[256];
				
				Format(sName, sizeof(sName), "DModel%d", i);
				KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
				
				if (DirExists(sBuffer))
				{
					Handle hModelDir = OpenDirectory(sBuffer);
					
					if (hModelDir != null)
					{
						char sFileName[PLATFORM_MAX_PATH + 1];
						FileType ftType;
						
						while (ReadDirEntry(hModelDir, sFileName, sizeof(sFileName), ftType))
						{
							if (ftType == FileType_File)
							{
								Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
								
								if (StrContains(sFileName, ".mdl", false) != -1)
								{
									PrecacheModel(sFileName, true);
								}
								
								AddFileToDownloadsTable(sFileName);
							}
						}
					}
					
					delete hModelDir;
				}
				
				Format(sName, sizeof(sName), "DMaterial%d", i);
				KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
				
				if (DirExists(sBuffer))
				{
					Handle hMaterialDir = OpenDirectory(sBuffer);
					
					if (hMaterialDir != null)
					{
						char sFileName[PLATFORM_MAX_PATH + 1];
						FileType ftType;
						
						while (ReadDirEntry(hMaterialDir, sFileName, sizeof(sFileName), ftType))
						{
							if (ftType == FileType_File)
							{
								Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
								
								if (StrContains(sFileName, ".mdl", false) != -1)
								{
									PrecacheModel(sFileName, true);
								}
								
								AddFileToDownloadsTable(sFileName);
							}
						}
					}
					
					delete hMaterialDir;
				}
			}
		}
		
		if (g_ITCount > 0)
		{
			for(int i = 1; i <= g_ITCount; i++)
			{
				char sName[64];
				char sBuffer[256];
				
				Format(sName, sizeof(sName), "ITModel%d", i);
				KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
				
				if (DirExists(sBuffer))
				{
					Handle hModelDir = OpenDirectory(sBuffer);
					
					if (hModelDir != null)
					{
						char sFileName[PLATFORM_MAX_PATH + 1];
						FileType ftType;
						
						while (ReadDirEntry(hModelDir, sFileName, sizeof(sFileName), ftType))
						{
							if (ftType == FileType_File)
							{
								Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
								
								if (StrContains(sFileName, ".mdl", false) != -1)
								{
									PrecacheModel(sFileName, true);
								}
								
								AddFileToDownloadsTable(sFileName);
							}
						}
					}
					
					delete hModelDir;
				}
				
				Format(sName, sizeof(sName), "ITMaterial%d", i);
				KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
				
				if (DirExists(sBuffer))
				{
					Handle hMaterialDir = OpenDirectory(sBuffer);
					
					if (hMaterialDir != null)
					{
						char sFileName[PLATFORM_MAX_PATH + 1];
						FileType ftType;
						
						while (ReadDirEntry(hMaterialDir, sFileName, sizeof(sFileName), ftType))
						{
							if (ftType == FileType_File)
							{
								Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
								
								if (StrContains(sFileName, ".mdl", false) != -1)
								{
									PrecacheModel(sFileName, true);
								}
								
								AddFileToDownloadsTable(sFileName);
							}
						}
					}
					
					delete hMaterialDir;
				}
			}
		}
	}
	else
	{
		SetFailState("Config for '%s' not found!", "Models");
		return;
	}
	delete hConfig;
}

public void TTT_OnClientGetRole(int client, int role)
{
	if (g_bEnable)
	{
		SetModel(client, role);
	}
}

void SetModel(int client, int role)
{
	Handle hConfig = CreateKeyValues("TTT-Models");

	if (!FileExists(CONFIG_FILE))
	{
		SetFailState("[TTT-Models] '%s' not found!", CONFIG_FILE);
		return;
	}

	FileToKeyValues(hConfig, CONFIG_FILE);

	if (role == TTT_TEAM_DETECTIVE)
	{
		char sName[64];
		char sBuffer[256];
		int model = GetRandomInt(1, g_iDCount);
		
		Format(sName, sizeof(sName), "DModel%d", model);
		if (KvJumpToKey(hConfig, "Models"))
		{
			KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
		}
		
		if (DirExists(sBuffer))
		{
			Handle hDir = OpenDirectory(sBuffer);
			
			if (hDir != null)
			{
				char sFileName[PLATFORM_MAX_PATH + 1];
				FileType ftType;
				
				while (ReadDirEntry(hDir, sFileName, sizeof(sFileName), ftType))
				{
					if (ftType == FileType_File)
					{
						Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
						
						if (StrContains(sFileName, ".mdl", false) != -1)
						{
							SetEntityModel(client, sFileName);
						}
					}
				}
			}
			
			delete hDir;
		}
	}
	
	if (role == TTT_TEAM_INNOCENT || role == TTT_TEAM_TRAITOR)
	{
		char sName[64];
		char sBuffer[256];
		int model = GetRandomInt(1, g_ITCount);
		
		Format(sName, sizeof(sName), "ITModel%d", model);
		if (KvJumpToKey(hConfig, "Models"))
		{
			KvGetString(hConfig, sName, sBuffer, sizeof(sBuffer));
		}
		
		if (DirExists(sBuffer))
		{
			Handle hDir = OpenDirectory(sBuffer);
			
			if (hDir != null)
			{
				char sFileName[PLATFORM_MAX_PATH + 1];
				FileType ftType;
				
				while (ReadDirEntry(hDir, sFileName, sizeof(sFileName), ftType))
				{
					if (ftType == FileType_File)
					{
						Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
						
						if (StrContains(sFileName, ".mdl", false) != -1)
						{
							SetEntityModel(client, sFileName);
						}
					}
				}
			}
			
			delete hDir;
		}
	}
	
	delete hConfig;
}
