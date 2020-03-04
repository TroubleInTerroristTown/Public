#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Respawn"

#define SHORT_NAME "respawn"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cChance = null;
ConVar g_cDelay = null;
ConVar g_cLongName = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

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

    TTT_StartConfig("respawn");
    CreateConVar("ttt2_respawn_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("respawn_traitor_name", "Traitor", "The name of respawn in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("respawn_traitor_price", "9000", "The amount of credits that cost to buy respawn. 0 to disable.");
    g_cChance = AutoExecConfig_CreateConVar("respawn_chance", "20", "Chance in % to respawn");
    g_cDelay = AutoExecConfig_CreateConVar("respawn_delay", "1.0", "Delay after client death and respawn", _, true, 0.1);
    g_cPrio = AutoExecConfig_CreateConVar("respawn_traitor_prio", "0", "The sorting priority of respawn in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("respawn_traitor_count", "1", "The amount of usages for respawn per round as traitor. 0 to disable.");
    g_cLimit = AutoExecConfig_CreateConVar("respawn_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    TTT_LoadTranslations();
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
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    RegisterItem();
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
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
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

public void TTT_OnClientDeath(int victim, int attacker, bool badAction)
{
    if (TTT_IsItemInInventory(victim, SHORT_NAME))
    {
        if (GetRandomInt(1, 100) <= g_cChance.IntValue)
        {
            CPrintToChat(victim, "%s %T", g_sPluginTag, "Respawn: You are back!", victim, g_cChance.FloatValue);
            CreateTimer(g_cDelay.FloatValue, Timer_Respawn, GetClientUserId(victim));
        }
    }
}

public Action Timer_Respawn(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        if (TTT_IsPlayerAlive(client))
        {
            return Plugin_Stop;
        }

        TTT_RespawnPlayer(client);

        TTT_AddItemUsage(client, SHORT_NAME);
        TTT_RemoveInventoryItem(client, SHORT_NAME);
    }

    return Plugin_Stop;
}
