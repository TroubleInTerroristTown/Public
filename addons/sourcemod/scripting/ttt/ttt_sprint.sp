#pragma semicolon 1

#include <sourcemod>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Sprint"
#define SHORT_NAME_D "sprint_d"
#define SHORT_NAME_T "sprint_t"
#define SHORT_NAME_I "sprint_i"

ConVar g_cDebugMessages = null;
ConVar g_cPluginTag = null;
char g_sPluginTag[64];

ConVar g_cPriceD = null;
ConVar g_cLimitD = null;
ConVar g_cPriceT = null;
ConVar g_cLimitT = null;
ConVar g_cPriceI = null;
ConVar g_cLimitI = null;
ConVar g_cPrioD = null;
ConVar g_cPrioT = null;
ConVar g_cPrioI = null;
ConVar g_cNormal = null;
ConVar g_cSpeed = null;
ConVar g_cTime = null;
ConVar g_cCooldown = null;
ConVar g_cLongName = null;
ConVar g_cCountD = null;
ConVar g_cCountT = null;
ConVar g_cCountI = null;

enum struct PlayerData {
    Handle Timer;
    Handle CooldownTimer;
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

    TTT_StartConfig("sprint");
    CreateConVar("ttt2_sprint_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("sprint_name", "Sprint", "The name of this in Shop");
    g_cPriceD = AutoExecConfig_CreateConVar("sprint_price_detective", "9000", "The amount of credits sprint costs as detective. 0 to disable.");
    g_cLimitD = AutoExecConfig_CreateConVar("sprint_limit_detective", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceI = AutoExecConfig_CreateConVar("sprint_price_innocent", "9000", "The amount of credits sprint costs as innocent. 0 to disable.");
    g_cLimitI = AutoExecConfig_CreateConVar("sprint_limit_innocent", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceT = AutoExecConfig_CreateConVar("sprint_price_traitor", "9000", "The amount of credits sprint costs as traitor. 0 to disable.");
    g_cLimitT = AutoExecConfig_CreateConVar("sprint_limit_traitor", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPrioD = AutoExecConfig_CreateConVar("sprint_sort_prio_detective", "0", "The sorting priority of the sprint in the shop menu for detectives.");
    g_cPrioI = AutoExecConfig_CreateConVar("sprint_sort_prio_innocent", "0", "The sorting priority of the sprint in the shop menu for innocents.");
    g_cPrioT = AutoExecConfig_CreateConVar("sprint_sort_prio_traitor", "0", "The sorting priority of the sprint in the shop menu for traitors.");
    g_cNormal = AutoExecConfig_CreateConVar("sprint_normal_speed", "1.0", "Float value of default speed");
    g_cSpeed = AutoExecConfig_CreateConVar("sprint_speed", "1.33", "Float value of sprint speed (X.33 = 33%)");
    g_cTime = AutoExecConfig_CreateConVar("sprint_speed_time", "3.0", "Time in seconds with speed");
    g_cCooldown = AutoExecConfig_CreateConVar("sprint_cooldown_time", "7.0", "Time in seconds until next speed boost");
    g_cCountD = AutoExecConfig_CreateConVar("sprint_count_detective", "1", "Amount of purchases for sprint for detectives per round");
    g_cCountI = AutoExecConfig_CreateConVar("sprint_count_innocent", "1", "Amount of purchases for sprint for innocents per round");
    g_cCountT = AutoExecConfig_CreateConVar("sprint_count_traitor", "1", "Amount of purchases for sprint for traitors per round");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_D);
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_I);
    }
}

public void OnConfigsExecuted()
{
    g_cDebugMessages = FindConVar("ttt_show_debug_messages");

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
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cPriceT.IntValue, TTT_TEAM_DETECTIVE, g_cPrioD.IntValue, g_cCountD.IntValue, g_cLimitT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cPriceD.IntValue, TTT_TEAM_TRAITOR, g_cPrioT.IntValue, g_cCountT.IntValue, g_cLimitD.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_I, sBuffer, g_cPriceI.IntValue, TTT_TEAM_INNOCENT, g_cPrioI.IntValue, g_cCountI.IntValue, g_cLimitI.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnClientDisconnect(int client)
{
    ResetSprint(client);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    CPrintToChat(client, "%s %T", g_sPluginTag, "Sprint available", client);
    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public int TTT_OnButtonPress(int client, int button)
{
    if (!HasSprint(client) || TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }
    
    if (button & IN_USE)
    {
        if (g_iPlayer[client].CooldownTimer != null)
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "Cooldown is active...");
            }
            
            return;
        }
        
        if (g_iPlayer[client].Timer != null)
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "Sprint is active...");
            }
            
            return;
        }
        
        g_iPlayer[client].Timer = CreateTimer(g_cTime.FloatValue, Timer_Sprint, GetClientUserId(client));
        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_cSpeed.FloatValue);
        
        CPrintToChat(client, "%s %T", g_sPluginTag, "Sprint active", client, g_cTime.FloatValue);
    }
}

public Action Timer_Sprint(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if(TTT_IsClientValid(client))
    {
        if (IsPlayerAlive(client))
        {
            SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_cNormal.FloatValue);
            
            CPrintToChat(client, "%s %T", g_sPluginTag, "Sprint cooldown", client, g_cCooldown.FloatValue);
            
            if(g_iPlayer[client].CooldownTimer == null)
            {
                g_iPlayer[client].CooldownTimer = CreateTimer(g_cCooldown.FloatValue, Timer_Cooldown, GetClientUserId(client));
            }
            
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "Sprint over");
            }
        }
        
        g_iPlayer[client].Timer = null;
    }
    
    return Plugin_Stop;
}

public Action Timer_Cooldown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if(TTT_IsClientValid(client))
    {
        g_iPlayer[client].CooldownTimer = null;
        
        CPrintToChat(client, "%s %T", g_sPluginTag, "Sprint available", client);
        
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "Cooldown over");
        }
    }
    
    return Plugin_Stop;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetSprint(client);
    }
}

void ResetSprint(int client)
{
    g_iPlayer[client].Timer = null;
    g_iPlayer[client].CooldownTimer = null;
}

bool HasSprint(int client)
{
    if (TTT_IsItemInInventory(client, SHORT_NAME_D) || TTT_IsItemInInventory(client, SHORT_NAME_T) || TTT_IsItemInInventory(client, SHORT_NAME_I))
    {
        return true;
    }

    return false;
}
