#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public void OnPluginStart()
{
    RegAdminCmd("sm_dronegun", Command_DroneGun, ADMFLAG_BAN);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (IsValidEntity(attacker))
    {
        char sClass[32];
        GetEntityClassname(attacker, sClass, sizeof(sClass));
        PrintToChatAll("Attacker Class: %s", sClass);

        if (StrEqual(sClass, "env_gunfire", false))
        {
            SetEntProp(attacker, Prop_Send, "m_bHasTarget", false);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public void OnMapStart()
{
    int precache = PrecacheModel("models/props_survival/dronegun/dronegun.mdl", true);

    if (precache == 0) {
        SetFailState("models/props_survival/dronegun/dronegun.mdl not precached !");
        return;
    }
    
    PrecacheModel("models/props_survival/dronegun/dronegun_gib1.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib2.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib3.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib4.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib5.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib6.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib7.mdl", true);
    PrecacheModel("models/props_survival/dronegun/dronegun_gib8.mdl", true);
    
    PrecacheSound("sound/survival/turret_death_01.wav", true);
    PrecacheSound("sound/survival/turret_idle_01.wav", true);
    
    PrecacheSound("sound/survival/turret_takesdamage_01.wav", true);
    PrecacheSound("sound/survival/turret_takesdamage_02.wav", true);
    PrecacheSound("sound/survival/turret_takesdamage_03.wav", true);
    
    PrecacheSound("sound/survival/turret_lostplayer_01.wav", true);
    PrecacheSound("sound/survival/turret_lostplayer_02.wav", true);
    PrecacheSound("sound/survival/turret_lostplayer_03.wav", true);
    
    PrecacheSound("sound/survival/turret_sawplayer_01.wav", true);
}

public Action Command_DroneGun(int client, int args)
{
    if(!IsClientInGame(client))
    {
        return Plugin_Handled;
    }

    float vec[2][3];
    GetClientEyePosition(client, vec[0]);
    GetClientEyeAngles(client, vec[1]);
    
    Handle trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);

    if(!TR_DidHit(trace))
    {
        delete trace;
        return Plugin_Handled;
    }

    TR_GetEndPosition(vec[0], trace);
    delete (trace);
    
    int dronegun = CreateEntityByName("dronegun");
    if(dronegun == -1 || !IsValidEntity(dronegun))
    {
        PrintToServer("dronegun %d", dronegun);
        return Plugin_Handled;
    }
    
    PrintToServer("A dronegun %d", dronegun);
    
    
    vec[0][2] = vec[0][2] + 16.0;
    TeleportEntity(dronegun, vec[0], NULL_VECTOR, NULL_VECTOR);
    SetEntPropEnt(dronegun, Prop_Send, "m_hOwnerEntity", client);
    SetEntProp(dronegun, Prop_Send, "m_iTeamNum", GetClientTeam(client));
    DispatchSpawn(dronegun);
    
    return Plugin_Handled;
}

public bool Filter_ExcludePlayers(int entity, int contentsMask, any data)
{
    return !((entity > 0) && (entity <= MaxClients));
}  