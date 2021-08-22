#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colorlib>
#include <emitsoundany>
#include <ttt_shop>
#include <ttt_inventory>
#include <ttt>

#define HEALTH_ITEM_SHORT "healthstation"
#define HURT_ITEM_SHORT "hurtstation"

#define SND_WARNING "resource/warning.wav"

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Health/Hurt Stations"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

ConVar g_cHealthPrice = null;
ConVar g_cHealthLimit = null;
ConVar g_cHealthPrio = null;
ConVar g_cHealthHeal = null;
ConVar g_cHealthCharges = null;
ConVar g_cHurtPrice = null;
ConVar g_cHurtLimit = null;
ConVar g_cHurtPrio = null;
ConVar g_cHurtDamage = null;
ConVar g_cHurtCharges = null;
ConVar g_cMaxHealth = null;
ConVar g_cHurtDistance = null;
ConVar g_cHealthDistance = null;
ConVar g_cHurtTraitors = null;
ConVar g_cHurt = null;
ConVar g_cHealth = null;
ConVar g_cHurtCount = null;
ConVar g_cHealthCount = null;
ConVar g_cActivation = null;
ConVar g_cDistanceHealthTimer = null;
ConVar g_cDistanceHurtTimer = null;

ConVar g_cDebug = null;
ConVar g_cPluginTag = null;
char g_sPluginTag[64];

enum StationType {
    Hurt = 0,
    Health
}

enum struct PlayerData {
    int Charges;
    int Health;

    StationType Type; 

    bool IsActive;
    bool Cooldown;

    Handle Timer;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    TTT_LoadTranslations();

