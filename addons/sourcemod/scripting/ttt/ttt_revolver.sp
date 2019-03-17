#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <multicolors>

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

bool g_bHasRevolver[MAXPLAYERS + 1] = { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();

    TTT_StartConfig("revolver");
    CreateConVar("ttt2_revolver_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cPrice = AutoExecConfig_CreateConVar("revolver_detective_price", "6000", "The price of the revolver");
    g_cName = AutoExecConfig_CreateConVar("revolver_detective_name", "Revolver","The name of the revolver");
    g_cShots = AutoExecConfig_CreateConVar("revolver_detective_shots", "1", "The amount of shots that the revolver should have");
    g_cPrio = AutoExecConfig_CreateConVar("revolver_detective_prio", "100", "The priority off the revolver");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);

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

public void TTT_OnShopReady()
{
    char sName[MAX_ITEM_LENGTH];
    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(ITEM_SHORT, sName, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnClientDisconnect(int client)
{
    ResetRevolver(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetRevolver(client);
    }
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
    if(TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if(StrEqual(itemshort, ITEM_SHORT, false))
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

                g_bHasRevolver[client] = true;
            }
            else
            {
                TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cPrice.IntValue);
            }
        }
    }
    return Plugin_Continue;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(!TTT_IsRoundActive())
    {
        return Plugin_Continue;
    }

    if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if(g_bHasRevolver[iAttacker])
    {
        if(HasPlayerRevolver(iAttacker))
        {
            g_bHasRevolver[iAttacker] = false;

            if(TTT_GetClientRole(iVictim) != TTT_TEAM_TRAITOR)
            {
                ForcePlayerSuicide(iAttacker);

                LoopValidClients(i)
                {
                    CPrintToChat(i, "%s %T", g_sPluginTag, "Revolver: Suicide", i);
                }

                return Plugin_Handled;
            }

            damage = float(GetClientHealth(iVictim) + GetClientArmor(iVictim));
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public bool HasPlayerRevolver(int client)
{
    char sWeapon[32];
    GetClientWeapon(client, sWeapon, sizeof(sWeapon));
    return StrEqual(sWeapon, "weapon_revolver", false);
}  

void ResetRevolver(int client)
{
    g_bHasRevolver[client] = false;
}
