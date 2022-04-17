#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#undef REQUIRE_PLUGIN
#include <tacticalshield>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Tactical Shield"

#define SHORT_NAME_D "tacShield_d"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cForce = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;

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
    g_cCount = AutoExecConfig_CreateConVar("tactical_shield_count", "1", "Amount of purchases for tactical shield");
    g_cLimit = AutoExecConfig_CreateConVar("tactical_shield_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "tacticalshield.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveShopItem(SHORT_NAME_D);
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
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnClientPutInServer(int client)
{
    ResetTacticalShield(client);
}

public void OnClientDisconnect(int client)
{
    ResetTacticalShield(client);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_DETECTIVE)
    {
        return Plugin_Stop;
    }

    ResetTacticalShield(client);

    TTT_AddInventoryItem(client, SHORT_NAME_D);

    GivePlayerShield(client);

    if (g_cForce.BoolValue)
    {
        RequestFrame(Frame_SetShield, GetClientUserId(client));
    }

    return Plugin_Continue;
}

public void Frame_SetShield(any userid)
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
    
    return Plugin_Continue;
}

void ResetTacticalShield(int client)
{
    if (IsClientInGame(client))
    {
        RemovePlayerShield(client);
    }
}
