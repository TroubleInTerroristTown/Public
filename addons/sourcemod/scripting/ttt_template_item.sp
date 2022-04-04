#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Shop Template"
#define SHORT_NAME "template"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cUses = null;
ConVar g_cLimit = null;

/*
ConVar g_cPluginTag = null;
char g_sPluginTag[64];
*/

enum struct PlayerData {
    bool HasItem;
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

    TTT_LoadTranslations();
    
    TTT_StartConfig("template_item");
    CreateConVar("ttt2_template_item_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("template_name", "Template", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("template_price", "9000", "The amount of credits TEMPLATE costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("template_prio", "0", "The sorting priority of the TEMPLATE in the shop menu.");
    g_cUses = AutoExecConfig_CreateConVar("template_uses", "2", "The number of uses of the TEMPLATE in the shop menu.");
    g_cLimit = AutoExecConfig_CreateConVar("template_limit", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
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
    /*        
        If you want the plugin tag from ttt
        
        g_cPluginTag = FindConVar("ttt_plugin_tag");
        g_cPluginTag.AddChangeHook(OnConVarChanged);
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
        CPrintToChat(client, "%s %T", g_sPluginTag, "Translation Name");
    */
    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cUses.IntValue, g_cLimit.IntValue, OnPurchase);
}

/* public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
} */

public void OnClientDisconnect(int client)
{
    ResetTemplate(client);
}

public Action OnPurchase(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientRole(client);

    if (role != TTT_TEAM_DETECTIVE)
    {
        return Plugin_Stop;
    }

    if (g_iPlayer[client].HasItem)
    {
        return Plugin_Stop;
    }

    g_iPlayer[client].HasItem = true;

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetTemplate(client);
    }

    return Plugin_Continue;
}

void ResetTemplate(int client)
{
    g_iPlayer[client].HasItem = false;
}
