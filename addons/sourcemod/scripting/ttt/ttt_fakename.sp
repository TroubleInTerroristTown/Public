#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Fake Name"
#define SHORT_NAME "fakename_t"
#define SHORT_NAME_INVI "invisName_t"

/* ConVars of fakename */
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;
ConVar g_cTimer = null;
ConVar g_cLongName = null;
ConVar g_cIgnoreRole = null;

/* ConVars of invisible name */
ConVar g_cInviPrice = null;
ConVar g_cInviPrio = null;
ConVar g_cInviCount = null;
ConVar g_cInviLimit = null;
ConVar g_cInviTimer = null;
ConVar g_cInviLongName = null;

ConVar g_cActivation = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

enum struct PlayerData {
    Handle FakeTimer;
    Handle InviTimer;

    char FakeName[MAX_NAME_LENGTH];
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
    
    TTT_StartConfig("fakename");
    CreateConVar("fakename_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("fakename_name", "Fake Name", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("fakename_price", "5000", "The amount of credits fakename costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("fakename_sort_prio", "0", "The sorting priority of the fakename in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("fakename_count", "5", "The number of fakename that the player can use in a round");
    g_cLimit = AutoExecConfig_CreateConVar("fakename_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTimer = AutoExecConfig_CreateConVar("fakename_timer", "15.0", "The time the target should be renamed");
    g_cIgnoreRole = AutoExecConfig_CreateConVar("fakename_ignore_role", "4", "Which role should be ignored when traitor use fakename? -1 - Disabled ( https://github.com/Bara/TroubleinTerroristTown/wiki/CVAR-Masks )", _, true, 2.0);

    g_cInviLongName = AutoExecConfig_CreateConVar("invisible_name_name", "Invisible Name", "The name of this in Shop");
    g_cInviPrice = AutoExecConfig_CreateConVar("invisible_name_price", "5000", "The amount of credits invisiblename costs as traitor. 0 to disable.");
    g_cInviPrio = AutoExecConfig_CreateConVar("invisible_name_sort_prio", "0", "The sorting priority of the invisiblename in the shop menu.");
    g_cInviCount = AutoExecConfig_CreateConVar("invisible_name_count", "5", "The number of invisiblename that the player can use in a round");
    g_cInviLimit = AutoExecConfig_CreateConVar("invisible_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cInviTimer = AutoExecConfig_CreateConVar("invisible_name_timer", "15.0", "The time the target should have a invisible name");

    g_cActivation = AutoExecConfig_CreateConVar("fake_invisible_name_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_Player);
    HookEvent("player_death", Event_Player);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
        TTT_RemoveShopItem(SHORT_NAME_INVI);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    CheckPlayerID();

    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    TTT_OnShopReady();
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
    char sName[128];
    g_cLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);

    g_cInviLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterShopItem(SHORT_NAME_INVI, sName, g_cInviPrice.IntValue, TTT_TEAM_TRAITOR, g_cInviPrio.IntValue, g_cInviCount.IntValue, g_cInviLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (StrEqual(itemshort, SHORT_NAME, false))
    {
        if (!CheckPlayerID())
        {
            return Plugin_Stop;
        }

        int role = TTT_GetClientRole(client);

        char sName[128];
        g_cLongName.GetString(sName, sizeof(sName));
        
        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        if (g_cActivation.IntValue == 0)
        {
            TTT_AddInventoryItem(client, SHORT_NAME);
        }
        else if (g_cActivation.IntValue == 1)
        {
            TTT_AddItemUsage(client, SHORT_NAME);
            Start_Fakename(client);
        }
    }
    else if (StrEqual(itemshort, SHORT_NAME_INVI, false))
    {
        if (!CheckPlayerID())
        {
            return Plugin_Stop;
        }

        int role = TTT_GetClientRole(client);

        char sName[128];
        g_cLongName.GetString(sName, sizeof(sName));
        
        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        if (g_cActivation.IntValue == 0)
        {
            TTT_AddInventoryItem(client, SHORT_NAME_INVI);
        }
        else if (g_cActivation.IntValue == 1)
        {
            TTT_AddItemUsage(client, SHORT_NAME_INVI);
            Start_Invisiblename(client);
        }
    }

    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client))
    {
        if (StrEqual(itemshort, SHORT_NAME) && TTT_IsItemInInventory(client, SHORT_NAME))
        {
            TTT_RemoveInventoryItem(client, SHORT_NAME);
            TTT_AddItemUsage(client, SHORT_NAME);

            Start_Fakename(client);
        }
        else if (StrEqual(itemshort, SHORT_NAME_INVI) && TTT_IsItemInInventory(client, SHORT_NAME_INVI))
        {
            TTT_RemoveInventoryItem(client, SHORT_NAME_INVI);
            TTT_AddItemUsage(client, SHORT_NAME_INVI);

            Start_Invisiblename(client);
        }
    }
}

void Start_Fakename(int client)
{
    if (g_iPlayer[client].FakeTimer != null || g_iPlayer[client].InviTimer != null)
    {
        return;
    }
    
    int iTarget = TTT_GetRandomPlayer(false, g_cIgnoreRole.IntValue);

    while (iTarget == client)
    {
        iTarget = TTT_GetRandomPlayer(false, g_cIgnoreRole.IntValue);
    }

    if (!TTT_IsClientValid(iTarget))
    {
        return;
    }

    if (!GetClientName(iTarget, g_iPlayer[client].FakeName, sizeof(PlayerData::FakeName)))
    {
        return;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Fake Name: New Name", client, g_cTimer.FloatValue, g_iPlayer[client].FakeName);
    
    g_iPlayer[client].FakeTimer = CreateTimer(g_cTimer.FloatValue, Timer_ResetName, GetClientUserId(client));
}

void Start_Invisiblename(int client)
{
    if (g_iPlayer[client].FakeTimer != null || g_iPlayer[client].InviTimer != null)
    {
        return;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Invisible Name: Start", client, g_cTimer.FloatValue);

    g_iPlayer[client].InviTimer = CreateTimer(g_cInviTimer.FloatValue, Timer_ResetInvi, GetClientUserId(client));
}

public Action Timer_ResetName(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].FakeTimer = null;
        Format(g_iPlayer[client].FakeName, sizeof(PlayerData::FakeName), "");
        CPrintToChat(client, "%s %T", g_sPluginTag, "Fake Name: Name expired", client);
    }

    return Plugin_Stop;
}

public Action Timer_ResetInvi(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].InviTimer = null;
        CPrintToChat(client, "%s %T", g_sPluginTag, "Invisible Name: Stop", client);
    }

    return Plugin_Stop;
}

public Action TTT_OnHudSend_Pre(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int &iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength)
{
    if (g_iPlayer[target].FakeTimer != null && strlen(g_iPlayer[target].FakeName) > 1)
    {
        iPlayerNameLength = sizeof(PlayerData::FakeName);
        Format(sPlayerName, iPlayerNameLength, g_iPlayer[target].FakeName);
    }

    if (g_iPlayer[target].InviTimer)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Event_Player(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetFakename(client);
        ResetInvisible(client);
    }
}

void ResetFakename(int client)
{
    if (g_iPlayer[client].FakeTimer != null)
    {
        KillTimer(g_iPlayer[client].FakeTimer);
    }

    g_iPlayer[client].FakeTimer = null;
    Format(g_iPlayer[client].FakeName, sizeof(PlayerData::FakeName), "");
}


void ResetInvisible(int client)
{
    if (g_iPlayer[client].InviTimer != null)
    {
        KillTimer(g_iPlayer[client].InviTimer);
    }

    g_iPlayer[client].InviTimer = null;
}

bool CheckPlayerID()
{
    ConVar cvar = FindConVar("mp_playerid");

    if (cvar == null)
    {
        return false;
    }

    if (cvar.IntValue == 2)
    {
        return true;
    }

    LogError("Fake Name and Invisible Name requires \"mp_playerid 2\". Both items has been unloaded!");
    TTT_RemoveShopItem(SHORT_NAME);
    TTT_RemoveShopItem(SHORT_NAME_INVI);

    return false;
}
