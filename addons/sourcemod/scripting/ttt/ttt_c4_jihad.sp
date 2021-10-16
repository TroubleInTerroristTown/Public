#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>
#include <emitsoundany>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - C4 & Jihad"
#define SHORT_NAME_C4 "c4"
#define SHORT_NAME_J "jihad"

#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"
#define SND_BEEP "weapons/c4/c4_beep1.wav"
#define SND_DISARM "weapons/c4/c4_disarm.wav"

#define MDL_C4 "models/weapons/w_c4_planted.mdl"

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

ConVar g_cRemoveBomb = null;
ConVar g_cSlayPlayer = null;
ConVar g_cPrice_C4 = null;
ConVar g_cPrio_C4 = null;
ConVar g_cLimit_C4 = null;
ConVar g_cCount_C4 = null;
ConVar g_cC4ShakeRadius = null;
ConVar g_cPrice_J = null;
ConVar g_cPrio_J = null;
ConVar g_cLimit_J = null;
ConVar g_cCount_J = null;
ConVar g_cLongName_C4 = null;
ConVar g_cLongName_J = null;
ConVar g_cJihadPreparingTime = null;
ConVar g_cC4DamageRadius = null;
ConVar g_cC4Magnitude = null;
ConVar g_cC4KillRadius = null;
ConVar g_cJihadDamageRadius = null;
ConVar g_cJihadMagnitude = null;
ConVar g_cC4BeepVolume = null;
ConVar g_cC4ExplodeVolume = null;
ConVar g_cEnableWires = null;
ConVar g_cWireCount = null;
ConVar g_cPlantSeconds = null;
ConVar g_cPunishment = null;
ConVar g_cJihadVolume = null;
ConVar g_cArmingVolume = null;
ConVar g_cC4OwnDamage = null;
ConVar g_cC4TraitorDamage = null;
ConVar g_cJihadTraitorDamage = null;

enum struct PlayerData {
    int Planter;
    int Wire;
    int Punishment;
    int C4;
    bool Detonate;
    bool HasActiveBomb;
    Handle TimerExplosion;
    Handle TimerJihad;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

int g_iPlantSecondsCount;
char g_sPlantSeconds[12][32];

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

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

