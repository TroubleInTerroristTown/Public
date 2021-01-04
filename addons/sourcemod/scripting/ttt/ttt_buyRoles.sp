#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Buy Roles"

#define T_SHORT_NAME "buyTRole"
#define TI_SHORT_NAME "buyTiRole"

#define D_SHORT_NAME "buyCTRole"
#define DI_SHORT_NAME "buyCTiRole"

ConVar g_cTPrice = null;
ConVar g_cTPrio = null;
ConVar g_cTiPrice = null;
ConVar g_cTiPrio = null;
ConVar g_cDPrice = null;
ConVar g_cDPrio = null;
ConVar g_cDiPrice = null;
ConVar g_cDiPrio = null;
ConVar g_cTLimit = null;
ConVar g_cTiLimit = null;
ConVar g_cDLimit = null;
ConVar g_cDiLimit = null;
ConVar g_cTLongName = null;
ConVar g_cTiLongName = null;
ConVar g_cDLongName = null;
ConVar g_cDiLongName = null;

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

    TTT_StartConfig("buyroles");
    CreateConVar("ttt2_buy_roles_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cTLongName = AutoExecConfig_CreateConVar("buyroles_traitor_name", "Traitor", "The name of the buy traitor role in the Shop");
    g_cTiLongName = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_name", "Traitor Instantly", "The name of the buy traitor role in the Shop");
    g_cDLongName = AutoExecConfig_CreateConVar("buyroles_detective_name", "Detective", "The name of the buy detective role in the Shop");
    g_cDiLongName = AutoExecConfig_CreateConVar("buyroles_detective_instantly_name", "Detective Instantly", "The name of the buy detective role in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("buyroles_traitor_price", "9000", "The amount of credits that cost to buy the traitor role. 0 to disable.");
    g_cTiPrice = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_price", "40000", "The amount of credits that cost to buy the traitor instantly role. 0 to disable.");
    g_cDPrice = AutoExecConfig_CreateConVar("buyroles_detective_price", "9000", "The amount of credits that cost to buy the detective role. 0 to disable.");
    g_cDiPrice = AutoExecConfig_CreateConVar("buyroles_detective_instantly_price", "10000", "The amount of credits that cost to buy the detective instantly role. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("buyroles_traitor_prio", "0", "The sorting priority of the buy traitor role in the shop menu.");
    g_cTiPrio = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_prio", "0", "The sorting priority of the buy traitor instantly role in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("buyroles_detective_prio", "0", "The sorting priority of the buy detective role in the shop menu.");
    g_cDiPrio = AutoExecConfig_CreateConVar("buyroles_detective_instantly_prio", "0", "The sorting priority of the buy detective instantly role in the shop menu.");
    g_cTLimit = AutoExecConfig_CreateConVar("buyroles_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTiLimit = AutoExecConfig_CreateConVar("buyroles_traitor_instantly_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDLimit = AutoExecConfig_CreateConVar("buyroles_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDiLimit = AutoExecConfig_CreateConVar("buyroles_detective_instantly_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(T_SHORT_NAME);
        TTT_RemoveShopItem(TI_SHORT_NAME);
        TTT_RemoveShopItem(D_SHORT_NAME);
        TTT_RemoveShopItem(DI_SHORT_NAME);
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

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cTLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(T_SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_INNOCENT, g_cTPrio.IntValue, 1, g_cTLimit.IntValue, OnItemPurchased, false);
    
    g_cTiLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(TI_SHORT_NAME, sBuffer, g_cTiPrice.IntValue, TTT_TEAM_INNOCENT, g_cTiPrio.IntValue, 1, g_cTiLimit.IntValue, OnItemPurchased);
    
    g_cDLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(D_SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_INNOCENT, g_cDPrio.IntValue, 1, g_cDLimit.IntValue, OnItemPurchased, false);
    
    g_cDiLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(DI_SHORT_NAME, sBuffer, g_cDiPrice.IntValue, TTT_TEAM_INNOCENT, g_cDiPrio.IntValue, 1, g_cDiLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if ((StrEqual(itemshort, D_SHORT_NAME, false) || StrEqual(itemshort, T_SHORT_NAME, false)) && (TTT_IsItemInInventory(client, D_SHORT_NAME) || TTT_IsItemInInventory(client, T_SHORT_NAME)))
    {
        return Plugin_Stop;
    }

    if ((StrEqual(itemshort, DI_SHORT_NAME, false) || StrEqual(itemshort, TI_SHORT_NAME, false)) && (TTT_IsItemInInventory(client, DI_SHORT_NAME) || TTT_IsItemInInventory(client, TI_SHORT_NAME)))
    {
        return Plugin_Stop;
    }

    if (StrEqual(itemshort, D_SHORT_NAME, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_INNOCENT)
        {
            return Plugin_Stop;
        }

        if(!TTT_ForceDetective(client))
        {
            return Plugin_Stop;
        }

        TTT_AddInventoryItem(client, D_SHORT_NAME);
    }
    else if (StrEqual(itemshort, T_SHORT_NAME, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_INNOCENT)
        {
            return Plugin_Stop;
        }

        if(!TTT_ForceTraitor(client))
        {
            return Plugin_Stop;
        }

        TTT_AddInventoryItem(client, T_SHORT_NAME);
    }
    else if (StrEqual(itemshort, DI_SHORT_NAME, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_INNOCENT)
        {
            return Plugin_Stop;
        }

        TTT_SetClientRole(client, TTT_TEAM_DETECTIVE);
        TTT_AddInventoryItem(client, DI_SHORT_NAME);
    }
    else if (StrEqual(itemshort, TI_SHORT_NAME, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_INNOCENT)
        {
            return Plugin_Stop;
        }

        TTT_SetClientRole(client, TTT_TEAM_TRAITOR);
        TTT_AddInventoryItem(client, TI_SHORT_NAME);
    }

    return Plugin_Continue;
}
