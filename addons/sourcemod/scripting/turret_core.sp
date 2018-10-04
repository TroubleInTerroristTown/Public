#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <autoexecconfig>
#include <ttt>

int g_iTurrets[MAXPLAYERS+1]= {-1,...};
float g_fDamageTaken[MAXPLAYERS+1]= {0.0,...};
bool g_bCanShoot[MAXPLAYERS+1]= {true,...};
float g_fAim[MAXPLAYERS+1]={0.0,...};
bool g_bTurretAim[MAXPLAYERS+1]= {true,...};
int g_iTurrets_Team[MAXPLAYERS+1]= {-1,...};
bool g_bCanAttack[MAXPLAYERS+1] = {false,...};

int g_iBeam = -1;
int g_iHalo = -1;

Handle g_hOnDead = null;
public Plugin myinfo = 
{
    name = "CS:GO Turret Core",
    author = "Tast - SDC Edited by Kento & e54385991",
    description = "",
    version = "1.0",
    url = "<- URL ->"
}

ConVar g_cEnable = null;
ConVar g_cHealth = null;
ConVar g_cDamage = null;
ConVar g_cRate = null;
ConVar g_cCheckTeam = null;
ConVar g_cDistance = null;

public void OnPluginStart()
{
    //ConVar
    AutoExecConfig_SetFile("csgo_turret");
    g_cEnable = AutoExecConfig_CreateConVar("sd_turret_enable"      , "1", "", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cHealth = AutoExecConfig_CreateConVar("sd_turret_health"    ,     "300.0"        , "Turrent HP",FCVAR_NONE, true, 1.0, true, 30000.0);
    g_cDamage = AutoExecConfig_CreateConVar("sd_turret_damage"    ,     "10"        , "Turrent Damage",FCVAR_NONE);
    g_cRate =   AutoExecConfig_CreateConVar("sd_turret_rate"      , "0.3", "Time Between Turrent Fires", FCVAR_NONE, true, 0.0001, true, 200.0);
    g_cCheckTeam =   AutoExecConfig_CreateConVar("sd_turret_checkteam"      ,  "2", "1 = Check Team T / CT   2 = Any Client not contain yourself  3 = API Mode g_bCanAttack Target", FCVAR_NONE, true, 1.0, true, 3.0);
    g_cDistance = AutoExecConfig_CreateConVar("sd_turret_distance", "300", "Distance between client and turret");
    
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    HookEvent("round_start", Event_RoundStart);
    RegAdminCmd("testturret", CreateTurrettest,ADMFLAG_ROOT);
}



public void OnClientDisconnect(int client)
{
    DestroyTurrets(client);
    ResetPlayerVars(client);
}

public Action CreateTurrettest(int client, int args)
{
    CreateTurret(client);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    InitVars();
}
public void InitVars()
{
    LoopValidClients(i)
    {
        g_iTurrets[i] = -1;
        g_fDamageTaken[i] = 0.0;
        g_bCanShoot[i] = true;
        g_fAim[i] = 0.0;
        g_bTurretAim[i] = true;
        g_bCanAttack[i] = false;
        g_iTurrets_Team[i] = -1;
    }
}

public void ResetPlayerVars(int i)
{
    g_iTurrets[i] = -1;
    g_fDamageTaken[i] = 0.0;
    g_bCanShoot[i] = true;
    g_fAim[i] = 0.0;
    g_bTurretAim[i] = true;
    g_bCanAttack[i] = false;
    g_iTurrets_Team[i] = -1;
}


public void OnMapStart()
{
    PrecacheSound("weapons/sg556/sg556-1.wav");
    PrecacheSound("player/damage1.wav");
    PrecacheSound("player/damage2.wav");
    PrecacheSound("player/damage3.wav");
    g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iHalo = PrecacheModel("materials/sprites/halo.vmt");
    
    PrecacheSound("training/light_on.wav");
    PrecacheSound("training/gallery_stop.wav");
    
    //PrecacheSound("buttons/blip2.wav");
    //-----------------------------------------------------------------------
    
    PrecacheModel("models/Combine_turrets/floor_turret.mdl");
    
    AddFileToDownloadsTable("models/Combine_turrets/floor_turret.mdl");
    AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.dx90.vtx");
    AddFileToDownloadsTable("models/Combine_turrets/floor_turret.mdl");
    AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.phy");
    AddFileToDownloadsTable("models/Combine_turrets/Floor_turret.sw.vtx");
    AddFileToDownloadsTable("models/Combine_turrets/floor_turret.vvd");
    
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002.vmt");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen.vmt");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2.vmt");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4.vmt");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002_mask.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/combine_gun002_normal.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen_glow.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen_noalpha.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen2_noalpha.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4_noalpha.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizen4Normal.vtf");
    AddFileToDownloadsTable("materials/models/Combine_turrets/floor_turret/floor_turret_citizenNormal.vtf");
}

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

