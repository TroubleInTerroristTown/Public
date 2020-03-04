#pragma semicolon 1

#include <sourcemod>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Nightvision"
#define SHORT_NAME "nightvision"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
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

    TTT_LoadTranslations();
    
    TTT_StartConfig("nightvision");
    CreateConVar("ttt2_nightvision_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("nightvision_name", "Night Vision", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("nightvision_price", "3000", "The amount of credits nightvisions costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("nightvision_sort_prio", "0", "The sorting priority of the nightvisions in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("nightvision_count", "1", "How often the item (Night Vision) can be bought per round as a detective (0 - Disabled).");
    g_cLimit = AutoExecConfig_CreateConVar("nightvision_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    RegConsoleCmd("sm_nvg", Command_NVG);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
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
    
    CPrintToChat(client, "%s %T", g_sPluginTag, "NightVision: Command Usage");

    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public Action Command_NVG(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_IsItemInInventory(client, SHORT_NAME))
    {
        return Plugin_Handled;
    }

    if (GetClientNV(client))
    {
        SetClientNV(client, false);
    }
    else
    {
        SetClientNV(client, true);
    }
    
    return Plugin_Handled;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        SetClientNV(client, false);
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        SetClientNV(client, false);
    }
}

bool GetClientNV(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_bNightVisionOn"));
}

bool SetClientNV(int client, bool status)
{
    SetEntProp(client, Prop_Send, "m_bNightVisionOn", status);
    return status;
}
