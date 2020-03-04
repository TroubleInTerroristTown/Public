#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#undef REQUIRE_PLUGIN
#include <AdvancedParachute>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Parachute"
#define SHORT_NAME "parachute"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
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
    
    TTT_StartConfig("parachute");
    CreateConVar("ttt2_parachute_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("parachute_name", "Parachute", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("parachute_price", "3000", "The amount of credits parachutes costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("parachute_sort_prio", "0", "The sorting priority of the parachutes in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("parachute_count", "1", "Amount of purchases per round");
    g_cLimit = AutoExecConfig_CreateConVar("parachute_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "AdvancedParachute.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveShopItem(SHORT_NAME);
        SetFailState("You must have this plugin as base plugin for this item: https://forums.alliedmods.net/showthread.php?p=2534158");
        return;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, SHOP_ITEM_4ALL, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (TTT_IsItemInInventory(client, SHORT_NAME))
    {
        return Plugin_Stop;
    }

    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public Action OnParachuteOpen(int client)
{
    if (TTT_IsItemInInventory(client, SHORT_NAME))
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}
