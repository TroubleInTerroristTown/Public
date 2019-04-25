#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Nightvision"
#define SHORT_NAME "nightvision"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;

bool g_bNightvision[MAXPLAYERS + 1] =  { false, ... };

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
    g_cPrice = AutoExecConfig_CreateConVar("nightvision_price", "0", "The amount of credits nightvisions costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("nightvision_sort_prio", "0", "The sorting priority of the nightvisions in the shop menu.");
    TTT_EndConfig();

    RegConsoleCmd("sm_nvg", Command_NVG);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, SHOP_ITEM_4ALL, g_cPrio.IntValue);
}

public void OnClientDisconnect(int client)
{
    ResetNightvision(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            if (g_bNightvision[client])
            {
                return Plugin_Stop;
            }
            
            g_bNightvision[client] = true;

            // TODO: Add message how to use this
        }
    }
    return Plugin_Continue;
}

public Action Command_NVG(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!g_bNightvision[client])
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
        ResetNightvision(client);
        SetClientNV(client, false);
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetNightvision(client);
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

void ResetNightvision(int client)
{
    g_bNightvision[client] = false;
}
