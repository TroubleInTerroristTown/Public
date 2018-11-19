#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Fake Name"
#define SHORT_NAME "fakename_t"
#define SHORT_NAME_INVI "invisName_t"

/* ConVars of fakename */
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cTimer = null;
ConVar g_cLongName = null;
ConVar g_cIgnoreRole = null;

int g_iCount[MAXPLAYERS + 1] = { 0, ... };
Handle g_hTimer[MAXPLAYERS + 1] = { null, ... };
char g_sName[MAXPLAYERS +  1][MAX_NAME_LENGTH];

/* ConVars of invisible name */
ConVar g_cInviPrice = null;
ConVar g_cInviPrio = null;
ConVar g_cInviCount = null;
ConVar g_cInviTimer = null;
ConVar g_cInviLongName = null;

int g_iInviCount[MAXPLAYERS + 1] = { 0, ... };
Handle g_hInviTimer[MAXPLAYERS + 1] = { null, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

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

    TTT_LoadTranslations();
    
    TTT_StartConfig("fakename");
    CreateConVar("fakename_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("fakename_name", "Fake Name", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("fakename_price", "5000", "The amount of credits fakename costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("fakename_sort_prio", "0", "The sorting priority of the fakename in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("fakename_count", "5", "The number of fakename that the player can use in a round");
    g_cTimer = AutoExecConfig_CreateConVar("fakename_timer", "15.0", "The time the target should be renamed");
    g_cIgnoreRole = AutoExecConfig_CreateConVar("fakename_ignore_role", "4", "Which role should be ignored when traitor use fakename? -1 - Disabled ( https://github.com/Bara/TroubleinTerroristTown/wiki/CVAR-Masks )", _, true, 2.0);

    g_cInviLongName = AutoExecConfig_CreateConVar("invisible_name_name", "Invisible Name", "The name of this in Shop");
    g_cInviPrice = AutoExecConfig_CreateConVar("invisible_name_price", "5000", "The amount of credits invisiblename costs as traitor. 0 to disable.");
    g_cInviPrio = AutoExecConfig_CreateConVar("invisible_name_sort_prio", "0", "The sorting priority of the invisiblename in the shop menu.");
    g_cInviCount = AutoExecConfig_CreateConVar("invisible_name_count", "5", "The number of invisiblename that the player can use in a round");
    g_cInviTimer = AutoExecConfig_CreateConVar("invisible_name_timer", "15.0", "The time the target should have a invisible name");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_Player);
    HookEvent("player_death", Event_Player);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    CheckPlayerID();

    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void TTT_OnShopReady()
{
    char sName[128];
    g_cLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);

    g_cInviLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterCustomItem(SHORT_NAME_INVI, sName, g_cInviPrice.IntValue, TTT_TEAM_TRAITOR, g_cInviPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            if (!CheckPlayerID())
            {
                return Plugin_Stop;
            }

            int role = TTT_GetClientRole(client);

            char sName[128];
            g_cLongName.GetString(sName, sizeof(sName));
            
            if (role != TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }

            if (g_hTimer[client] != null || g_hInviTimer[client] != null)
            {
                return Plugin_Stop;
            }
            
            if (g_iCount[client] >= g_cCount.IntValue)
            {
                return Plugin_Stop;
            }
            
            int iTarget = TTT_GetRandomPlayer(false, g_cIgnoreRole.IntValue);

            while (iTarget == client)
            {
                iTarget = TTT_GetRandomPlayer(false, g_cIgnoreRole.IntValue);
            }

            if (!TTT_IsClientValid(iTarget))
            {
                return Plugin_Stop;
            }

            if (!GetClientName(iTarget, g_sName[client], sizeof(g_sName[])))
            {
                return Plugin_Stop;
            }

            CPrintToChat(client, "%s %T", g_sPluginTag, "Fake Name: New Name", client, g_cTimer.FloatValue, g_sName[client]);

            g_iCount[client]++;
            g_hTimer[client] = CreateTimer(g_cTimer.FloatValue, Timer_ResetName, GetClientUserId(client));
        }
        else if (StrEqual(itemshort, SHORT_NAME_INVI, false))
        {
            if (!CheckPlayerID())
            {
                return Plugin_Stop;
            }

            int role = TTT_GetClientRole(client);

            char sName[128];
            g_cLongName.GetString(sName, sizeof(sName));
            
            if (role != TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }

            if (g_hTimer[client] != null || g_hInviTimer[client] != null)
            {
                return Plugin_Stop;
            }
            
            if (g_iInviCount[client] >= g_cInviCount.IntValue)
            {
                return Plugin_Stop;
            }

            CPrintToChat(client, "%s %T", g_sPluginTag, "Invisible Name: Start", client, g_cTimer.FloatValue);

            g_iCount[client]++;
            g_hInviTimer[client] = CreateTimer(g_cInviTimer.FloatValue, Timer_ResetInvi, GetClientUserId(client));
        }
    }
    return Plugin_Continue;
}

public Action Timer_ResetName(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_hTimer[client] = null;
        Format(g_sName[client], sizeof(g_sName[]), "");
        CPrintToChat(client, "%s %T", g_sPluginTag, "Fake Name: Name expired", client);
    }

    return Plugin_Stop;
}

public Action Timer_ResetInvi(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_hInviTimer[client] = null;
        CPrintToChat(client, "%s %T", g_sPluginTag, "Invisible Name: Stop", client);
    }

    return Plugin_Stop;
}

public Action TTT_OnHudSend_Pre(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int &iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength)
{
    if (g_hTimer[target] != null && strlen(g_sName[target]) > 1)
    {
        iPlayerNameLength = sizeof(g_sName[]);
        Format(sPlayerName, iPlayerNameLength, g_sName[target]);
    }

    if (g_hInviTimer[target])
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Event_Player(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetFakename(client);
        ResetInvisible(client);
    }
}

void ResetFakename(int client)
{
    g_iCount[client] = 0;

    if (g_hTimer[client] != null)
    {
        KillTimer(g_hTimer[client]);
    }

    g_hTimer[client] = null;
    Format(g_sName[client], sizeof(g_sName[]), "");
}


void ResetInvisible(int client)
{
    g_iInviCount[client] = 0;

    if (g_hInviTimer[client] != null)
    {
        KillTimer(g_hInviTimer[client]);
    }

    g_hInviTimer[client] = null;
}

bool CheckPlayerID()
{
    ConVar cvar = FindConVar("mp_playerid");

    if (cvar == null)
    {
        return false;
    }

    if (cvar.IntValue == 2)
    {
        return true;
    }

    LogError("Fake Name and Invisible Name requires \"mp_playerid 2\". Both items has been unloaded!");
    TTT_RemoveCustomItem(SHORT_NAME);
    TTT_RemoveCustomItem(SHORT_NAME_INVI);

    return false;
}