    TTT_StartConfig("c4_jihad");
    g_cLongName_C4 = AutoExecConfig_CreateConVar("c4_name", "C4", "The name of the C4 in the Shop");
    g_cPrice_C4 = AutoExecConfig_CreateConVar("c4_price", "9000", "The amount of credits a c4 costs as traitor. 0 to disable.");
    g_cPrio_C4 = AutoExecConfig_CreateConVar("c4_sort_prio", "0", "The sorting priority of the C4 in the shop menu.");
    g_cLimit_C4 = AutoExecConfig_CreateConVar("c4_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cCount_C4 = AutoExecConfig_CreateConVar("c4_count", "3", "The amount of c4's a traitor can buy.");
    g_cCount_J = AutoExecConfig_CreateConVar("jihad_count", "3", "The amount of Jihad's a traitor can buy.");
    g_cC4ShakeRadius = AutoExecConfig_CreateConVar("c4_shake_radius", "5000", "The 'shake' radius of the C4 explosion.");
    g_cC4DamageRadius = AutoExecConfig_CreateConVar("c4_damage_radius", "850", "The damage radius of the C4 explosion.");
    g_cLongName_J = AutoExecConfig_CreateConVar("jihad_name", "Jihad Bomb", "The name of the Jihad in the Shop");
    g_cPrice_J = AutoExecConfig_CreateConVar("jihad_price", "9000", "The amount of credits a jihad costs as traitor. 0 to disable.");
    g_cPrio_J = AutoExecConfig_CreateConVar("jihad_sort_prio", "0", "The sorting priority of the Jihad in the shop menu.");
    g_cLimit_J = AutoExecConfig_CreateConVar("jihad_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cJihadPreparingTime = AutoExecConfig_CreateConVar("jihad_preparing_time", "60.0", "The amount of time in seconds until the jihad bomb is ready after buying it. 0.0 - immediately");
    g_cRemoveBomb = AutoExecConfig_CreateConVar("remove_bomb_on_spawn", "1", "Remove the bomb from the map to prevent interference. 1 = Remove, 0 = Don't Remove", _, true, 0.0, true, 1.0);
    g_cJihadDamageRadius = AutoExecConfig_CreateConVar("jihad_damage_radius", "600", "The damage radius of the Jihad explosion.");
    g_cSlayPlayer = AutoExecConfig_CreateConVar("jihad_slay_player", "1", "Slay player on own jihad explosion?", _, true, 0.0, true, 1.0);
    g_cC4Magnitude = AutoExecConfig_CreateConVar("c4_magnitude", "850", "The amount of damage done by the explosion. For C4");
    g_cJihadMagnitude = AutoExecConfig_CreateConVar("jihad_magnitude", "1000", "The amount of damage done by the explosion. For Jihad");
    g_cC4KillRadius = AutoExecConfig_CreateConVar("c4_kill_radius", "275.0", "The kill radius of the C4 explosion.");
    g_cC4BeepVolume = AutoExecConfig_CreateConVar("c4_beep_volume", "0.6", "Volume of c4 beep sound (0.0 - no sound)", _, true, 0.0, true, 1.0);
    g_cC4ExplodeVolume = AutoExecConfig_CreateConVar("c4_explode_volume", "0.75", "Volume of c4 explode sound (0.0 - no sound)", _, true, 0.0, true, 1.0);
    g_cEnableWires = AutoExecConfig_CreateConVar("c4_enable_wires", "1", "Enable wires to defuse c4?", _, true, 0.0, true, 1.0);
    g_cWireCount = AutoExecConfig_CreateConVar("c4_wire_count", "4", "How many wires for defusing?", _, true, 1.0);
    g_cPlantSeconds = AutoExecConfig_CreateConVar("c4_plant_seconds", "20,30,40,50,60", "Plant seconds (Separate numbers with ,)");
    g_cPunishment = AutoExecConfig_CreateConVar("c4_punishment", "0", "Punishment for the player who cut the wrong wire. 0 - Slay player, 1 - (Instant) Bomb explode, 2 - Menu (Players choice)", _, true, 0.0, true, 3.0);
    g_cJihadVolume = AutoExecConfig_CreateConVar("jihad_volume", "0.8", "Sound volume for the jihad \"ALALAA\" sound", _, true, 0.0, true, 1.0);
    g_cArmingVolume = AutoExecConfig_CreateConVar("jihad_arming_volume", "0.8", "Sound volume for the jihad arming sound", _, true, 0.0, true, 1.0);
    g_cC4OwnDamage = AutoExecConfig_CreateConVar("c4_own_damage", "1", "Block damage from own c4", _, true, 0.0, true, 1.0);
    g_cC4TraitorDamage = AutoExecConfig_CreateConVar("c4_traitor_damage", "1", "Block damage for other traitors with c4", _, true, 0.0, true, 1.0);
    g_cJihadTraitorDamage = AutoExecConfig_CreateConVar("jihad_traitor_damage", "1", "Block damage for other traitors with jihad", _, true, 0.0, true, 1.0);
    g_cPlantSeconds.AddChangeHook(OnConVarChanged);
    TTT_EndConfig();
    
    AddCommandListener(Command_LAW, "+lookatweapon");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);

    TTT_LoadTranslations();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_C4);
        TTT_RemoveShopItem(SHORT_NAME_J);
    }
}

