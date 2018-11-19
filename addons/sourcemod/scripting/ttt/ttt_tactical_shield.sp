#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#undef REQUIRE_PLUGIN
#include <tacticalshield>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tactical Shield"

#define SHORT_NAME_D "tacShield_d"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cForce = null;

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

    TTT_StartConfig("tactical_shield");
    CreateConVar("ttt2_tactical_shield_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("tactical_shield_name", "Tactical Shield", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("tactical_shield_price", "9000", "The amount of credits a tactical shield costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("tactical_shield_sort_prio", "0", "The sorting priority of the tactical shield in the shop menu.");
    g_cForce = AutoExecConfig_CreateConVar("tactical_shield_force", "0", "Force shield?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "tacticalshield.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveCustomItem(SHORT_NAME_D);
        SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?t=303333");
        return;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue);
}

public void OnClientPutInServer(int client)
{
    ResetTacticalShield(client);
}

public void OnClientDisconnect(int client)
{
    ResetTacticalShield(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME_D, false))
        {
            ResetTacticalShield(client);
            
            int role = TTT_GetClientRole(client);

            if (role == TTT_TEAM_DETECTIVE)
            {
                GivePlayerShield(client);

                if (g_cForce.BoolValue)
                {
                    RequestFrame(Frame_SetShield, GetClientUserId(client));
                }
            }
            else
            {
                return Plugin_Stop;
            }
        }
    }
    return Plugin_Continue;
}


public void Frame_SetShield(int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        SetEquipPlayerShield(client, true);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetTacticalShield(client);
    }
}

void ResetTacticalShield(int client)
{
    if (IsClientInGame(client))
    {
        RemovePlayerShield(client);
    }
}
