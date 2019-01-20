#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "hurtshot_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hurtshot"

ConVar g_cPrice = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cDamage = null;
ConVar g_cName = null;

int g_iCount[MAXPLAYERS + 1] = { 0, ... };
bool g_bHasHS[MAXPLAYERS + 1] = { false, ... };
ArrayList g_aListHS = null;

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
    
    TTT_StartConfig("hurtshot");
    CreateConVar("hurtshot_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cName = AutoExecConfig_CreateConVar("hurtshot_name", "Hurtshot", "The name of the Hurtshot in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("hurtshot_traitor_price", "5000", "The amount of credits for hurtshots costs as traitor. 0 to disable.");
    g_cCount = AutoExecConfig_CreateConVar("hurtshot_traitor_count", "1", "The amount of usages for hurtshots per round as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("hurtshot_traitor_sort_prio", "0", "The sorting priority of the hurtshots (Traitor) in the shop menu.");
    g_cDamage = AutoExecConfig_CreateConVar("hurtshot_traitor_damage", "50", "The damage of the hurtshot");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("weapon_fire", Event_Fire, EventHookMode_Pre);
    
    g_aListHS = new ArrayList();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
    SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);	
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetHurtshot(client);
    }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_aListHS.Clear();
}

public Action Event_Fire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (TTT_IsClientValid(client) && StrEqual(weapon, "weapon_healthshot"))
    {
        if (g_bHasHS[client] && GetClientHealth(client) < 100)
        {
            DataPack pack = new DataPack();
            int iHP = GetClientHealth(client) - (g_cDamage.IntValue);

            if (iHP <= 0)
            {
                CreateTimer(1.0, Timer_ChangeHP, pack);
            }
            else
            {
                CreateTimer(2.0, Timer_ChangeHP, pack);
            }

            pack.WriteCell(client);
            pack.WriteCell(iHP);

            g_bHasHS[client] = false;

            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon)
{
    if (IsValidEntity(weapon))
    {
        int iRef = EntIndexToEntRef(weapon);
        int iIndex = g_aListHS.FindValue(iRef);
        
        if (iIndex != -1)
        {
            int iArrayRef = g_aListHS.Get(iIndex);
            
            if (TTT_IsClientValid(client) && IsValidEntity(EntRefToEntIndex(iArrayRef) && iRef == iArrayRef))
            {
                g_bHasHS[client] = true;
            }
        }
    }
    
    return Plugin_Handled;
}

public Action OnWeaponDrop(int client, int weapon)
{
    if (IsValidEntity(weapon))
    {
        int iRef = EntIndexToEntRef(weapon);
        int iIndex = g_aListHS.FindValue(iRef);
        
        if (iIndex != -1)
        {
            int iArrayRef = g_aListHS.Get(iIndex);
            
            if (TTT_IsClientValid(client) && IsValidEntity(EntRefToEntIndex(iArrayRef) && iRef == iArrayRef))
            {
                g_bHasHS[client] = false;
            }
        }
    }
    
    return Plugin_Handled;
}

public Action Timer_ChangeHP(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = pack.ReadCell();
    int iHP = pack.ReadCell();
    
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (iHP <= 0)
        {
            ForcePlayerSuicide(client);
        }
        else
        {
            SetEntityHealth(client, iHP);
        }
    }
    delete pack;
    return Plugin_Handled;
}

public void TTT_OnShopReady()
{
    char sName[128];
    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            int role = TTT_GetClientRole(client);
            
            if (role != TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }				

            if (role == TTT_TEAM_TRAITOR && g_iCount[client] >= g_cCount.IntValue)
            {
                char sName[128];
                g_cName.GetString(sName, sizeof(sName));
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sName, g_cCount.IntValue);
                return Plugin_Stop;
            }
            
            int ent = GivePlayerItem(client, "weapon_healthshot");
            g_aListHS.Push(EntIndexToEntRef(ent));
            CS_DropWeapon(client, ent, false, false);

            if (count)
            {
                g_iCount[client]++;
            }
        }
    }
    return Plugin_Continue;
}

void ResetHurtshot(int client)
{
    g_iCount[client] = 0;
    g_bHasHS[client] = false;
}