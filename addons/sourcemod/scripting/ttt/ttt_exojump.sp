#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Exojump"
#define SHORT_NAME "exojump"

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
    
    TTT_StartConfig("exojump");
    CreateConVar("ttt2_exojump_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("exojump_name", "Exojump", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("exojump_price", "3000", "The amount of credits exojump costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("exojump_sort_prio", "0", "The sorting priority of the exojump in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("exojump_count", "1", "The amount of usages for exojump per round. 0 to disable.", _, true, 0.0);
    g_cLimit = AutoExecConfig_CreateConVar("exojump_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
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
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, SHOP_ITEM_4ALL, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnClientPutInServer(int client)
{
    ResetExojump(client);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (GetClientExojump(client))
    {
        return Plugin_Stop;
    }

    SetClientExojump(client, true);

    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetExojump(client);
    }
}

void ResetExojump(int client)
{
    SetClientExojump(client, false);
}

bool GetClientExojump(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_passiveItems", 1, 1));
}

bool SetClientExojump(int client, bool status)
{
    SetEntProp(client, Prop_Send, "m_passiveItems", status, 1, 1);
    return GetClientExojump(client);
}