void CreateTurret(int client)
{
    
    if(!g_cEnable.BoolValue)
    {
        return;
    }
    
    if(!IsPlayerAlive(client))
    {
        return;
    }
    
    if(g_iTurrets[client] != -1)
    {
        return;
    }
    
    int ent = CreateEntityByName("prop_dynamic_override");
    
    if(ent == -1)
    {
        return;
    }
    
    SetEntityModel(ent, "models/Combine_turrets/floor_turret.mdl");
    DispatchKeyValue(ent, "disablereceiveshadows", "1");
    DispatchKeyValue(ent, "disableshadows", "1");
    DispatchKeyValue(ent, "solid", "6");
    SetEntProp(ent, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
    SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
    
    
    DispatchSpawn(ent);
    ActivateEntity(ent);
    
    SetVariantString("deploy");
    AcceptEntityInput(ent, "SetAnimation", -1, -1, 0);
    
    
    float fPos[3], fAngle[3], fDir[3];
    
    GetClientEyeAngles(client, fAngle);
    GetAngleVectors(fAngle, fDir, NULL_VECTOR, NULL_VECTOR);
    GetClientEyePosition(client, fPos); 
    
    fPos[0] += fDir[0] * 100.0;
    fPos[1] += fDir[1] * 100.0;
    fPos[2] -= 60.0;
    fAngle[0] = 0.0;
    TeleportEntity(ent, fPos, fAngle, NULL_VECTOR);
    
    g_iTurrets[client] = ent;
    g_fDamageTaken[client] = 0.0;
    g_iTurrets_Team[client] = GetClientTeam(client);
    
    if (GetRandomInt(1, 0))
    {
        EmitSoundToAll("training/gallery_stop.wav",ent,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,fPos,NULL_VECTOR,true,0.0);
    }
    else
    {
        EmitSoundToAll("training/light_on.wav",ent,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,fPos,NULL_VECTOR,true,0.0);
    }
    
    
    SDKHook(ent, SDKHook_OnTakeDamage, TurretTakeDamage);
    
    HookSingleEntityOutput(ent, "OnAnimationDone", OnAnimationDone, false);
}

public Action TurretTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if (!TTT_IsClientValid(attacker))
    {
        return Plugin_Continue;
    }
    
    int client = -1;
    
    LoopValidClients(i)
    {
        if (g_iTurrets[i] == victim)
        {
            client = i;
            break;
        }
    }
    
    if (client == -1)
    {
        return Plugin_Continue;
    }
    
    
    if(g_cCheckTeam.IntValue == 1 && client == GetClientTeam(attacker))
    {
        return Plugin_Continue;
    }

    if(g_cCheckTeam.IntValue == 2)
    {
        if(client == attacker) return Plugin_Continue;
    }

    if(g_cCheckTeam.IntValue == 3 && !g_bCanAttack[attacker])
    {
        return Plugin_Continue;
    }
    
    
    g_fDamageTaken[client] += damage;
    
    if (g_fDamageTaken[client] > g_cHealth.FloatValue)
    {
        DestroyTurrets(client);
        Call_StartForward(g_hOnDead);
        Call_PushCell(client);
        Call_PushCell(attacker);
        Call_Finish();
    }
    
    return Plugin_Continue;
}

int GetTurretTeam(int ent)
{
    int iTeam = -1;
    LoopValidClients(i)
    {
        if (g_iTurrets[i] == ent)
        {
            iTeam = g_iTurrets_Team[i];
            break;
        }
    }
    
    return iTeam;
}


