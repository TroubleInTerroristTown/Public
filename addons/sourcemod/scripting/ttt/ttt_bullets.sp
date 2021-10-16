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

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Bullets (Fire, Freeze, Poison)"
#define SHORT_NAME_ICE "bullets_ice"
#define SHORT_NAME_FIRE "bullets_fire"
#define SHORT_NAME_POISON "bullets_poison"

/* ConVars of the plugin */
ConVar g_cIcePrice = null;
ConVar g_cIcePrio = null;
ConVar g_cIceNb = null;
ConVar g_cIceLimit = null;
ConVar g_cIceTimer = null;
ConVar g_cFirePrice = null;
ConVar g_cFirePrio = null;
ConVar g_cFireNb = null;
ConVar g_cFireLimit = null;
ConVar g_cFireTimer = null;
ConVar g_cPoisonPrice = null;
ConVar g_cPoisonPrio = null;
ConVar g_cPoisonNb = null;
ConVar g_cPoisonLimit = null;
ConVar g_cPoisonTimer = null;
ConVar g_cPoisonDmg = null;
ConVar g_cIceLongName = null;
ConVar g_cFireLongName = null;
ConVar g_cPoisonLongName = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH];

enum struct PlayerData {
    int PoisonTimer;

    int DefaultRed;
    int DefaultGreen;
    int DefaultBlue;
    int DefaultAlpha;
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
    
