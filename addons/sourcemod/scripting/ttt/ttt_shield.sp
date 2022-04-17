#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Shield"

#define SHORT_NAME "shield"
#define SHORT_NAME_D "shield_d"
#define SHORT_NAME_T "shield_t"

ConVar g_cLongName = null;
ConVar g_cTPrice = null;
ConVar g_cTPrio = null;
ConVar g_cTCount = null;
ConVar g_cTLimit = null;
ConVar g_cDPrice = null;
ConVar g_cDPrio = null;
ConVar g_cDCount = null;
ConVar g_cDLimit = null;
ConVar g_cIPrice = null;
ConVar g_cIPrio = null;
ConVar g_cICount = null;
ConVar g_cILimit = null;
ConVar g_cShieldDrop = null;
ConVar g_cShieldRemove = null;

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
    
    TTT_StartConfig("shield");
    CreateConVar("ttt2_shield_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("shield_name", "Shield", "The name of the item in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("shield_traitor_price", "9000", "The amount of credits shield costs as a traitor. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("shield_traitor_sort_prio", "0", "The sorting priority of the shields (Traitor) in the shop menu.");
    g_cTCount = AutoExecConfig_CreateConVar("shield_traitor_count", "1", "The amount of usages for shields per round as a traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("shield_traitor_limit", "0", "The amount of purchases for all traitors during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("shield_detective_price", "9000", "The amount of credits shield costs as a detective. 0 to disable.");
    g_cDPrio = AutoExecConfig_CreateConVar("shield_detective_sort_prio", "0", "The sorting priority of the shields (Detective) in the shop menu.");
    g_cDCount = AutoExecConfig_CreateConVar("shield_detective_count", "1", "The amount of usages for shields per round as a detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("shield_detective_limit", "0", "The amount of purchases for all detectives during a round.", _, true, 0.0);
    g_cIPrice = AutoExecConfig_CreateConVar("shield_innocent_price", "9000", "The amount of credits shield costs as an innocent. 0 to disable.");
    g_cIPrio = AutoExecConfig_CreateConVar("shield_innocent_sort_prio", "0", "The sorting priority of the shields (Innocent) in the shop menu.");
    g_cICount = AutoExecConfig_CreateConVar("shield_innocent_count", "1", "The amount of usages for shields per round as an innocent. 0 to disable.");
    g_cILimit = AutoExecConfig_CreateConVar("shield_innocent_limit", "0", "The amount of purchases for all innocents during a round.", _, true, 0.0);
    g_cShieldDrop = AutoExecConfig_CreateConVar("shield_disable_drop", "1", "Disallow players to drop thier shields.", _, true, 0.0,  true, 1.0);
    g_cShieldRemove = AutoExecConfig_CreateConVar("shield_remove_on_start", "1", "Remove shield on ttt round start?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
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
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cICount.IntValue, g_cILimit.IntValue, OnItemPurchased);
}

public void TTT_OnClientGetRole(int client, int team, int role)
{
    if (!g_cShieldRemove.BoolValue)
    {
        return;
    }

    int iShield = -1;
    int iMax = 0;
    char sClass[32];

    while (iShield == -1)
    {
        iShield = GetPlayerWeaponSlot(client, 11); // 11 - CS_SLOT_BOOST, this is not defined in SM1.10...

        if (iShield == -1)
        {
            iMax++;
        }
        else
        {
            GetEntityClassname(iShield, sClass, sizeof(sClass));

            if (StrContains(sClass, "shield", false) != -1)
            {
                TTT_SafeRemoveWeapon(client, iShield, 11);
                return;
            }
        }

        if (iMax == 2)
        {
            return;
        }
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iShield = TTT_HasClientWeapon(client, "weapon_shield");

    if (iShield > 0 && IsValidEntity(iShield))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Shield: Cannot have two", client);
        return Plugin_Stop;
    }

    EquipPlayerWeapon(client, GivePlayerItem(client, "weapon_shield"));

    TTT_AddItemUsage(client, itemshort);
    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public Action CS_OnCSWeaponDrop(int client, int weapon)
{
    if (!TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return Plugin_Continue;
    }

    char sWeapon[32];
    GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

    if (g_cShieldDrop.BoolValue && StrEqual(sWeapon, "weapon_shield", false))
    {
        return Plugin_Stop;
    }

    return Plugin_Continue;
} 