int GetTurretOwner(int ent)
{
    
    int iOwner = -1;
    LoopValidClients(i)
    {
        if (g_iTurrets[i] == ent)
        {
            iOwner = i;
            break;
        }
    }
    
    if(!TTT_IsClientValid(iOwner))
    {
        return -1;
    }
    
    return iOwner;
}

public void DestroyTurrets(int client)
{
    if (g_iTurrets[client] != -1 && g_iTurrets[client] > MaxClients && IsValidEdict(g_iTurrets[client]))
    {
        AcceptEntityInput(g_iTurrets[client], "Kill");
    }
    g_iTurrets[client] = -1;
}

public void OnAnimationDone(const char[] output, int caller, int activator, float delay)
{
    if(IsValidEntity(caller))
    {
        SetVariantString("idlealert");
        AcceptEntityInput(caller, "SetAnimation", -1, -1, 0);
    }
}

void TickTurret(int client)
{
    if(!IsValidEntity(g_iTurrets[client]))
    {
        return;
    }

    float TurretPos[3];
    GetEntPropVector(g_iTurrets[client], Prop_Send, "m_vecOrigin", TurretPos);
    int iTeam = GetTurretTeam(g_iTurrets[client]); 
    
    //if(iTeam != GetClientTeam(client)) ..
    LoopValidClients(i)
    {
        if(IsPlayerAlive(i))
        {
            if(g_cCheckTeam.IntValue == 1 && iTeam == GetClientTeam(i))
            {
                continue;
            }
            if(g_cCheckTeam.IntValue == 2)
            {
                int owner = GetTurretOwner(g_iTurrets[client]);
                if(owner != -1 && owner == i) continue;
            }
            
            if(g_cCheckTeam.IntValue == 3 && !g_bCanAttack[i])
            {
                continue;
            }
            
            float EnemyPos[3];
            GetClientEyePosition(i, EnemyPos);

            float fDistance = GetVectorDistance(TurretPos, EnemyPos);

            if (fDistance > g_cDistance.FloatValue)
            {
                continue;
            }

            float m_vecMins[3];
            float m_vecMaxs[3];
            GetEntPropVector(g_iTurrets[client], Prop_Send, "m_vecMins", m_vecMins);
            GetEntPropVector(g_iTurrets[client], Prop_Send, "m_vecMaxs", m_vecMaxs);
            
            // MASK_SOLID
            TR_TraceHullFilter(TurretPos, EnemyPos, m_vecMins, m_vecMaxs, MASK_SOLID, DontHitOwnerOrNade, client);
            if(TR_GetEntityIndex() == i)
            {
                TurretTickFollow(client, i);
                return;
            }
            
        }
    }
    TurretTickIdle(client);
}