    TTT_StartConfig("stations");
    CreateConVar("ttt2_stations_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cHealthPrice = AutoExecConfig_CreateConVar("health_station_price", "3000", "The price of the Health Station in the shop for detectives. 0 to disable.");
    g_cHealthLimit = AutoExecConfig_CreateConVar("health_station_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cHurtPrice = AutoExecConfig_CreateConVar("hurt_station_price", "0", "The price of the Hurt Station in the shop for traitors. 0 to disable. Recommended is double health price.");
    g_cHurtLimit = AutoExecConfig_CreateConVar("hurt_station_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cHealthPrio = AutoExecConfig_CreateConVar("health_sort_prio", "0", "The sorting priority of the Health Station in the shop menu.");
    g_cHurtPrio = AutoExecConfig_CreateConVar("hurt_sort_prio", "0", "The sorting priority of the Hurt Station in the shop menu.");
    g_cHealthHeal = AutoExecConfig_CreateConVar("health_station_heal", "15", "The amount of health the health station should heal each second.");
    g_cHurtDamage = AutoExecConfig_CreateConVar("hurt_station_damage", "25", "The damage the hurt station should do each second.");
    g_cHealthCharges = AutoExecConfig_CreateConVar("health_station_charges", "10", "The amount of charges that the health station should start off with.");
    g_cHurtCharges = AutoExecConfig_CreateConVar("hurt_station_charges", "15", "The amount of charges that the hurt station should start off with.");
    g_cHealthDistance = AutoExecConfig_CreateConVar("health_station_distance", "200.0", "The distance that the health station should reach.");
    g_cHurtDistance = AutoExecConfig_CreateConVar("hurt_station_distance", "200.0", "The distance that the hurt station should reach.");
    g_cHurtTraitors = AutoExecConfig_CreateConVar("hurt_station_hurt_other_traitors", "0", "Hurt other traitors with a hurtstation?", _, true, 0.0, true, 1.0);
    g_cMaxHealth = AutoExecConfig_CreateConVar("health_station_max_health", "125", "What's the max health for a health station that the player can get?");
    g_cHealth = AutoExecConfig_CreateConVar("health_station_name", "Health Station", "The name of the health station in the menu.");
    g_cHurt = AutoExecConfig_CreateConVar("hurt_station_name", "Hurt Station", "The name of the hurt station in the menu.");
    g_cHurtCount = AutoExecConfig_CreateConVar("hurt_station_count", "1", "How many hurt stations a traitor can buy per round?");
    g_cHealthCount = AutoExecConfig_CreateConVar("health_station_count", "1", "How many health stations a detective can buy per round?");
    g_cActivation = AutoExecConfig_CreateConVar("health_hurt_station_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    g_cDistanceHealthTimer = AutoExecConfig_CreateConVar("heahlth_station_distance_delay", "1.0", "How often should health station effects apply?", _, true, 0.0);
    g_cDistanceHurtTimer = AutoExecConfig_CreateConVar("hurt_station_distance_delay", "2.0", "How often should hurt station effects apply?", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
    
    CreateTimer(5.0, Timer_AddCharge, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(HEALTH_ITEM_SHORT);
        TTT_RemoveShopItem(HURT_ITEM_SHORT);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnMapStart()
{
    PrecacheSoundAny(SND_WARNING, true);
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_debug_mode");

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
    
    g_cHealth.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(HEALTH_ITEM_SHORT, sBuffer, g_cHealthPrice.IntValue, TTT_TEAM_DETECTIVE, g_cHealthPrio.IntValue, g_cHealthCount.IntValue, g_cHealthLimit.IntValue, OnItemPurchased);
    
    g_cHurt.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(HURT_ITEM_SHORT, sBuffer, g_cHurtPrice.IntValue, TTT_TEAM_TRAITOR, g_cHurtPrio.IntValue, g_cHurtCount.IntValue, g_cHurtLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    bool hurt = StrEqual(itemshort, HURT_ITEM_SHORT, false);
    bool health = StrEqual(itemshort, HEALTH_ITEM_SHORT, false);

    if (hurt || health)
    {
        if (health)
        {
            if (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE)
            {
                return Plugin_Stop;
            }

            if (g_cActivation.IntValue == 0)
            {
                TTT_AddInventoryItem(client, HEALTH_ITEM_SHORT);
            }
            else if (g_cActivation.IntValue == 1)
            {
                TTT_AddItemUsage(client, HEALTH_ITEM_SHORT);
                spawnStation(client);
            }
        }
        else if (hurt)
        {
            if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }

            if (g_cActivation.IntValue == 0)
            {
                TTT_AddInventoryItem(client, HURT_ITEM_SHORT);
            }
            else if (g_cActivation.IntValue == 1)
            {
                TTT_AddItemUsage(client, HURT_ITEM_SHORT);
                spawnStation(client);
            }
        }
    }

    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    bool hurt = StrEqual(itemshort, HURT_ITEM_SHORT, false);
    bool health = StrEqual(itemshort, HEALTH_ITEM_SHORT, false);

    if (hurt || health)
    {
        spawnStation(client);
    }
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    cleanupStation();
}

public Action Timer_CheckDistance(Handle timer, any ref)
{
    int iEnt = EntRefToEntIndex(ref);

    if (!IsValidEntity(iEnt))
    {
        return Plugin_Stop;
    }

    int iOwner = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");

    if (!TTT_IsClientValid(iOwner))
    {
        return Plugin_Stop;
    }

    if (g_iPlayer[iOwner].Charges <= 0)
    {
        return Plugin_Stop;
    }

    LoopValidClients(i)
    {
        if (!IsPlayerAlive(i) || !TTT_ClientValidRole(i))
        {
            continue;
        }
    
        checkDistanceFromStation(i, iOwner, iEnt);
    }

    return Plugin_Continue;
}

public Action Timer_AddCharge(Handle timer)
{
    LoopValidClients(i)
    {
        if (!IsPlayerAlive(i))
        {
            continue;
        }
    
        if (g_iPlayer[i].IsActive && g_iPlayer[i].Charges < 9)
        {
            g_iPlayer[i].Charges++;
        }
    }
}

public void OnClientDisconnect(int client)
{
    TTT_ClearTimer(g_iPlayer[client].Timer);
}

public Action Timer_RemoveCooldown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    g_iPlayer[client].Cooldown = false;
    g_iPlayer[client].Timer = null;
    return Plugin_Stop;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    cleanupStation();

    return Plugin_Continue;
}

public Action OnTakeDamageStation(int iStation, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IsValidEntity(iStation) || iStation == INVALID_ENT_REFERENCE || iStation <= MaxClients || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    int iOwner = GetEntProp(iStation, Prop_Send, "m_hOwnerEntity");
    if (!TTT_IsClientValid(iOwner))
    {
        return Plugin_Continue;
    }

    g_iPlayer[iOwner].Health--;

    if (g_iPlayer[iOwner].Health <= 0)
    {
        AcceptEntityInput(iStation, "Kill");
        g_iPlayer[iOwner].IsActive = false;
    }
    return Plugin_Continue;
}

void checkDistanceFromStation(int client, int owner, int entity)
{
    float fClientPos[3];
    float fStationPos[3];
    int iCurrentHealth;
    int iNewHealth;
    char sModelName[PLATFORM_MAX_PATH];

    GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

    if (StrContains(sModelName, "microwave") == -1)
    {
        return;
    }

    GetClientEyePosition(client, fClientPos);
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fStationPos);

    float fDistance;

    if (g_iPlayer[owner].Type == Hurt)
    {
        fDistance = g_cHurtDistance.FloatValue;
    }
    else
    {
        fDistance = g_cHealthDistance.FloatValue;
    }

    if (GetVectorDistance(fClientPos, fStationPos) > fDistance)
    {
        return;
    }

    if (g_iPlayer[client].Cooldown)
    {
        return;
    }

    iCurrentHealth = GetClientHealth(client);

    if (!g_cHurtTraitors.BoolValue && g_iPlayer[owner].Type == Hurt && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
    {
        return;
    }

    if (g_iPlayer[owner].Type == Health && (iCurrentHealth >= g_cMaxHealth.IntValue))
    {
        return;
    }

    if (!g_cDebug.BoolValue && g_iPlayer[owner].Type == Hurt && client == owner)
    {
        return;
    }

    if (g_iPlayer[owner].Charges > 0)
    {
        if (g_iPlayer[owner].Type == Hurt)
        {
            iNewHealth = iCurrentHealth - g_cHurtDamage.IntValue;

            TTT_LogString("-> [%N's death station damaged %N (-%d)]", owner, client, g_cHurtDamage.IntValue);
        }
        else
        {
            iNewHealth = iCurrentHealth + g_cHealthHeal.IntValue;

            TTT_LogString("-> [%N's health station healed %N (+%d)]", owner, client, g_cHurtDamage.IntValue);
        }

        if (iNewHealth >= g_cMaxHealth.IntValue)
        {
            SetEntityHealth(client, g_cMaxHealth.IntValue);
        }
        else if (iNewHealth <= 0)
        {
            ForcePlayerSuicide(client);
        }
        else
        {
            SetEntityHealth(client, iNewHealth);
        }

        if (g_iPlayer[owner].Type == Health)
        {
            char sName[MAX_NAME_LENGTH];
            TTT_GetClientName(owner, sName, sizeof(sName));
            CPrintToChat(client, "%s %T", g_sPluginTag, "Healing From", client, sName);
        }

        EmitSoundToClientAny(client, SND_WARNING);
        g_iPlayer[owner].Charges--;
        g_iPlayer[client].Cooldown = true;
        g_iPlayer[client].Timer = CreateTimer(1.0, Timer_RemoveCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        if (g_iPlayer[owner].Type == Health)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Health Station Out Of Charges", client);
            g_iPlayer[client].Cooldown = true;
            g_iPlayer[client].Timer = CreateTimer(1.0, Timer_RemoveCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

void spawnStation(int client)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    int iStation = CreateEntityByName("prop_physics_multiplayer");
    if (iStation != -1)
    {
        float fClientPos[3];
        GetClientAbsOrigin(client, fClientPos);
        SetEntProp(iStation, Prop_Send, "m_hOwnerEntity", client);
        DispatchKeyValue(iStation, "model", "models/props/cs_office/microwave.mdl");

        if (DispatchSpawn(iStation))
        {
            SDKHook(iStation, SDKHook_OnTakeDamage, OnTakeDamageStation);
            TeleportEntity(iStation, fClientPos, NULL_VECTOR, NULL_VECTOR);

            g_iPlayer[client].Health = 10;
            g_iPlayer[client].IsActive = true;

            if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
            {
                g_iPlayer[client].Charges = g_cHurtCharges.IntValue;
                g_iPlayer[client].Type = Hurt;
                CreateTimer(g_cDistanceHurtTimer.FloatValue, Timer_CheckDistance, EntIndexToEntRef(iStation), TIMER_REPEAT);

                CPrintToChat(client, "%s %T", g_sPluginTag, "Hurt Station Deployed", client);
            }
            else
            {
                g_iPlayer[client].Charges = g_cHealthCharges.IntValue;
                g_iPlayer[client].Type = Health;
                CreateTimer(g_cDistanceHealthTimer.FloatValue, Timer_CheckDistance, EntIndexToEntRef(iStation), TIMER_REPEAT);

                CPrintToChat(client, "%s %T", g_sPluginTag, "Health Station Deployed", client);
            }
        }
    }
}

void cleanupStation()
{
    LoopValidClients(i)
    {
        g_iPlayer[i].Charges = 0;
        g_iPlayer[i].IsActive = false;
        g_iPlayer[i].Cooldown = false;

        TTT_ClearTimer(g_iPlayer[i].Timer);
    }
}