public void OnMapStart()
{
    PrecacheSoundAny(SND_BLIP, true);
    PrecacheSoundAny(SND_BURST, true);
    PrecacheSoundAny(SND_BEEP, true);
    PrecacheSoundAny(SND_DISARM, true);

    PrecacheModel("weapons/w_c4_planted.mdl", true);

    PrecacheSoundAny("ttt/jihad/explosion.mp3", true);
    PrecacheSoundAny("ttt/jihad/jihad.mp3", true);

    AddFileToDownloadsTable("sound/ttt/jihad/explosion.mp3");
    AddFileToDownloadsTable("sound/ttt/jihad/jihad.mp3");

    g_iBeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vtf");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnClientDisconnect(int client)
{
    ResetGlobals(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetGlobals(client);
    }
}

public Action Event_PlayerDeath(Event event, const char[] menu, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (TTT_IsClientValid(client))
    {
        ResetJihad(client);
    }
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    char sBuffer[128];
    g_cPlantSeconds.GetString(sBuffer, sizeof(sBuffer));
    g_iPlantSecondsCount = ExplodeString(sBuffer, ",", g_sPlantSeconds, sizeof(g_sPlantSeconds), sizeof(g_sPlantSeconds[]));

    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName_C4.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_C4, sBuffer, g_cPrice_C4.IntValue, TTT_TEAM_TRAITOR, g_cPrio_C4.IntValue, g_cCount_C4.IntValue, g_cLimit_C4.IntValue, OnItemPurchased);
    
    g_cLongName_J.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_J, sBuffer, g_cPrice_J.IntValue, TTT_TEAM_TRAITOR, g_cPrio_J.IntValue, g_cCount_J.IntValue, g_cLimit_J.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
    else if (convar == g_cPlantSeconds)
    {
        g_iPlantSecondsCount = ExplodeString(newValue, ",", g_sPlantSeconds, sizeof(g_sPlantSeconds), sizeof(g_sPlantSeconds[]));
    }
}

public void ResetJihad(int client)
{
    g_iPlayer[client].Detonate = false;
    
    TTT_ClearTimer(g_iPlayer[client].TimerJihad);
}

public void ResetGlobals(int client)
{
    g_iPlayer[client].Detonate = false;
    g_iPlayer[client].HasActiveBomb = false;
    
    g_iPlayer[client].Planter = -1;
    g_iPlayer[client].Wire = -1;
    g_iPlayer[client].C4 = -1;
    
    TTT_ClearTimer(g_iPlayer[client].TimerExplosion);
    TTT_ClearTimer(g_iPlayer[client].TimerJihad);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (StrEqual(itemshort, SHORT_NAME_C4, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_TRAITOR )
        {
            return Plugin_Stop;
        }

        TTT_AddInventoryItem(client, SHORT_NAME_C4);

        CPrintToChat(client, "%s %T", g_sPluginTag, "Right click to plant the C4", client);
    }
    else if (StrEqual(itemshort, SHORT_NAME_J, false))
    {
        int role = TTT_GetClientRole(client);

        if (role != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        TTT_ClearTimer(g_iPlayer[client].TimerJihad);

        if (g_cJihadPreparingTime.FloatValue > 0.0)
        {
            g_iPlayer[client].TimerJihad = CreateTimer(g_cJihadPreparingTime.FloatValue, Timer_JihadPreparing, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

            CPrintToChat(client, "%s %T", g_sPluginTag, "bomb will arm in few seconds, double tab F to explode", client, g_cJihadPreparingTime.IntValue);
        }
        else if(g_cJihadPreparingTime.FloatValue == 0.0)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Your bomb is now armed.", client);
            
            float fPos[3];
            GetClientEyePosition(client, fPos);
            
            EmitAmbientSound(SND_BLIP, fPos, SOUND_FROM_PLAYER, _, _, g_cArmingVolume.FloatValue);
        }
        
        TTT_AddInventoryItem(client, SHORT_NAME_J);
    }

    return Plugin_Continue;
}

public Action Timer_JihadPreparing(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if(!IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Your bomb is now armed.", client);
    
    float fPos[3];
    GetClientEyePosition(client, fPos);
    
    EmitAmbientSound(SND_BLIP, fPos, SOUND_FROM_PLAYER, _, _, g_cArmingVolume.FloatValue);
    g_iPlayer[client].TimerJihad = null;
    return Plugin_Stop;
}


public Action OnTakeDamageAlive(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
    if (TTT_IsClientValid(attacker) && TTT_IsClientValid(victim) && IsValidEntity(inflictor))
    {
        char sClass[32], sName[256];
        GetEntityClassname(inflictor, sClass, sizeof(sClass));
        GetEntPropString(inflictor, Prop_Data, "m_iName", sName, sizeof(sName));

        if (StrEqual(sClass, "env_explosion", false))
        {
            if (StrEqual(sName, "c4", false))
            {
                if (g_cC4OwnDamage.BoolValue && attacker == victim)
                {
                    return Plugin_Handled;
                }
                else if (g_cC4TraitorDamage.BoolValue && attacker != victim && TTT_GetClientRole(victim) == TTT_TEAM_TRAITOR)
                {
                    return Plugin_Handled;
                }
            }
            else if (StrEqual(sName, "jihad", false))
            {
                if (g_cJihadTraitorDamage.BoolValue && attacker != victim && TTT_GetClientRole(victim) == TTT_TEAM_TRAITOR)
                {
                    return Plugin_Handled;
                }
            }
        }
    }

    return Plugin_Continue;
}


public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cRemoveBomb.BoolValue)
    {
        return Plugin_Continue;
    }

    char sItem[32];
    event.GetString("item", sItem, sizeof(sItem));
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        RemoveC4(client);
    }
    return Plugin_Continue;
}

