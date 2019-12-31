#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#undef REQUIRE_PLUGIN
#include <customkeyvalues>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Doors"

ConVar g_cLogDoorUse = null;
ConVar g_cLogDoorsSpam = null;
ConVar g_cAddLogs = null;
ConVar g_cLogFormat = null;

bool g_bPressed[MAXPLAYERS + 1] = { false, ... };

bool g_bCustomKeyValues = false;

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

    TTT_StartConfig("traitordoors");
    CreateConVar("ttt2_traitor_door_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLogDoorUse = AutoExecConfig_CreateConVar("traitordoor_log_use", "1", "Log use of traitor doors?", _, true, 0.0, true, 1.0);
    g_cLogDoorsSpam = AutoExecConfig_CreateConVar("traitordoor_log_doors_time", "1", "Prevent log spamming for the same doors - Time in seconds");
    TTT_EndConfig();

    g_bCustomKeyValues = LibraryExists("CustomKeyValues");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = false;
    }
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    g_cAddLogs = FindConVar("ttt_steamid_add_to_logs");
    g_cLogFormat = FindConVar("ttt_steamid_log_format");
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    char sClass[64];
    char sName[64];

    for (int i = MaxClients; i < GetMaxEntities(); i++)
    {
        if (IsValidEdict(i) && IsValidEntity(i))
        {
            GetEdictClassname(i, sClass, sizeof(sClass));
            GetEntPropString(i, Prop_Data, "m_iName", sName, sizeof(sName));

            if ((StrContains(sClass, "_door", false) != -1 || StrContains(sClass, "_room", false) != -1) && StrContains(sName, "traitor", false) != -1)
            {
                AcceptEntityInput(i, "Lock");

                HookSingleEntityOutput(i, "OnLockedUse", OnLockedUse);
            }
        }
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!TTT_IsRoundActive())
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (!IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    if (!(buttons & IN_USE))
    {
        return Plugin_Continue;
    }

    if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
    {
        return Plugin_Continue;
    }

    int target = GetClientAimTarget(client, false);

    if (!IsValidEntity(target) || !IsValidEdict(target))
    {
        return Plugin_Continue;
    }

    if (g_bCustomKeyValues)
    {
        char sCustom[4];
        bool success = GetCustomKeyValue(target, "ttt_traitor_only", sCustom, sizeof(sCustom));

        if (success)
        {
            if (view_as<bool>(StringToInt(sCustom)) && TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
            {
                return Plugin_Continue;
            }
        }
    }

    char sClass[64];
    char sName[64];
    GetEdictClassname(target, sClass, sizeof(sClass));
    GetEntPropString(target, Prop_Data, "m_iName", sName, sizeof(sName));

    if ((StrContains(sClass, "_door", false) != -1 || StrContains(sClass, "_room", false) != -1) && StrContains(sName, "traitor", false) != -1)
    {
        AcceptEntityInput(target, "Unlock");
        AcceptEntityInput(target, "Open");
        AcceptEntityInput(target, "Lock");

        if (g_cLogDoorUse != null && g_cLogDoorUse.BoolValue && !g_bPressed[target])
        {
            char sClientID[32];

            if (g_cAddLogs != null && g_cAddLogs.BoolValue)
            {
                if (g_cLogFormat.IntValue == 1)
                {
                    GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
                }
                else if (g_cLogFormat.IntValue == 2)
                {
                    GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
                }
                else if (g_cLogFormat.IntValue == 3)
                {
                    GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
                }
                
                if (strlen(sClientID) > 2)
                {
                    Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
                }
            }
            
            TTT_LogString("-> [%N%s (Traitor) opened a traitor door: %s]", client, sClientID, sName);

            g_bPressed[target] = true;
            CreateTimer(g_cLogDoorsSpam.FloatValue, Timer_EnableLog, EntIndexToEntRef(target));
        }
    }

    return Plugin_Continue;
}

public int OnLockedUse(const char[] output, int caller, int attacker, float data)
{
    if (TTT_GetClientRole(attacker) != TTT_TEAM_TRAITOR)
    {
        return;
    }

    AcceptEntityInput(caller, "Unlock");
    AcceptEntityInput(caller, "Open");
    AcceptEntityInput(caller, "Lock");

    if (g_cLogDoorUse != null && g_cLogDoorUse.BoolValue && !g_bPressed[caller])
    {
        char sClientID[32];

        if (g_cAddLogs != null && g_cAddLogs.BoolValue)
        {
            if (g_cLogFormat.IntValue == 1)
            {
                GetClientAuthId(attacker, AuthId_Steam2, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 2)
            {
                GetClientAuthId(attacker, AuthId_Steam3, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 3)
            {
                GetClientAuthId(attacker, AuthId_SteamID64, sClientID, sizeof(sClientID));
            }
            
            if (strlen(sClientID) > 2)
            {
                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
            }
        }

        char sName[64];
        GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

        TTT_LogString("-> [%N%s (Traitor) opened a traitor door: %s]", attacker, sClientID, sName);

        g_bPressed[caller] = true;
        CreateTimer(g_cLogDoorsSpam.FloatValue, Timer_EnableLog, EntIndexToEntRef(caller));
    }
}

public Action Timer_EnableLog(Handle timer, any reference)
{
    int doors = EntRefToEntIndex(reference);
    
    if (IsValidEntity(doors))
    {
        g_bPressed[doors] = false;
    }
}