    TTT_StartConfig("bullets");
    CreateConVar("bullets_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cIceLongName = AutoExecConfig_CreateConVar("bullets_ice", "Bullets (Ice)", "The name of this in Shop");
    g_cFireLongName = AutoExecConfig_CreateConVar("bullets_fire", "Bullets (Fire)", "The name of this in Shop");
    g_cPoisonLongName = AutoExecConfig_CreateConVar("bullets_poison", "Bullets (Poison)", "The name of this in Shop");	
    g_cIcePrice = AutoExecConfig_CreateConVar("bullets_ice_price", "5000", "The amount of credits ice bullets costs as traitor. 0 to disable.");
    g_cIcePrio = AutoExecConfig_CreateConVar("bullets_ice_sort_prio", "0", "The sorting priority of the ice bullets in the shop menu.");
    g_cIceNb = AutoExecConfig_CreateConVar("bullets_ice_number", "5", "The number of ice bullets that the player can use");
    g_cIceLimit = AutoExecConfig_CreateConVar("bullets_ice_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIceTimer = AutoExecConfig_CreateConVar("bullets_ice_timer", "2.0", "The time the target should be frozen");		
    g_cFirePrice = AutoExecConfig_CreateConVar("bullets_fire_price", "5000", "The amount of credits fire bullets costs as traitor. 0 to disable.");
    g_cFirePrio = AutoExecConfig_CreateConVar("bullets_fire_sort_prio", "0", "The sorting priority of the fire bullets in the shop menu.");
    g_cFireNb = AutoExecConfig_CreateConVar("bullets_fire_number", "5", "The number of fire bullets that the player can use per time");	
    g_cFireTimer = AutoExecConfig_CreateConVar("bullets_fire_timer", "2.0", "The time the target should be burned");
    g_cFireLimit = AutoExecConfig_CreateConVar("bullets_fire_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPoisonPrice = AutoExecConfig_CreateConVar("bullets_poison_price", "5000", "The amount of credits poison bullets costs as traitor. 0 to disable.");
    g_cPoisonPrio = AutoExecConfig_CreateConVar("bullets_poison_sort_prio", "0", "The sorting priority of the poison bullets in the shop menu.");
    g_cPoisonNb = AutoExecConfig_CreateConVar("bullets_poison_number", "5", "The number of poison bullets that the player can use per time");
    g_cPoisonLimit = AutoExecConfig_CreateConVar("bullets_poison_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPoisonTimer = AutoExecConfig_CreateConVar("bullets_poison_timer", "2", "The number of time the target should be poisened");
    g_cPoisonDmg = AutoExecConfig_CreateConVar("bullets_poison_dmg", "5", "The damage the target should receive per time");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
    
    LoopValidClients(i)
    {
        SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);

        if (IsPlayerAlive(i))
        {
            GetEntityRenderColor(i, g_iPlayer[i].DefaultRed, g_iPlayer[i].DefaultGreen, g_iPlayer[i].DefaultBlue, g_iPlayer[i].DefaultAlpha);
        }
    }
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_ICE);
        TTT_RemoveShopItem(SHORT_NAME_FIRE);
        TTT_RemoveShopItem(SHORT_NAME_POISON);
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
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void TTT_OnShopReady()
{
    char sName[128];

    g_cIceLongName.GetString(sName, sizeof(sName));	
    TTT_RegisterShopItem(SHORT_NAME_ICE, sName, g_cIcePrice.IntValue, TTT_TEAM_TRAITOR, g_cIcePrio.IntValue, g_cIceNb.IntValue, g_cIceLimit.IntValue, OnItemPurchased);

    g_cFireLongName.GetString(sName, sizeof(sName));		
    TTT_RegisterShopItem(SHORT_NAME_FIRE, sName, g_cFirePrice.IntValue, TTT_TEAM_TRAITOR, g_cFirePrio.IntValue, g_cFireNb.IntValue, g_cFireLimit.IntValue, OnItemPurchased);

    g_cPoisonLongName.GetString(sName, sizeof(sName));		
    TTT_RegisterShopItem(SHORT_NAME_POISON, sName, g_cPoisonPrice.IntValue, TTT_TEAM_TRAITOR, g_cPoisonPrio.IntValue, g_cPoisonNb.IntValue, g_cPoisonLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (StrEqual(itemshort, SHORT_NAME_ICE, false))
    {
        int role = TTT_GetClientRole(client);

        char sName[128];
        g_cIceLongName.GetString(sName, sizeof(sName));
        
        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        else if (HasBullets(client))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Have already", client);
            return Plugin_Stop;
        }

        CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Buy bullets", client, g_cIceNb.IntValue, sName);
        TTT_AddInventoryItem(client, SHORT_NAME_ICE, g_cIceNb.IntValue);
    } 
    else if (StrEqual(itemshort, SHORT_NAME_FIRE, false))
    {
        int role = TTT_GetClientRole(client);
        char sName[128];
        g_cFireLongName.GetString(sName, sizeof(sName));
        
        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        else if (HasBullets(client))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Have already", client);
            return Plugin_Stop;
        }		

        CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Buy bullets", client, g_cFireNb.IntValue, sName);
        TTT_AddInventoryItem(client, SHORT_NAME_FIRE, g_cFireNb.IntValue);
    } 
    else if (StrEqual(itemshort, SHORT_NAME_POISON, false))
    {
        int role = TTT_GetClientRole(client);
        char sName[128];
        g_cPoisonLongName.GetString(sName, sizeof(sName));			
        
        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        else if (HasBullets(client))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Have already", client);
            return Plugin_Stop;
        }			

        CPrintToChat(client, "%s %T", g_sPluginTag, "Bullets: Buy bullets", client, g_cPoisonNb.IntValue, sName);
        TTT_AddInventoryItem(client, SHORT_NAME_POISON, g_cPoisonNb.IntValue);
    }

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetBullets(client);
        GetEntityRenderColor(client, g_iPlayer[client].DefaultRed, g_iPlayer[client].DefaultGreen, g_iPlayer[client].DefaultBlue, g_iPlayer[client].DefaultAlpha);
    }
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3])
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }
    
    if (iWeapon == -1 || !IsValidEntity(iWeapon))
    {
        return Plugin_Continue;
    }

    char sWeapon[32];
    GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));

    if (!IsValidWeapon(sWeapon))
    {
        return Plugin_Continue;
    }

    if (TTT_IsItemInInventory(iAttacker, SHORT_NAME_ICE))
    {
        char sName[128];	
        g_cIceLongName.GetString(sName, sizeof(sName));

        TTT_RemoveInventoryItem(iAttacker, SHORT_NAME_ICE);
        TTT_AddItemUsage(iAttacker, SHORT_NAME_ICE);

        CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "Bullets: Number bullets", iAttacker, sName, TTT_GetClientItemQuantity(iAttacker, SHORT_NAME_ICE), g_cIceNb.IntValue);			

        SetEntityMoveType(iVictim, MOVETYPE_NONE);

        SetEntityRenderMode(iVictim, RENDER_TRANSCOLOR);
        SetEntityRenderColor(iVictim, 55, 77, 99, 255);

        CreateTimer(g_cIceTimer.FloatValue, Timer_Ice, GetClientUserId(iVictim));
    }
    else if (TTT_IsItemInInventory(iAttacker, SHORT_NAME_FIRE))
    {
        char sName[128];	
        g_cFireLongName.GetString(sName, sizeof(sName));					
        
        TTT_RemoveInventoryItem(iAttacker, SHORT_NAME_FIRE);
        TTT_AddItemUsage(iAttacker, SHORT_NAME_FIRE);

        CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "Bullets: Number bullets", iAttacker, sName, TTT_GetClientItemQuantity(iAttacker, SHORT_NAME_FIRE), g_cFireNb.IntValue);
        
        IgniteEntity(iVictim, g_cFireTimer.FloatValue);
    }
    else if (TTT_IsItemInInventory(iAttacker, SHORT_NAME_POISON))
    {
        char sName[128];	
        g_cPoisonLongName.GetString(sName, sizeof(sName));			
        
        TTT_RemoveInventoryItem(iAttacker, SHORT_NAME_POISON);
        TTT_AddItemUsage(iAttacker, SHORT_NAME_POISON);

        CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "Bullets: Number bullets", iAttacker, sName, TTT_GetClientItemQuantity(iAttacker, SHORT_NAME_POISON), g_cPoisonNb.IntValue);

        
        CreateTimer(1.0, Timer_Poison, GetClientUserId(iVictim), TIMER_REPEAT); 
    }			
    return Plugin_Continue;	
}