void TurretTickFollow(int owner, int player)
{
    float TurretPos[3], EnemyPos[3],EnemyAngle[3], TuretAngle[3], fDir[3];
    
    GetEntPropVector(g_iTurrets[owner], Prop_Send, "m_angRotation", TuretAngle);
    GetEntPropVector(g_iTurrets[owner], Prop_Send, "m_vecOrigin", TurretPos);
    GetClientAbsOrigin(player, EnemyPos);
    
    MakeVectorFromPoints(EnemyPos, TurretPos, fDir);
    GetVectorAngles(EnemyPos, EnemyAngle);
    GetVectorAngles(fDir, fDir);
    fDir[2]=0.0;
    
    TuretAngle[1]+=180.0;
    
    float m_iDegreesY = (((fDir[2]-TuretAngle[2])+30.0)/60.0);
    float m_iDegreesX = (((fDir[1]-TuretAngle[1])+30.0)/60.0);
    
    if(m_iDegreesX < 0.0 || m_iDegreesX > 2.2)
    {
        TurretTickIdle(owner);
        return;
    }
    
    g_fAim[owner] = m_iDegreesX;
    SetEntPropFloat(g_iTurrets[owner], Prop_Send, "m_flPoseParameter", m_iDegreesX, 0);
    SetEntPropFloat(g_iTurrets[owner], Prop_Send, "m_flPoseParameter", m_iDegreesY, 1);
    
    if(g_bCanShoot[owner])
    {
        SetVariantString("retract");
        AcceptEntityInput(g_iTurrets[owner], "SetAnimationNoReset", -1, -1, 0);
        
        TurretPos[2]+=50.0;
        EnemyPos[2] = (EnemyPos[2] + GetRandomFloat(10.0, 70.0));
        EnemyPos[0] = (EnemyPos[0] + GetRandomFloat(-5.0, 5.0));
        EnemyPos[1] = (EnemyPos[1] + GetRandomFloat(-5.0, 5.0));
        
        if(GetTurretTeam(g_iTurrets[owner]) == CS_TEAM_CT)
        {
            TE_SetupBeamPoints(TurretPos, EnemyPos, g_iBeam, g_iHalo, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {128,128,64, 100}, 0);
        }
        else if(GetTurretTeam(g_iTurrets[owner]) == CS_TEAM_T)
        {
            TE_SetupBeamPoints(TurretPos, EnemyPos, g_iBeam, g_iHalo, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {102,153,255, 100}, 0);
        }
        else
        {
            TE_SetupBeamPoints(TurretPos, EnemyPos, g_iBeam, g_iHalo, 0, 30, GetRandomFloat(0.1, 0.3), 1.0, 1.0, 0, 1.0, {204,0,51, 100}, 0);
        }

        TE_SendToAll();
        
        int hp = g_cDamage.IntValue;
        
        SDKHooks_TakeDamage(player, 0, owner, float(hp * 2), DMG_BULLET, -1 , TurretPos, EnemyPos); //http://docs.sourcemod.net/api/index.php?fastload=show&id=1028&
        
        char szFile[128];
        Format(szFile, sizeof(szFile), "player/damage%d.wav", GetRandomInt(1, 3));
        EmitSoundToClient(player, szFile);
        EmitAmbientSound("weapons/sg556/sg556-1.wav", TurretPos);
        
        g_bCanShoot[owner] = false;
        
        int ref = EntIndexToEntRef(owner);
        
        CreateTimer(g_cRate.FloatValue, TurretSetState, ref);
    }
}

public Action TurretSetState(Handle Timer, any ref)
{
    
    int entity = EntRefToEntIndex(ref);
    
    if (entity != INVALID_ENT_REFERENCE)
    {
        g_bCanShoot[entity] = true;
    }
}

public void OnGameFrame()
{
    LoopValidClients(i)
    {
        if(g_iTurrets[i] != -1 && IsValidEdict(g_iTurrets[i]))
        {
            TickTurret(i);
        }
    }
}

public bool DontHitOwnerOrNade(int entity, int contentsMask, any data)
{
    if(entity > 0 && entity < MaxClients && IsClientInGame(entity)) 
    {
        return true;
    }
    return false;
}

void TurretTickIdle(int client)
{
    if(g_fAim[client] <= 0.1) g_bTurretAim[client] = true;
    if(g_fAim[client] >= 0.9) g_bTurretAim[client] = false;    
    
    if(g_bTurretAim[client])
    {
        g_fAim[client] = (g_fAim[client] + 0.01);
    }
    else
    {
        g_fAim[client] = (g_fAim[client] - 0.01);
    }
    
    SetEntPropFloat(g_iTurrets[client], Prop_Send, "m_flPoseParameter", g_fAim[client], 0);
    SetEntPropFloat(g_iTurrets[client], Prop_Send, "m_flPoseParameter", 0.5, 1);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("CreateTurret", Native_CreateTurret);
    CreateNative("RemoveTurret", Native_RemovePlayerTurret);
    CreateNative("SetTurretCanAttackClient", Native_SetTurretCanAttackClient);

    g_hOnDead = CreateGlobalForward("Turret_OnTurretDead", ET_Event, Param_Cell, Param_Cell);
    
    RegPluginLibrary("turret_core");

    return APLRes_Success;
}

public int Native_CreateTurret(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!TTT_IsClientValid(client))
    {
        PrintToServer("Invalid client (%d)", client);
        return;
    }
    CreateTurret(client);
}

public int Native_RemovePlayerTurret(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!TTT_IsClientValid(client))
    {
        PrintToServer("Invalid client (%d)", client);
        return;
    }
    DestroyTurrets(client);
    ResetPlayerVars(client);
}

public int Native_SetTurretCanAttackClient(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    bool bCanAttack = view_as<bool>(GetNativeCell(2));
    if (!TTT_IsClientValid(client))
    {
        PrintToServer("Invalid client (%d)", client);
        return;
    }
    g_bCanAttack[client] = bCanAttack;
    
}
