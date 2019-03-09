#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Doors"

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
    CreateConVar("ttt2_traitor_door_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
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

    char sClass[64];
    char sName[64];
    GetEdictClassname(target, sClass, sizeof(sClass));
    GetEntPropString(target, Prop_Data, "m_iName", sName, sizeof(sName));

    if ((StrContains(sClass, "_door", false) != -1 || StrContains(sClass, "_room", false) != -1) && StrContains(sName, "traitor", false) != -1)
    {
        AcceptEntityInput(target, "Unlock");
        AcceptEntityInput(target, "Open");
        AcceptEntityInput(target, "Lock");
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
}
