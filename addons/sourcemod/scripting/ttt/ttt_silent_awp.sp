#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Silent AWP"
#define SHORT_NAME_T "silentawp_t"
#define SHORT_NAME_D "silentawp_d"
#define SHORT_NAME_I "silentawp_i"

ConVar g_cPriceT = null;
ConVar g_cLimitT = null;
ConVar g_cPriceD = null;
ConVar g_cLimitD = null;
ConVar g_cPriceI = null;
ConVar g_cLimitI = null;
ConVar g_cPriorityT = null;
ConVar g_cPriorityD = null;
ConVar g_cPriorityI = null;
ConVar g_cMaxShotsT = null;
ConVar g_cMaxShotsD = null;
ConVar g_cMaxShotsI = null;
ConVar g_cMinShotsT = null;
ConVar g_cMinShotsD = null;
ConVar g_cMinShotsI = null;
ConVar g_cAmountT = null;
ConVar g_cAmountD = null;
ConVar g_cAmountI = null;
ConVar g_cLongName = null;

enum struct PlayerData {
    int Weapon;

    bool HasSilencer;
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

    TTT_StartConfig("silent_awp");
    CreateConVar("ttt2_silent_awp_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("silent_awp_name", "Silent AWP", "The name of this in Shop");
    g_cAmountT = AutoExecConfig_CreateConVar("silent_awp_amount_t", "2", "How many AWPs can traitors buy?");
    g_cMinShotsT = AutoExecConfig_CreateConVar("silent_awp_min_t", "1", "Minimum shots for the AWP for Traitors");
    g_cMaxShotsT = AutoExecConfig_CreateConVar("silent_awp_max_t", "2", "Maximum shots for the AWP for Traitors");
    g_cPriorityT = AutoExecConfig_CreateConVar("silent_awp_priority_t", "0", "Priority in shop list for Traitors");
    g_cPriceT = AutoExecConfig_CreateConVar("silent_awp_price_t", "10000", "Price for the silenced AWP for Traitors");
    g_cLimitT = AutoExecConfig_CreateConVar("silent_awp_limit_t", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cAmountD = AutoExecConfig_CreateConVar("silent_awp_amount_d", "0", "How many AWPs can detectives buy?");
    g_cMinShotsD = AutoExecConfig_CreateConVar("silent_awp_min_d", "1", "Minimum shots for the AWP for Detectives");
    g_cMaxShotsD = AutoExecConfig_CreateConVar("silent_awp_max_d", "2", "Maximum shots for the AWP for Detectives");
    g_cPriorityD = AutoExecConfig_CreateConVar("silent_awp_priority_d", "0", "Priority in shop list for Detectives");
    g_cPriceD = AutoExecConfig_CreateConVar("silent_awp_price_d", "0", "Price for the silenced AWP for Detectives");
    g_cLimitD = AutoExecConfig_CreateConVar("silent_awp_limit_d", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceI = AutoExecConfig_CreateConVar("silent_awp_price_i", "0", "Price for the silenced AWP for Innos");
    g_cLimitI = AutoExecConfig_CreateConVar("silent_awp_limit_i", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriorityI = AutoExecConfig_CreateConVar("silent_awp_priority_i", "0", "Priority in shop list for Innos");
    g_cMaxShotsI = AutoExecConfig_CreateConVar("silent_awp_max_i", "2", "Maximum shots for the AWP for Innos");
    g_cMinShotsI = AutoExecConfig_CreateConVar("silent_awp_min_i", "1", "Minimum shots for the AWP for Innos");
    g_cAmountI = AutoExecConfig_CreateConVar("silent_awp_amount_i", "0", "How many AWPs can innocents buy?");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);

    AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);
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
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cPriceT.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT.IntValue, g_cAmountT.IntValue,  g_cLimitT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_I, sBuffer, g_cPriceD.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD.IntValue, g_cAmountD.IntValue,  g_cLimitD.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cPriceI.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI.IntValue, g_cAmountI.IntValue,  g_cLimitI.IntValue, OnItemPurchased);
}

public void OnClientDisconnect(int client)
{
    ResetSilentAWP(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetSilentAWP(client);
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    g_iPlayer[client].Weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

    if (g_iPlayer[client].Weapon != -1)
    {
        char sWeapon[32];
        GetEntityClassname(g_iPlayer[client].Weapon, sWeapon, sizeof(sWeapon));
        if (!StrEqual(sWeapon, "weapon_awp", false))
        {
            TTT_SafeRemoveWeapon(client, g_iPlayer[client].Weapon, CS_SLOT_PRIMARY);
            g_iPlayer[client].Weapon = -1;
        }
    }

    bool bEquip = false;

    if (g_iPlayer[client].Weapon == -1 || !IsValidEntity(g_iPlayer[client].Weapon))
    {
        bEquip = true;
        g_iPlayer[client].Weapon  = GivePlayerItem(client, "weapon_awp");
    }

    int max = 0;
    int min = 0;
    int iRole = TTT_GetClientRole(client);

    if (iRole == TTT_TEAM_TRAITOR)
    {
        max = g_cMaxShotsT.IntValue;
        min = g_cMinShotsT.IntValue;
    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        max = g_cMaxShotsD.IntValue;
        min = g_cMinShotsD.IntValue;
    }
    else if (iRole == TTT_TEAM_INNOCENT)
    {
        max = g_cMaxShotsI.IntValue;
        min = g_cMinShotsI.IntValue;
    }

    int iRand = GetRandomInt(min, max);
    
    SetWeaponClip(g_iPlayer[client].Weapon, iRand);
    SetWeaponAmmo(g_iPlayer[client].Weapon, 0);

    g_iPlayer[client].HasSilencer = true;

    if (bEquip)
    {
        EquipPlayerWeapon(client, g_iPlayer[client].Weapon);
    }

    TTT_AddItemUsage(client, itemshort);
    return Plugin_Continue;
}

public Action Hook_ShotgunShot(const char[] sample, const int[] Players, int numClients, float delay)
{
    int client = TE_ReadNum("m_iPlayer") + 1;

    if(!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (g_iPlayer[client].Weapon == iWeapon)
    {
        char sWeapon[32];
        GetClientWeapon(client, sWeapon, sizeof(sWeapon));
        
        if(StrEqual(sWeapon, "weapon_awp", false) && g_iPlayer[client].HasSilencer)
        {
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

void ResetSilentAWP(int client)
{
    g_iPlayer[client].HasSilencer = false;
    g_iPlayer[client].Weapon = -1;
}

void SetWeaponClip(int weapon, int ammo)
{
    SetEntProp(weapon, Prop_Send, "m_iClip1", ammo);
}

void SetWeaponAmmo(int weapon, int ammo)
{
    SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
}