bool RemoveC4(int client)
{
    if (!TTT_IsItemInInventory(client, SHORT_NAME_C4) && !TTT_IsItemInInventory(client, SHORT_NAME_J))
    {
        return TTT_RemoveWeaponByClassname(client, "weapon_c4", CS_SLOT_C4);
    }
    
    return false;
}

void Detonate(int client)
{
    int ExplosionIndex = CreateEntityByName("env_explosion");
    if (ExplosionIndex != -1)
    {
        SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 16384);
        SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", g_cJihadMagnitude.IntValue);
        SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", g_cJihadDamageRadius.IntValue);
        DispatchKeyValue(ExplosionIndex, "targetname", "jihad");

        DispatchSpawn(ExplosionIndex);
        ActivateEntity(ExplosionIndex);

        float playerEyes[3];
        GetClientEyePosition(client, playerEyes);

        TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR);
        SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client);

        EmitAmbientSoundAny("ttt/jihad/explosion.mp3", playerEyes, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN);


        AcceptEntityInput(ExplosionIndex, "Explode");

        AcceptEntityInput(ExplosionIndex, "Kill");
        
        // Slay players
        if (g_cSlayPlayer.BoolValue && IsPlayerAlive(client))
        {
            ForcePlayerSuicide(client);
        }
    }
}

public Action Command_Detonate(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_IsItemInInventory(client, SHORT_NAME_J))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "You dont have it!", client);
        return Plugin_Handled;
    }

    if (g_iPlayer[client].TimerJihad != null)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Your bomb is not armed.", client);
        return Plugin_Handled;
    }

    StartJihad(client);

    return Plugin_Handled;
}

