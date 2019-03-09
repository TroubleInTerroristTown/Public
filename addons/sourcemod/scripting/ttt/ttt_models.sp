#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Models"

bool g_bEnable = false;
bool g_bEnableArms = false;

int g_iDCount = 0;
int g_iITCount = 0;

bool g_bDebug = false;

StringMap g_smModels = null;

char g_sLog[PLATFORM_MAX_PATH+1];

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    char sDate[12];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
    BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/ttt/ttt_models_%s.log", sDate);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnMapStart()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/models.ini");

    if (!FileExists(sFile))
    {
        SetFailState("[TTT-Models] '%s' not found!", sFile);
        return;
    }
    
    KeyValues kvConfig = new KeyValues("TTT-Models");
    
    if (!kvConfig.ImportFromFile(sFile))
    {
    	delete kvConfig;
        SetFailState("[TTT-Models] Something went wrong with: \"%s\"", sFile);
        return;
    }
    
    delete g_smModels;
    g_smModels = new StringMap();

    if (kvConfig.JumpToKey("Models"))
    {
        g_bEnable = view_as<bool>(kvConfig.GetNum("Enable", 0));
        g_bEnableArms = view_as<bool>(kvConfig.GetNum("EnableArms", 0));
        g_iDCount = kvConfig.GetNum("DModelCount", 1);
        g_iITCount = kvConfig.GetNum("ITModelCount", 1);

        if (!g_bEnable)
        {
            delete kvConfig;
            return;
        }

        if (g_iDCount > 0)
        {
            for(int i = 1; i <= g_iDCount; i++)
            {
                char sName[64];
                char sBuffer[256];
                
                Format(sName, sizeof(sName), "DModel%d", i);
                kvConfig.GetString(sName, sBuffer, sizeof(sBuffer));

                if (g_bDebug)
                {
                    LogToFile(g_sLog, "%s: %s", sName, sBuffer);
                }
                
                if (DirExists(sBuffer))
                {
                    DirectoryListing dModel = OpenDirectory(sBuffer);
                    
                    if (dModel != null)
                    {
                        char sFileName[PLATFORM_MAX_PATH + 1];
                        FileType ftType;
                        
                        while (dModel.GetNext(sFileName, sizeof(sFileName), ftType))
                        {
                            if (ftType == FileType_File)
                            {
                                Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);

                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) sFileName: %s", sFileName);
                                }

                                if (!g_bEnableArms && IsArms(sFileName))
                                {
                                    continue;
                                }
                                
                                if (StrContains(sFileName, ".mdl", false) != -1)
                                {
                                    PrecacheModel(sFileName, true);

                                    if (IsModel(sFileName))
                                    {
                                        g_smModels.SetString(sName, sFileName);

                                        if (g_bDebug)
                                        {
                                            LogToFile(g_sLog, "(OnMapStart) %s SetString: %s - %s", sName, sName, sFileName);
                                        }
                                    }
                                    else if (IsArms(sFileName))
                                    {
                                        char sArms[64];
                                        Format(sArms, sizeof(sArms), "%s_Arms", sName);
                                        g_smModels.SetString(sArms, sFileName);

                                        if (g_bDebug)
                                        {
                                            LogToFile(g_sLog, "(OnMapStart) %s SetString: %s - %s", sArms, sArms, sFileName);
                                        }
                                    }

                                    if (g_bDebug)
                                    {
                                        LogToFile(g_sLog, "(OnMapStart) %s Precache: %s", sName, sFileName);
                                    }
                                }
                                
                                AddFileToDownloadsTable(sFileName);
                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) %s AddDownload: %s", sName, sFileName);
                                }
                            }
                        }
                    }
                    
                    delete dModel;
                }
                else
                {
                    LogError("(OnMapStart) Can't find %s dir: %s", sName, sBuffer);
                }
                
                Format(sName, sizeof(sName), "DMaterial%d", i);
                kvConfig.GetString(sName, sBuffer, sizeof(sBuffer));

                if (g_bDebug)
                {
                    LogToFile(g_sLog, "%s: %s", sName, sBuffer);
                }
                
                if (DirExists(sBuffer))
                {
                    DirectoryListing dMaterial = OpenDirectory(sBuffer);
                    
                    if (dMaterial != null)
                    {
                        char sFileName[PLATFORM_MAX_PATH + 1];
                        FileType ftType;
                        
                        while (dMaterial.GetNext(sFileName, sizeof(sFileName), ftType))
                        {
                            if (ftType == FileType_File)
                            {
                                Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);

                                if (!g_bEnableArms && IsArms(sFileName))
                                {
                                    continue;
                                }
                                
                                AddFileToDownloadsTable(sFileName);
                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) %s AddDownload: %s", sName, sFileName);
                                }
                            }
                        }
                    }
                    
                    delete dMaterial;
                }
                else
                {
                    LogError("(OnMapStart) Can't find %s dir: %s", sName, sBuffer);
                }
            }
        }
        
        if (g_iITCount > 0)
        {
            for(int i = 1; i <= g_iITCount; i++)
            {
                char sName[64];
                char sBuffer[256];
                
                Format(sName, sizeof(sName), "ITModel%d", i);
                kvConfig.GetString(sName, sBuffer, sizeof(sBuffer));

                if (g_bDebug)
                {
                    LogToFile(g_sLog, "%s: %s", sName, sBuffer);
                }
                
                if (DirExists(sBuffer))
                {
                    DirectoryListing dModel = OpenDirectory(sBuffer);
                    
                    if (dModel != null)
                    {
                        char sFileName[PLATFORM_MAX_PATH + 1];
                        FileType ftType;
                        
                        while (dModel.GetNext(sFileName, sizeof(sFileName), ftType))
                        {
                            if (ftType == FileType_File)
                            {
                                Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);
                                
                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) %s sFileName: %s", sName, sFileName);
                                }

                                if (!g_bEnableArms && IsArms(sFileName))
                                {
                                    continue;
                                }
                                
                                if (StrContains(sFileName, ".mdl", false) != -1)
                                {
                                    PrecacheModel(sFileName, true);

                                    if (IsModel(sFileName))
                                    {
                                        g_smModels.SetString(sName, sFileName);

                                        if (g_bDebug)
                                        {
                                            LogToFile(g_sLog, "(OnMapStart) %s SetString: %s - %s", sName, sName, sFileName);
                                        }
                                    }
                                    else if (IsArms(sFileName))
                                    {
                                        char sArms[64];
                                        Format(sArms, sizeof(sArms), "%s_Arms", sName);
                                        g_smModels.SetString(sArms, sFileName);

                                        if (g_bDebug)
                                        {
                                            LogToFile(g_sLog, "(OnMapStart) %s SetString: %s - %s", sArms, sArms, sFileName);
                                        }
                                    }

                                    if (g_bDebug)
                                    {
                                        LogToFile(g_sLog, "(OnMapStart) %s Precache: %s", sName, sFileName);
                                    }
                                }
                                
                                AddFileToDownloadsTable(sFileName);
                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) %s AddDownload: %s", sName, sFileName);
                                }
                            }
                        }
                    }
                    
                    delete dModel;
                }
                else
                {
                    LogError("(OnMapStart) Can't find %s dir: %s", sName, sBuffer);
                }
                
                Format(sName, sizeof(sName), "ITMaterial%d", i);
                kvConfig.GetString(sName, sBuffer, sizeof(sBuffer));

                if (g_bDebug)
                {
                    LogToFile(g_sLog, "%s: %s", sName, sBuffer);
                }
                
                if (DirExists(sBuffer))
                {
                    DirectoryListing dMaterial = OpenDirectory(sBuffer);
                    
                    if (dMaterial != null)
                    {
                        char sFileName[PLATFORM_MAX_PATH + 1];
                        FileType ftType;
                        
                        while (dMaterial.GetNext(sFileName, sizeof(sFileName), ftType))
                        {
                            if (ftType == FileType_File)
                            {
                                Format(sFileName, sizeof(sFileName), "%s/%s", sBuffer, sFileName);

                                if (!g_bEnableArms && IsArms(sFileName))
                                {
                                    continue;
                                }
                                
                                AddFileToDownloadsTable(sFileName);
                                if (g_bDebug)
                                {
                                    LogToFile(g_sLog, "(OnMapStart) %s AddDownload: %s", sName, sFileName);
                                }
                            }
                        }
                    }
                    
                    delete dMaterial;
                }
                else
                {
                    LogError("(OnMapStart) Can't find %s dir: %s", sName, sBuffer);
                }
            }
        }
    }
    else
    {
        SetFailState("Config for '%s' not found!", "Models");

        delete kvConfig;
        return;
    }
    delete kvConfig;
}

