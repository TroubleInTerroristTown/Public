#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <ttt_bodies>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Item: Clothes"

#define SHORT_NAME "clothes"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLimit = null;
ConVar g_cCount = null;
ConVar g_cLongName = null;
ConVar g_cInterval = null;

enum struct PlayerData
{
    bool Identify;
    int Target;
}

PlayerData Player[MAXPLAYERS + 1];

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

    TTT_StartConfig("clothes");
    CreateConVar("ttt2_clothes_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("clothes_name", "Take Clothes", "The name in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("clothes_price", "9000", "The amount of credits that cost this item. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("clothes_prio", "0", "The sorting priority in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("clothes_player_count", "3", "The amount of times the player can buy this item per round.");
    g_cLimit = AutoExecConfig_CreateConVar("clothes_limit", "0", "The amount of purchases for all players during a round. (0 - No Limit)", _, true, 0.0);
    g_cInterval = AutoExecConfig_CreateConVar("clothes_interval", "3", "Time in seconds after identify to take the clothes from the dead player", _, true, 1.0);
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

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased, true);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientRole(client);

    if (role != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    TTT_AddInventoryItem(client, SHORT_NAME);
    
    return Plugin_Continue;
}

public void TTT_OnBodyFound(int client, int victim, int victimRole, int attackerRole, int entityref, bool silentID)
{
    if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR && TTT_IsItemInInventory(client, SHORT_NAME) && !Player[client].Identify)
    {
        Player[client].Identify = true;
        Player[client].Target = entityref;

        CreateTimer(g_cInterval.FloatValue, Timer_Reset, GetClientUserId(client));
    }
}

public Action Timer_Reset(Handle timer, any userid)
{
    int client = GetClientOfUserId(client);

    if (client)
    {
        Player[client].Identify = false;
        Player[client].Target = -1;
    }

    return Plugin_Stop;
}

public int TTT_OnButtonPress(int client, int button)
{
    if (button & IN_USE && Player[client].Identify && Player[client].Target != -1)
    {
        Ragdoll body;
        TTT_GetEntityRefRagdoll(Player[client].Target, body);
        SetEntityModel(client, body.Model);

        Player[client].Identify = false;
        Player[client].Target = -1;

        TTT_RemoveInventoryItem(client, SHORT_NAME);
        TTT_AddItemUsage(client, SHORT_NAME);
    }
}
