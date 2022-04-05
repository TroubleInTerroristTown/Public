#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt_inventory>
#include <ttt>
#include <colorlib>

#define SHORT_NAME "hurtshot_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hurtshot"

ConVar g_cPrice = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cDamage = null;
ConVar g_cName = null;
ConVar g_cLimit = null;

ArrayList g_aListHS = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

enum struct PlayerData {
    bool HasHurtshot;
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
    
    TTT_StartConfig("hurtshot");
    CreateConVar("hurtshot_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cName = AutoExecConfig_CreateConVar("hurtshot_name", "Hurt Shot", "The name of the Hurtshot in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("hurtshot_traitor_price", "5000", "The amount of credits for hurtshots costs as traitor. 0 to disable.");
    g_cCount = AutoExecConfig_CreateConVar("hurtshot_traitor_count", "1", "The amount of usages for hurtshots per round as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("hurtshot_traitor_sort_prio", "0", "The sorting priority of the hurtshots (Traitor) in the shop menu.");
    g_cDamage = AutoExecConfig_CreateConVar("hurtshot_traitor_damage", "50", "The damage of the hurtshot");
    g_cLimit = AutoExecConfig_CreateConVar("hurtshot_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Pre);
    
    g_aListHS = new ArrayList();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
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

    TTT_OnShopReady();
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
    
    return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_aListHS.Clear();
    
    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    char sWeapon[64];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));
    
    if (TTT_IsClientValid(client) && StrContains(sWeapon, "weapon_healthshot", false) != -1)
    {
        if (g_iPlayer[client].HasHurtshot)
        {
            int iHP = GetClientHealth(client) - g_cDamage.IntValue;

            DataPack pack = new DataPack();
            pack.WriteCell(event.GetInt("userid"));
            pack.WriteCell(iHP);

            if (iHP <= 0)
            {
                CreateTimer(2.0, Timer_ChangeHP, pack);
            }
            else
            {
                
                CreateTimer(2.0, Timer_ChangeHP, pack);
            }

            g_iPlayer[client].HasHurtshot = false;

            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

public Action Timer_ChangeHP(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
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

public Action OnWeaponEquip(int client, int weapon)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (!IsValidEntity(weapon))
    {
        return Plugin_Continue;
    }

    int iRef = EntIndexToEntRef(weapon);
    int iIndex = g_aListHS.FindValue(iRef);

    if (iIndex != -1)
    {
        if (IsValidEntity(EntRefToEntIndex(iRef)))
        {
            g_iPlayer[client].HasHurtshot = true;
        }
    }
    
    return Plugin_Handled;
}

public Action OnWeaponDrop(int client, int weapon)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (!IsValidEntity(weapon))
    {
        return Plugin_Continue;
    }

    int iRef = EntIndexToEntRef(weapon);
    int iIndex = g_aListHS.FindValue(iRef);

    if (iIndex != -1)
    {
        if (IsValidEntity(EntRefToEntIndex(iRef)))
        {
            g_iPlayer[client].HasHurtshot = false;
        }
    }
    
    return Plugin_Handled;
}

public void TTT_OnShopReady()
{
    char sName[128];
    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    int iEntity = GivePlayerItem(client, "weapon_healthshot");
    SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

    int iRef = EntIndexToEntRef(iEntity);

    g_aListHS.Push(iRef);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(iRef);
    RequestFrame(Frame_DropEntity, pack);

    TTT_AddItemUsage(client, SHORT_NAME);
    return Plugin_Continue;
}

public void Frame_DropEntity(any pack)
{
    view_as<DataPack>(pack).Reset();
    int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());
    int iEntity = EntRefToEntIndex(view_as<DataPack>(pack).ReadCell());
    delete view_as<DataPack>(pack);

    if (TTT_IsClientValid(client) && IsValidEntity(iEntity))
    {
        CS_DropWeapon(client, iEntity, false, false);
    }
}

void ResetHurtshot(int client)
{
    g_iPlayer[client].HasHurtshot = false;
}