public void TTT_OnClientGetRole(int client, int role)
{
    if (g_bEnable)
    {
        SetModel(client, role);
    }
}

public void TTT_OnPlayerRespawn(int client)
{
    if (!TTT_IsRoundActive())
    {
        return;
    }

    if (g_bEnable)
    {
        SetModel(client, TTT_GetClientRole(client));
    }
}

void SetModel(int client, int role)
{
    if (role == TTT_TEAM_DETECTIVE)
    {
        char sName[64];
        char sFileName[PLATFORM_MAX_PATH+1];
        int model = GetRandomInt(1, g_iDCount);

        Format(sName, sizeof(sName), "DModel%d", model);
        g_smModels.GetString(sName, sFileName, sizeof(sFileName));
        SetEntityModel(client, sFileName);

        if (g_bDebug)
        {
            LogToFile(g_sLog, "Player Model: %N (Detective), Model: (%d) %s", client, model, sFileName);
        }
        
        if (g_bEnableArms)
        {
            Format(sName, sizeof(sName), "%s_Arms", sName);
            g_smModels.GetString(sName, sFileName, sizeof(sFileName));

            SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
            SetEntPropString(client, Prop_Send, "m_szArmsModel", sFileName);

            if (g_bDebug)
            {
                LogToFile(g_sLog, "Player Arms: %N (Detective), Arms: (%d) %s", client, model, sFileName);
            }
        }
    }
    
    if (role == TTT_TEAM_INNOCENT || role == TTT_TEAM_TRAITOR)
    {
        char sName[64],  sRole[ROLE_LENGTH];
        char sFileName[PLATFORM_MAX_PATH+1];
        int model = GetRandomInt(1, g_iITCount);

        TTT_GetRoleNameByID(role, sRole, sizeof(sRole));
        Format(sName, sizeof(sName), "ITModel%d", model);
        g_smModels.GetString(sName, sFileName, sizeof(sFileName));
        SetEntityModel(client, sFileName);

        if (g_bDebug)
        {
            LogToFile(g_sLog, "Player Model: %N (%s), Model: (%d) %s", client, sRole, model, sFileName);
        }

        if (g_bEnableArms)
        {
            Format(sName, sizeof(sName), "%s_Arms", sName);
            g_smModels.GetString(sName, sFileName, sizeof(sFileName));

            SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
            SetEntPropString(client, Prop_Send, "m_szArmsModel", sFileName);

            if (g_bDebug)
            {
                LogToFile(g_sLog, "Player Arms: %N (%s), Arms: (%d) %s", client, sRole, model, sFileName);
            }
        }
    }
}

bool IsModel(char[] model)
{
    if (StrContains(model, ".mdl", false) != -1 && StrContains(model, ".bz2", false) == -1 && StrContains(model, "_arms", false) == -1)
    {
        return true;
    }
    
    return false;
}

bool IsArms(char[] model)
{
    if (StrContains(model, ".mdl", false) != -1 && StrContains(model, ".bz2", false) == -1 && StrContains(model, "_arms", false) != -1)
    {
        return true;
    }
    
    return false;
}
