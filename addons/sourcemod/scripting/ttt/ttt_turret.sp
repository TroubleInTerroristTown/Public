#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#undef REQUIRE_PLUGIN
#include <turret_core>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Turret"
#define SHORT_NAME "turret"

ConVar g_cPrice = null;
ConVar g_cLimit = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cKillTurretCount = null;
ConVar g_cCount = null;
ConVar g_cCheckTeam = null;
ConVar g_cActivation = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR ... " & bbs.93x.net",
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_LoadTranslations();
    
    TTT_StartConfig("turret");
    CreateConVar("ttt2_turret_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("turret_name", "Turret", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("turret_price", "9000", "The amount of credits turret costs as traitor. 0 to disable.");
    g_cLimit = AutoExecConfig_CreateConVar("turret_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPrio = AutoExecConfig_CreateConVar("turret_sort_prio", "0", "The sorting priority of the turret in the shop menu.");
    g_cKillTurretCount = AutoExecConfig_CreateConVar("turret_kill_cash_amount", "800", "Kill turret credits ?");
    g_cCount = AutoExecConfig_CreateConVar("turret_count", "1", "Amount of turret purchases per round");
    g_cActivation = AutoExecConfig_CreateConVar("turret_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
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

public void OnAllPluginsLoaded()
{
    g_cCheckTeam = FindConVar("sd_turret_checkteam");
    
    if(g_cCheckTeam != null)
    {
        g_cCheckTeam.SetInt(3);
        g_cCheckTeam.AddChangeHook(OnConVarChange);
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    if(!LibraryExists("turret_core"))
    {
        TTT_RemoveShopItem(SHORT_NAME);
        SetFailState("Can't find turret_core.smx! This file will be provided with TTT.");
        return;
    }

    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientRole(client);
    
    if (role != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }
    
    LoopValidClients(i)
    {
        int iRole = TTT_GetClientRole(i);

        if(iRole == TTT_TEAM_DETECTIVE || iRole == TTT_TEAM_INNOCENT)
        {
            SetTurretCanAttackClient(i, true);
        }
        else
        {
            SetTurretCanAttackClient(i, false);
        }
    }
    
    if (g_cActivation.IntValue == 0)
    {
        TTT_AddInventoryItem(client, SHORT_NAME);
    }
    else if (g_cActivation.IntValue == 1)
    {
        TTT_AddItemUsage(client, SHORT_NAME);
        CreateTurret(client);
    }

    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client) && StrEqual(itemshort, SHORT_NAME))
    {
        if (TTT_IsItemInInventory(client, SHORT_NAME))
        {
            TTT_RemoveInventoryItem(client, SHORT_NAME);
            TTT_AddItemUsage(client, SHORT_NAME);

            CreateTurret(client);
        }
    }
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(convar == g_cCheckTeam)
    {
        g_cCheckTeam.SetInt(3);
    }
}

public void Turret_OnTurretDead(int iOwner,int iAttacker)
{
    TTT_AddClientCredits(iAttacker, g_cKillTurretCount.IntValue);
}
    
public void TTT_OnClientGetRole(int client, int role)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {    
        if(role == TTT_TEAM_DETECTIVE || role == TTT_TEAM_INNOCENT)
        {
            SetTurretCanAttackClient(client,true);
        }
        else
        {
            SetTurretCanAttackClient(client,false);
        }
    }
}