void StartJihad(int client)
{
    float fPos[3];
    GetClientEyePosition(client, fPos);

    if (g_cJihadVolume.FloatValue > 0.0)
    {
        EmitAmbientSoundAny("ttt/jihad/jihad.mp3", fPos, SOUND_FROM_PLAYER, _, _, g_cJihadVolume.FloatValue);
    }

    CreateTimer(2.0, Timer_Detonate, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    TTT_RemoveInventoryItem(client, SHORT_NAME_J);
    TTT_AddItemUsage(client, SHORT_NAME_J);
}

public Action Timer_Detonate(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        Detonate(client);
    }

    return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int argc)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (IsPlayerAlive(client) && TTT_IsItemInInventory(client, SHORT_NAME_J) && g_iPlayer[client].TimerJihad == null && g_iPlayer[client].Detonate)
    {
        StartJihad(client);

        return Plugin_Continue;
    }
    else
    {
        g_iPlayer[client].Detonate = true;
        CreateTimer(2.0, Timer_Reset, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action Timer_Reset(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iPlayer[client].Detonate = false;
    }

    return Plugin_Handled;
}

public Action Timer_ExplodeC4(Handle timer, DataPack pack)
{
    pack.Reset();
    int clientUserId = pack.ReadCell();
    int bombEnt = pack.ReadCell();

    if (!IsValidEntity(bombEnt))
    {
        return Plugin_Stop;
    }

    int client = GetClientOfUserId(clientUserId);
    float explosionOrigin[3];
    GetEntPropVector(bombEnt, Prop_Send, "m_vecOrigin", explosionOrigin);
    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].HasActiveBomb = false;
        g_iPlayer[client].TimerExplosion = null;
        CPrintToChat(client, "%s %T", g_sPluginTag, "Bomb Detonated", client);
    }
    else
    {
        return Plugin_Stop;
    }

    int explosionIndex = CreateEntityByName("env_explosion");
    int particleIndex = CreateEntityByName("info_particle_system");
    int shakeIndex = CreateEntityByName("env_shake");
    if (explosionIndex != -1 && particleIndex != -1 && shakeIndex != -1)
    {
        char sShakeRadius[8];
        IntToString(g_cC4ShakeRadius.IntValue, sShakeRadius, sizeof(sShakeRadius));

        DispatchKeyValue(shakeIndex, "amplitude", "4");
        DispatchKeyValue(shakeIndex, "duration", "1");
        DispatchKeyValue(shakeIndex, "frequency", "2.5");
        DispatchKeyValue(shakeIndex, "radius", sShakeRadius);
        DispatchKeyValue(particleIndex, "effect_name", "explosion_c4_500");
        SetEntProp(explosionIndex, Prop_Data, "m_spawnflags", 16384);
        SetEntProp(explosionIndex, Prop_Data, "m_iRadiusOverride", g_cC4DamageRadius.IntValue);
        SetEntProp(explosionIndex, Prop_Data, "m_iMagnitude", g_cC4Magnitude.IntValue);
        SetEntPropEnt(explosionIndex, Prop_Send, "m_hOwnerEntity", client);
        DispatchKeyValue(explosionIndex, "targetname", "c4");
        DispatchSpawn(particleIndex);
        DispatchSpawn(explosionIndex);
        DispatchSpawn(shakeIndex);
        ActivateEntity(shakeIndex);
        ActivateEntity(particleIndex);
        ActivateEntity(explosionIndex);
        TeleportEntity(particleIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
        TeleportEntity(explosionIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
        TeleportEntity(shakeIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(bombEnt, "Kill");
        g_iPlayer[client].C4 = -1;
        AcceptEntityInput(explosionIndex, "Explode");
        AcceptEntityInput(particleIndex, "Start");
        AcceptEntityInput(shakeIndex, "StartShake");
        AcceptEntityInput(explosionIndex, "Kill");

        LoopValidClients(i)
        {
            if (!IsPlayerAlive(i))
            {
                continue;
            }

            float clientOrigin[3];
            GetEntPropVector(i, Prop_Data, "m_vecOrigin", clientOrigin);

            if (GetVectorDistance(clientOrigin, explosionOrigin) <= g_cC4KillRadius.FloatValue)
            {
                if (g_cC4OwnDamage.BoolValue && client == i)
                {
                    continue;
                }
                else if (g_cC4TraitorDamage.BoolValue && client != i && TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
                {
                    continue;
                }
                
                Event killEvent = CreateEvent("player_death", true);
                killEvent.SetInt("userid", GetClientUserId(i));
                killEvent.SetInt("attacker", GetClientUserId(client));
                killEvent.Fire(false);
                
                ForcePlayerSuicide(i);
            }
        }

        if(g_cC4ExplodeVolume.FloatValue > 0.0)
        {
            EmitAmbientSoundAny(SND_BURST, explosionOrigin, SOUND_FROM_WORLD, SNDLEVEL_RAIDSIREN, _, g_cC4ExplodeVolume.FloatValue);
        }
    }
    
    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
    if (!g_cRemoveBomb.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (buttons & IN_ATTACK && !TTT_IsItemInInventory(client, SHORT_NAME_C4))
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
        if (iWeapon != -1 && IsValidEdict(iWeapon))
        {
            char sWeapon[32];
            GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));

            if (StrContains(sWeapon, "weapon_c4", false) != -1)
            {
                buttons &= ~IN_ATTACK;
                return Plugin_Changed;
            }
        }
    }

    return Plugin_Continue;
}

public int TTT_OnButtonPress(int client, int button)
{
    if (button & IN_ATTACK2 && !g_iPlayer[client].HasActiveBomb && TTT_IsItemInInventory(client, SHORT_NAME_C4))
    {
        g_iPlayer[client].HasActiveBomb = true;
        int bombEnt = CreateEntityByName("prop_physics");
        if (bombEnt != -1 && g_iPlayer[client].C4 == -1)
        {
            float clientPos[3];
            GetClientAbsOrigin(client, clientPos);
            SetEntProp(bombEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
            SetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity", client);
            DispatchKeyValue(bombEnt, "model", MDL_C4);
            DispatchKeyValue(bombEnt, "targetname", "c4_bomb");
            if(DispatchSpawn(bombEnt))
            {
                g_iPlayer[client].C4 = EntIndexToEntRef(bombEnt);
                TeleportEntity(bombEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
                showPlantMenu(client);
            }
        }
    }

    if (button & IN_RELOAD && g_iPlayer[client].Planter == -1 && g_cEnableWires.BoolValue)
    {
        int target = GetClientAimTarget(client, false);

        if (target > 0)
        {
            float clientEyes[3], targetOrigin[3];
            GetClientEyePosition(client, clientEyes);
            GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetOrigin);
            if (GetVectorDistance(clientEyes, targetOrigin) > 100.0)
            {
                return;
            }

            int iEnt;
            while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
            {
                int planter = GetEntProp(target, Prop_Send, "m_hOwnerEntity");

                if (!TTT_IsClientValid(planter))
                {
                    return;
                }

                char sModelPath[PLATFORM_MAX_PATH];
                GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

                if(!StrEqual(MDL_C4, sModelPath))
                {
                    return;
                }

                if (target == iEnt)
                {
                    g_iPlayer[client].Planter = planter;
                    showDefuseMenu(client);
                }
            }
        }
    }
}

void showPlantMenu(int client)
{
    if (!TTT_IsClientValid(client))
    {
        return;
    }

    
    Menu menu = new Menu(plantBombMenu);
    menu.SetTitle("%T", "Set C4 Timer", client);
    
    char sSeconds[64];
    for(int i = 0; i < g_iPlantSecondsCount; i++)
    {
        Format(sSeconds, sizeof(sSeconds), "%T", "Seconds", client, StringToInt(g_sPlantSeconds[i]));
        menu.AddItem(g_sPlantSeconds[i], sSeconds);
    }
    
    menu.Pagination = 6;
    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(client, 10);
}

void showDefuseMenu(int client)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return;
    }

    char sWire[64], sWireInt[12];
    Menu menu = new Menu(defuseBombMenu);
    menu.SetTitle("%T", "Defuse C4", client);

    for (int i = 1; i <= g_cWireCount.IntValue; i++)
    {
        Format(sWire, sizeof(sWire), "%T", "C4 Wire", client, i);
        IntToString(i, sWireInt, sizeof(sWireInt));
        menu.AddItem(sWireInt, sWire);
    }

    menu.Pagination = 4;
    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, 10);
}

