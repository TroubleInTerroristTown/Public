#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Teleporter"
#define SHORT_NAME "teleporter"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLongName = null;
ConVar g_cBlockCrouch = null;
ConVar g_cLimit = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

enum struct PlayerData {
    float Location[3];

    bool Duck;
    bool Teleport;
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
    
    TTT_StartConfig("teleporter");
    CreateConVar("ttt2_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("teleporter_name", "Teleporter", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("teleporter_price", "9000", "The amount of credits Teleporter costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("teleporter_sort_prio", "0", "The sorting priority of the Teleporter in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("teleporter_count", "2", "How often a players can port him back to the location");
    g_cBlockCrouch = AutoExecConfig_CreateConVar("teleporter_block_crouch_save", "0", "Disable position saving while crouching?", _, true, 0.0, true, 1.0);
    g_cLimit = AutoExecConfig_CreateConVar("teleporter_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    RegConsoleCmd("sm_tele", Command_Tele);
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
    
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }
    
    g_iPlayer[client].Duck = view_as<bool>(GetEntProp(client, Prop_Send, "m_bDucked"));

    if (g_cBlockCrouch.BoolValue && g_iPlayer[client].Duck)
    {
        return Plugin_Stop;
    }

    GetClientAbsOrigin(client, g_iPlayer[client].Location);

    CPrintToChat(client, "%s %T", g_sPluginTag, "Location Saved", client);

    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public Action Command_Tele(int client, int args)
{
    if (!TTT_IsClientValid(client) || !TTT_IsItemInInventory(client, SHORT_NAME) || IsNullVector(g_iPlayer[client].Location))
    {
        return Plugin_Handled;
    }
    
    if (g_iPlayer[client].Duck)
    {
        g_iPlayer[client].Teleport = true;
    }
    else
    {
        TeleportEntity(client, g_iPlayer[client].Location, NULL_VECTOR, NULL_VECTOR);
    }

    TTT_AddItemUsage(client, SHORT_NAME);
    TTT_RemoveInventoryItem(client, SHORT_NAME);
    
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (TTT_IsClientValid(client))
    {
        if (g_iPlayer[client].Duck && g_iPlayer[client].Teleport)
        {
            if (!(buttons & IN_DUCK))
			{
				buttons ^= IN_DUCK;
			}
            
            RequestFrame(Frame_Teleport, GetClientUserId(client));
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public void Frame_Teleport(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        TeleportEntity(client, g_iPlayer[client].Location, NULL_VECTOR, NULL_VECTOR);
        RequestFrame(Frame_Reset, userid);
    }
}


public void Frame_Reset(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].Duck = false;
        g_iPlayer[client].Teleport = false;
        g_iPlayer[client].Location = NULL_VECTOR;
    }
}
