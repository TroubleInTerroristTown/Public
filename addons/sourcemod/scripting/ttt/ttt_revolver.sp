#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Revolver"
#define ITEM_SHORT "revolver_d"

public Plugin myinfo = 
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

ConVar g_cPrice = null;
ConVar g_cName = null;
ConVar g_cShots = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();

    TTT_StartConfig("revolver");
    CreateConVar("ttt2_revolver_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cPrice = AutoExecConfig_CreateConVar("revolver_detective_price", "6000", "The price of the 1-shot revolver");
    g_cName = AutoExecConfig_CreateConVar("revolver_detective_name", "1-Shot Revolver","The name of the 1-shot revolver");
    g_cShots = AutoExecConfig_CreateConVar("revolver_detective_shots", "1", "The amount of shots that the 1-shot revolver should have");
    g_cPrio = AutoExecConfig_CreateConVar("revolver_detective_prio", "100", "The priority off the 1-shot revolver");
    g_cCount = AutoExecConfig_CreateConVar("revovler_detective_count", "1", "Amount of revolver purchases per Round as detective. 0 to disable.");
    g_cLimit = AutoExecConfig_CreateConVar("revovler_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(ITEM_SHORT);
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

public void TTT_OnShopReady()
{
    char sName[MAX_ITEM_LENGTH];
    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(ITEM_SHORT, sName, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
    {
        SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
    }
    
    int iRevolver = GivePlayerItem(client, "weapon_revolver");

    if(iRevolver != -1)
    {
        EquipPlayerWeapon(client, iRevolver);
        SetEntProp(iRevolver, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
        SetEntProp(iRevolver, Prop_Send, "m_iClip1", g_cShots.IntValue);

        TTT_AddInventoryItem(client, ITEM_SHORT);
    }
    else
    {
        TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cPrice.IntValue);
    }
    
    return Plugin_Continue;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if(TTT_IsItemInInventory(iAttacker, ITEM_SHORT))
    {
        if(HasPlayerRevolver(iAttacker))
        {
            if(TTT_GetClientRole(iVictim) != TTT_TEAM_TRAITOR)
            {
                ForcePlayerSuicide(iAttacker);

                TTT_RemoveInventoryItem(iAttacker, ITEM_SHORT);

                LoopValidClients(i)
                {
                    CPrintToChat(i, "%s %T", g_sPluginTag, "Revolver: Suicide", i);
                }

                return Plugin_Handled;
            }

            TTT_RemoveInventoryItem(iAttacker, ITEM_SHORT);
            TTT_AddItemUsage(iAttacker, ITEM_SHORT);

            damage = float(GetClientHealth(iVictim) + GetClientArmor(iVictim));
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public bool HasPlayerRevolver(int client)
{
    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (!IsValidEntity(iWeapon))
    {
        return false;
    }

    char sClass[32];
    GetEntityClassname(iWeapon, sClass, sizeof(sClass));

    if (!StrEqual(sClass, "weapon_revolver", false))
    {
        return false;
    }

    if (GetEntProp(iWeapon, Prop_Send, "m_iClip1") > g_cShots.IntValue)
    {
        return false;
    }

    return true;
}  