public int plantBombMenu(Menu menu, MenuAction action, int client, int option)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return;
    }

    if (action == MenuAction_Select)
    {
        char info[100];
        menu.GetItem(option, info, sizeof(info));
        
        for(int i = 0; i < g_iPlantSecondsCount; i++)
        {
            if (StrEqual(info, g_sPlantSeconds[i]))
            {
                plantBomb(client, StringToFloat(g_sPlantSeconds[i]));
                break;
            }
        }

        if (g_cPunishment.IntValue == 0 || g_cPunishment.IntValue == 1)
        {
            g_iPlayer[client].Punishment = g_cPunishment.IntValue;
        }
        else
        {
            showPlanterPunishments(client);
        }
        
        TTT_RemoveInventoryItem(client, SHORT_NAME_C4);
        TTT_AddItemUsage(client, SHORT_NAME_C4);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        g_iPlayer[client].HasActiveBomb = false;
        removeBomb(client);
    }
    else if (action == MenuAction_Cancel)
    {
        g_iPlayer[client].HasActiveBomb = false;
        removeBomb(client);
    }
}

void showPlanterPunishments(int client)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return;
    }

    char sBuffer[128];

    Menu menu = new Menu(punishmentsBombMenu);
    menu.SetTitle("%T", "C4: Choose Punishment", client);

    Format(sBuffer, sizeof(sBuffer), "%T", "C4: Slay", client);
    menu.AddItem("slay", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "%T", "C4: Explode", client);
    menu.AddItem("explode", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(client, 10);
}

