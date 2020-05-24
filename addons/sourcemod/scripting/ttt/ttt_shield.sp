#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Shield"

#define SHORT_NAME "buyShield"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLimit = null;
ConVar g_cLimitRound = null;

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

    TTT_StartConfig("shield");
    CreateConVar("ttt2_shield_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("shield_name", "Shield", "The name of the item in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("shield_price", "9000", "The amount of credits that cost to buy this item. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("shield_prio", "0", "The sorting priority of the buy it in the shop menu.");
    g_cLimit = AutoExecConfig_CreateConVar("shield_limit", "0", "The amount of purchases for players during a round.", _, true, 0.0);
    g_cLimitRound = AutoExecConfig_CreateConVar("shield_limit_round", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, SHOP_ITEM_4ALL, g_cPrio.IntValue, g_cLimit.IntValue, g_cLimitRound.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    EquipPlayerWeapon(client, GivePlayerItem(client, "weapon_shield"));
}
