#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define SHORT_NAME_I "id"
#define SHORT_NAME_T "id_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: ID"

ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cIPrice = null;
ConVar g_cILimit = null;
ConVar g_cTPrio = null;
ConVar g_cIPrio = null;
ConVar g_cLongNameT = null;
ConVar g_cLongNameI = null;
ConVar g_cCooldown = null;
ConVar g_cCountI = null;
ConVar g_cCountT = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

enum struct PlayerData {
    float Cooldown;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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

    TTT_StartConfig("id");
    CreateConVar("ttt2_id_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongNameI = AutoExecConfig_CreateConVar("id_name_innocent", "ID", "The name of this in Innocent Shop");
    g_cLongNameT = AutoExecConfig_CreateConVar("id_name_traitor", "(Fake) ID", "The name of this in Traitor Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("id_traitor_price", "1000", "The amount of credits for fake ID costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("id_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIPrice = AutoExecConfig_CreateConVar("id_innocent_price", "1000", "The amount of credits for ID costs as innocent. 0 to disable.");
    g_cILimit = AutoExecConfig_CreateConVar("id_innocent_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTPrio = AutoExecConfig_CreateConVar("id_traitor_sort_prio", "0", "The sorting priority of the fake ID in the shop menu.");
    g_cIPrio = AutoExecConfig_CreateConVar("id_innocent_sort_prio", "0", "The sorting priority of the ID in the shop menu.");
    g_cCooldown = AutoExecConfig_CreateConVar("id_cooldown_time", "30.0", "The cooldown for the !id command. Set it to 0.0 to disable the cooldown");
    g_cCountI = AutoExecConfig_CreateConVar("id_count_innocent", "1", "How often the item (Id Tag) can be bought per round as an innocent (0 - Disabled).");
    g_cCountT = AutoExecConfig_CreateConVar("id_count_traitor", "1", "How often the item (Id Tag) can be bought per round as a traitor (0 - Disabled).");
    TTT_EndConfig();

    RegConsoleCmd("sm_id", Command_ID, "Prove yourself as Innocent");

    TTT_LoadTranslations();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_I);
    }
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

public Action Command_ID(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_cCooldown.FloatValue > 0.0)
    {
        if (g_iPlayer[client].Cooldown != 0.0 && ((GetEngineTime() - g_iPlayer[client].Cooldown) < g_cCooldown.FloatValue))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Cooldown", client);
            return Plugin_Handled;
        }
        g_iPlayer[client].Cooldown = GetEngineTime();
    }


    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Need to be Alive", client);
        return Plugin_Handled;
    }

    if (!TTT_IsItemInInventory(client, SHORT_NAME_I) && !TTT_IsItemInInventory(client, SHORT_NAME_T))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Need to buy ID", client);
        return Plugin_Handled;
    }

    char sName[MAX_NAME_LENGTH];
    if (!TTT_GetClientName(client, sName, sizeof(sName)))
    {
        return Plugin_Handled;
    }

    LoopValidClients(i)
    {
        CPrintToChat(i, "%s %T", g_sPluginTag, "ID: Shows ID", i, sName);
    }

    return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
    ResetID(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetID(client);
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongNameT.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cCountT.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    
    g_cLongNameI.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_I, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cCountI.IntValue, g_cILimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    CPrintToChat(client, "%s %T", g_sPluginTag, "ID: Buy Message", client);
    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

void ResetID(int client)
{
    g_iPlayer[client].Cooldown = 0.0;
}