public Action Timer_Ice(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        if (IsPlayerAlive(client))
        {
            SetEntityMoveType(client, MOVETYPE_WALK);
            
            SetEntityRenderColor(client, g_iPlayer[client].DefaultRed, g_iPlayer[client].DefaultGreen, g_iPlayer[client].DefaultBlue, g_iPlayer[client].DefaultAlpha);
            SetEntityRenderMode(client, RENDER_NORMAL);
        }
    }
    return Plugin_Handled;
}

public Action Timer_Poison(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    Action result = Plugin_Stop;
    
    if (TTT_IsClientValid(client))
    {
        if (IsPlayerAlive(client))
        {
            if (g_iPlayer[client].PoisonTimer <= g_cPoisonTimer.IntValue)
            {
                int iHealth = GetClientHealth(client) - g_cPoisonDmg.IntValue;


                if (iHealth <= 0)
                {
                    ForcePlayerSuicide(client);
                    g_iPlayer[client].PoisonTimer = 0;	
                }
                else
                {
                    SetEntityHealth(client, iHealth);

                    SetEntityRenderMode(client, RENDER_TRANSCOLOR);
                    SetEntityRenderColor(client, 0, 255, 20, 255);

                    g_iPlayer[client].PoisonTimer++;
                    result = Plugin_Continue;
                }
            }
            else
            {
                g_iPlayer[client].PoisonTimer = 0;

                SetEntityRenderColor(client, g_iPlayer[client].DefaultRed, g_iPlayer[client].DefaultGreen, g_iPlayer[client].DefaultBlue, g_iPlayer[client].DefaultAlpha);
                SetEntityRenderMode(client, RENDER_NORMAL);
            }
        }	
    }	
    return result;
}

void ResetBullets(int client)
{
    g_iPlayer[client].PoisonTimer = 0;
}

bool HasBullets(int client)
{
    bool result = false;

    if (TTT_IsItemInInventory(client, SHORT_NAME_ICE) || TTT_IsItemInInventory(client, SHORT_NAME_FIRE) || TTT_IsItemInInventory(client, SHORT_NAME_POISON))
    {
        result = true;
    }

    return result;
}

bool IsValidWeapon(const char[] weapon)
{
    bool result = true;

    if (
        StrContains(weapon, "nade") != -1 
        || StrContains(weapon, "knife") != -1 
        || StrContains(weapon, "healthshot") != -1 
        || StrContains(weapon, "molotov") != -1  
        || StrContains(weapon, "decoy") != -1
        || StrContains(weapon, "c4") != -1
        || StrContains(weapon, "flashbang") != -1
        || StrContains(weapon, "taser") != -1
        )
    {
        result = false;
    }	
    return result;
}