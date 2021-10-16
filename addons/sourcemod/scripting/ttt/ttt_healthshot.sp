#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <colorlib>

#define SHORT_NAME "healthshot"
#define SHORT_NAME_D "healthshot_d"
#define SHORT_NAME_T "healthshot_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Healthshot"

ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cIPrice = null;
ConVar g_cILimit = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cIPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cICount = null;
ConVar g_cLongName = null;

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

    TTT_StartConfig("healthshot");
    CreateConVar("ttt2_healthshot_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("healthshot_name", "Health Shot", "The name of the Healtshot in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("healthshot_traitor_price", "9000", "The amount of credits for healthshot costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("healthshot_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("healthshot_detective_price", "9000", "The amount of credits for healthshot costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("healthshot_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIPrice = AutoExecConfig_CreateConVar("healthshot_innocent_price", "9000", "The amount of credits for healthshot costs as innocent. 0 to disable.");
    g_cILimit = AutoExecConfig_CreateConVar("healthshot_innocent_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTCount = AutoExecConfig_CreateConVar("healthshot_traitor_count", "1", "The amount of usages for healthshots per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("healthshot_detective_count", "1", "The amount of usages for healthshots per round as detective. 0 to disable.");
    g_cICount = AutoExecConfig_CreateConVar("healthshot_innocent_count", "1", "The amount of usages for healthshots per round as innocent. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("healthshot_traitor_sort_prio", "0", "The sorting priority of the healthshots (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("healthshot_detective_sort_prio", "0", "The sorting priority of the healthshots (Detective) in the shop menu.");
    g_cIPrio = AutoExecConfig_CreateConVar("healthshot_innocent_sort_prio", "0", "The sorting priority of the healthshots (Innocent) in the shop menu.");
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
        TTT_RemoveShopItem(SHORT_NAME);
    }
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
    
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cICount.IntValue, g_cILimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    GivePlayerItem(client, "weapon_healthshot");
    
    TTT_AddItemUsage(client, itemshort);
    return Plugin_Continue;
}
