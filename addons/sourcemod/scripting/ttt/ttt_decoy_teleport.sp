#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define SHORT_NAME "decoyteleport"
#define SHORT_NAME_D "decoyteleport_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Decoy Teleporter"

ConVar g_cTPrice = null;
ConVar g_cDPrice = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cTLimit = null;
ConVar g_cDLimit = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cRefund = null;
ConVar g_cLongName = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";


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

    TTT_StartConfig("decoy_teleporter");
    CreateConVar("ttt2_decoy_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("dt_name", "Decoy Teleporter", "The name of the Decoy Teleporter in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("dt_traitor_price", "9000", "The amount of credits for decoy teleporter costs as traitor. 0 to disable.");
    g_cDPrice = AutoExecConfig_CreateConVar("dt_detective_price", "9000", "The amount of credits for decoy teleporter costs as detective. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("dt_traitor_sort_prio", "0", "The sorting priority of the decoy teleporter (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("dt_detective_sort_prio", "0", "The sorting priority of the decoy teleporter (Detective) in the shop menu.");
    g_cTLimit = AutoExecConfig_CreateConVar("dt_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDLimit = AutoExecConfig_CreateConVar("dt_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTCount = AutoExecConfig_CreateConVar("dt_traitor_count", "1", "The amount of usages for decoy teleporters per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("dt_detective_count", "1", "The amount of usages for decoy teleporters per round as detective. 0 to disable.");
    g_cRefund = AutoExecConfig_CreateConVar("dt_refund", "0", "Refund after a fail teleporter? 0 = Disabled/Nothing, 1 = Credits back, 2 = New decoy");
    TTT_EndConfig();

    HookEvent("decoy_started", Event_DecoyStarted, EventHookMode_Pre);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
        TTT_RemoveShopItem(SHORT_NAME_D);
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

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientRole(client);

    if (role == TTT_TEAM_TRAITOR)
    {
        GivePlayerItem(client, "weapon_decoy");

        TTT_AddInventoryItem(client, SHORT_NAME);
        return Plugin_Continue;
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        GivePlayerItem(client, "weapon_decoy");

        TTT_AddInventoryItem(client, SHORT_NAME_D);
        return Plugin_Continue;
    }
    
    
    return Plugin_Stop;
}

public Action Event_DecoyStarted(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        int entity = event.GetInt("entityid");

        if (!TTT_IsItemInInventory(client, SHORT_NAME) || !TTT_IsItemInInventory(client, SHORT_NAME_D))
        {
            return Plugin_Continue;
        }

        float fOldPos[3];
        GetClientAbsOrigin(client, fOldPos);

        float fPos[3];
        fPos[0] = event.GetFloat("x");
        fPos[1] = event.GetFloat("y");
        fPos[2] = event.GetFloat("z");

        TeleportEntity(client, fPos, NULL_VECTOR, NULL_VECTOR);

        bool stuck = StuckClient(client);

        if (stuck)
        {
            TeleportEntity(client, fOldPos, NULL_VECTOR, NULL_VECTOR);
            CPrintToChat(client, "%s %T", g_sPluginTag, "DT: Invalid Position", client);
        }

        AcceptEntityInput(entity, "kill");

        if (stuck && g_cRefund.IntValue == 1)
        {
            int role = TTT_GetClientRole(client);
            if (role == TTT_TEAM_TRAITOR)
            {
                TTT_AddClientCredits(client, g_cTPrice.IntValue);
                TTT_RemoveInventoryItem(client, SHORT_NAME);
                TTT_AddItemUsage(client, SHORT_NAME);
            }
            else if (role == TTT_TEAM_DETECTIVE)
            {
                TTT_AddClientCredits(client, g_cDPrice.IntValue);
                TTT_RemoveInventoryItem(client, SHORT_NAME_D);
                TTT_AddItemUsage(client, SHORT_NAME_D);
            }
        }
        else if (stuck && g_cRefund.IntValue == 2)
        {
            GivePlayerItem(client, "weapon_decoy");
        }
        else
        {
            int role = TTT_GetClientRole(client);
            if (role == TTT_TEAM_TRAITOR)
            {
                TTT_RemoveInventoryItem(client, SHORT_NAME);
                TTT_AddItemUsage(client, SHORT_NAME);
            }
            else if (role == TTT_TEAM_DETECTIVE)
            {
                TTT_RemoveInventoryItem(client, SHORT_NAME_D);
                TTT_AddItemUsage(client, SHORT_NAME_D);
            }
        }

        return Plugin_Handled;
    }
    return Plugin_Continue;
}

bool StuckClient(int client)
{
    float vOrigin[3];
    float vMins[3];
    float vMaxs[3];

    GetClientAbsOrigin(client, vOrigin);
    GetEntPropVector(client, Prop_Send, "m_vecMins", vMins);
    GetEntPropVector(client, Prop_Send, "m_vecMaxs", vMaxs);

    TR_TraceHullFilter(vOrigin, vOrigin, vMins, vMaxs, MASK_ALL, OnlyPlayers, client);

    return TR_DidHit();
}

public bool OnlyPlayers(int entity, int contentsMask, any data)
{
    if (entity != data && entity > 0 && entity <= MaxClients)
    {
        return true;
    }
    return false;
}