public int punishmentsBombMenu(Menu menu, MenuAction action, int client, int option)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return;
    }

    if (action == MenuAction_Select)
    {
        char info[100];
        menu.GetItem(option, info, sizeof(info));
        
        if (StrEqual(info, "slay", false))
        {
            g_iPlayer[client].Punishment = 0;
        }
        else if (StrEqual(info, "explode", false))
        {
            g_iPlayer[client].Punishment = 1;
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int defuseBombMenu(Menu menu, MenuAction action, int client, int option)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return;
    }

    if (action == MenuAction_Select)
    {
        char info[100];
        int planter = g_iPlayer[client].Planter;
        g_iPlayer[client].Planter = -1;

        if (!TTT_IsClientValid(planter))
        {
            g_iPlayer[client].Planter = -1;
            return;
        }

        int wire;
        int correctWire;
        int iBomb = findBomb(planter);
        float bombPos[3];
        GetEntPropVector(iBomb, Prop_Data, "m_vecOrigin", bombPos);
        correctWire = g_iPlayer[planter].Wire;
        menu.GetItem(option, info, sizeof(info));
        wire = StringToInt(info);
        if (wire == correctWire)
        {
            if (TTT_IsClientValid(planter))
            {
                char sPlanterName[MAX_NAME_LENGTH], sName[MAX_NAME_LENGTH];
                TTT_GetClientName(planter, sPlanterName, sizeof(sPlanterName));
                TTT_GetClientName(client, sName, sizeof(sName));

                CPrintToChat(client, "%s %T", g_sPluginTag, "You Defused Bomb", client, sPlanterName);
                CPrintToChat(planter, "%s %T", g_sPluginTag, "Has Defused Bomb", planter, sName);

                EmitAmbientSoundAny(SND_DISARM, bombPos);

                g_iPlayer[planter].HasActiveBomb = false;
                
                TTT_ClearTimer(g_iPlayer[planter].TimerExplosion);

                SetEntProp(iBomb, Prop_Send, "m_hOwnerEntity", -1);
            }
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Failed Defuse", client);

            if (g_iPlayer[planter].Punishment == 1)
            {
                TriggerTimer(g_iPlayer[planter].TimerExplosion, false);
            }
            else
            {
                ForcePlayerSuicide(client);
            }
            
            g_iPlayer[client].Planter = -1;
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        g_iPlayer[client].Planter = -1;
    }
    else if (action == MenuAction_Cancel)
    {
        g_iPlayer[client].Planter = -1;
    }
}

float plantBomb(int client, float time)
{
    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Alive to Plant", client);
        return;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Will Explode In", client, time);

    bool bombFound;
    int bombEnt;
    while ((bombEnt = FindEntityByClassname(bombEnt, "prop_physics")) != -1)
    {
        if (GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity") != client)
        {
            continue;
        }

        char sModelPath[PLATFORM_MAX_PATH];
        GetEntPropString(bombEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

        if (!StrEqual(MDL_C4, sModelPath))
        {
            continue;
        }

        TTT_ClearTimer(g_iPlayer[client].TimerExplosion);

        DataPack explosionPack;
        g_iPlayer[client].TimerExplosion = CreateDataTimer(time, Timer_ExplodeC4, explosionPack, TIMER_FLAG_NO_MAPCHANGE);
        explosionPack.WriteCell(GetClientUserId(client));
        explosionPack.WriteCell(bombEnt);

        if (g_cC4BeepVolume.FloatValue > 0.0)
        {
            DataPack beepPack;
            CreateDataTimer(1.0, Timer_Beep, beepPack);
            beepPack.WriteCell(bombEnt);
            beepPack.WriteCell((time - 1));
        }

        g_iPlayer[client].HasActiveBomb = true;
        bombFound = true;
    }

    if (!bombFound)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Bomb Was Not Found", client);
    }

    g_iPlayer[client].Wire = GetRandomInt(1, g_cWireCount.IntValue);
    CPrintToChat(client, "%s %T", g_sPluginTag, "Wire Is", client, g_iPlayer[client].Wire);
}

int findBomb(int client)
{
    if (!TTT_IsClientValid(client))
    {
        return -1;
    }

    int iEnt;
    while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
    {
        if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
        {
            continue;
        }

        char sModelPath[PLATFORM_MAX_PATH];
        GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

        if (!StrEqual(MDL_C4, sModelPath))
        {
            continue;
        }

        return iEnt;
    }
    return -1;
}

public Action Timer_Beep(Handle timer, DataPack pack)
{
    int bombEnt;
    int beeps;
    pack.Reset();
    bombEnt = pack.ReadCell();
    beeps = pack.ReadCell();

    if (!IsValidEntity(bombEnt))
    {
        return Plugin_Stop;
    }

    int owner = GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity");
    if (!TTT_IsClientValid(owner))
    {
        return Plugin_Stop;
    }

    float bombPos[3];
    GetEntPropVector(bombEnt, Prop_Data, "m_vecOrigin", bombPos);
    bool stopBeeping = false;
    if (beeps > 0)
    {
        EmitAmbientSoundAny(SND_BEEP, bombPos, _, _, _, g_cC4BeepVolume.FloatValue);
        beeps--;

        int[] clients = new int[MaxClients];
        int index = 0;

        LoopValidClients(j)
        {
            if (TTT_IsPlayerAlive(j) && TTT_GetClientRole(j) == TTT_TEAM_TRAITOR)
            {
                clients[index] = j;
                index++;
            }
        }

        bombPos[2] += 10;

        TE_SetupBeamRingPoint(bombPos, 50.0, 60.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, { 0, 0, 255, 255 }, 10, 0);
        TE_Send(clients, index);

        stopBeeping = false;
    }
    else
    {
        stopBeeping = true;
    }

    if (stopBeeping)
    {
        return Plugin_Stop;
    }

    DataPack bombBeep2 = new DataPack();
    CreateDataTimer(1.0, Timer_Beep, bombBeep2);
    bombBeep2.WriteCell(bombEnt);
    bombBeep2.WriteCell(beeps);
    return Plugin_Stop;
}

void removeBomb(int client)
{
    int iEnt;
    while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
    {
        if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
        {
            continue;
        }

        char sModelPath[PLATFORM_MAX_PATH];
        GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

        if (!StrEqual(MDL_C4, sModelPath))
        {
            continue;
        }

        AcceptEntityInput(iEnt, "Kill");
    }

    int iC4 = EntRefToEntIndex(g_iPlayer[client].C4);

    if (IsValidEntity(iC4))
    {
        AcceptEntityInput(iC4, "Kill");
    }

    g_iPlayer[client].C4 = -1;
}
