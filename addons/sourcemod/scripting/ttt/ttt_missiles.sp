#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Missiles"

#define SHORT_NAME_T "missile_t"
#define SHORT_NAME_D "missile_d"
#define SHORT_NAME_I "missile_i"
#define SHORT_NAMEF_T "missile_f_t"
#define SHORT_NAMEF_D "missile_f_d"
#define SHORT_NAMEF_I "missile_f_i"
#define SHORT_NAMEC_T "missile_c_t"
#define SHORT_NAMEC_D "missile_c_d"
#define SHORT_NAMEC_I "missile_c_i"

#define FSOLID_NOT_SOLID 0x0004
#define MISSILE_MODEL "models/props/de_inferno/hr_i/missile/missile_02.mdl"
#define MISSILE_SOUND "weapons/rpg/rocket1.wav"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <ttt_shop>
#include <emitsoundany>

#pragma newdecls required

enum MissileType
{
    tNone = -1,
    tNormal = 0,
    tFollow = 1,
    tControl = 2
}

ConVar g_cDamage = null;
ConVar g_cRadius = null;
ConVar g_cSpeed = null;
ConVar g_cArc = null;
ConVar g_cVolume = null;

ConVar g_cPriceT_F = null;
ConVar g_cPriceD_F = null;
ConVar g_cPriceI_F = null;
ConVar g_cPriorityT_F = null;
ConVar g_cPriorityD_F = null;
ConVar g_cPriorityI_F = null;
ConVar g_cAmountT_F = null;
ConVar g_cAmountD_F = null;
ConVar g_cAmountI_F = null;
ConVar g_cName_F = null;
ConVar g_cStandOffset_F = null;
ConVar g_cDuckOffset_F = null;
int g_iPAmount_F[MAXPLAYERS + 1] =  { 0, ... };
int g_iMissile_F[MAXPLAYERS + 1] =  { 0, ... };

ConVar g_cPriceT_C = null;
ConVar g_cPriceD_C = null;
ConVar g_cPriceI_C = null;
ConVar g_cPriorityT_C = null;
ConVar g_cPriorityD_C = null;
ConVar g_cPriorityI_C = null;
ConVar g_cAmountT_C = null;
ConVar g_cAmountD_C = null;
ConVar g_cAmountI_C = null;
ConVar g_cName_C = null;
int g_iPAmount_C[MAXPLAYERS + 1] =  { 0, ... };
int g_iMissile_C[MAXPLAYERS + 1] =  { 0, ... };

int g_iMissileEnt[MAXPLAYERS +1] = { -1, ... };

ConVar g_cPriceT = null;
ConVar g_cPriceD = null;
ConVar g_cPriceI = null;
ConVar g_cPriorityT = null;
ConVar g_cPriorityD = null;
ConVar g_cPriorityI = null;
ConVar g_cAmountT = null;
ConVar g_cAmountD = null;
ConVar g_cAmountI = null;
ConVar g_cName = null;
int g_iPAmount[MAXPLAYERS + 1] =  { 0, ... };
int g_iMissile[MAXPLAYERS + 1] =  { 0, ... };

float g_fMinNadeHull[3] = {-2.5, -2.5, -2.5};
float g_fMaxNadeHull[3] = {2.5, 2.5, 2.5};
float g_fMaxWorldLength = 0.0;
float g_fSpinVel[3] = {0.0, 0.0, 200.0};
float g_fClientAngles[MAXPLAYERS + 1][3];

MissileType g_iType[MAXPLAYERS + 1] =  { tNone, ... };

ConVar g_cNoblock = null;

public Plugin myinfo = 
{
    name = PLUGIN_NAME, 
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION, 
    version = PLUGIN_AUTHOR, 
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    
    TTT_LoadTranslations();

    TTT_StartConfig("missiles");
    CreateConVar("ttt2_missiles_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cDamage = AutoExecConfig_CreateConVar("missiles_damage", "850", "Sets the maximum amount of damage the missiles can do", _, true, 1.0);
    g_cRadius = AutoExecConfig_CreateConVar("missiles_radius", "600", "Sets the explosive radius of the missiles", _, true, 1.0);
    g_cSpeed = AutoExecConfig_CreateConVar("missiles_speed", "500.0", "Sets the speed of the missiles", _, true, 300.0 ,true, 3000.0);
    g_cArc = AutoExecConfig_CreateConVar("missiles_arc", "1", "1 enables the turning arc of missiles, 0 makes turning instant for missiles", _, true, 0.0, true, 1.0);
    g_cVolume = AutoExecConfig_CreateConVar("missile_volume", "1.0", "Sound volume of the missile", _, true, 0.1, true, 1.0);

    g_cPriceT = AutoExecConfig_CreateConVar("missiles_price_t", "0", "Price for the missile for Traitors", _, true, 0.0);
    g_cPriceD = AutoExecConfig_CreateConVar("missiles_price_d", "0", "Price for the missile for Detectives", _, true, 0.0);
    g_cPriceI = AutoExecConfig_CreateConVar("missiles_price_i", "0", "Price for the missile for Innos", _, true, 0.0);
    g_cPriorityT = AutoExecConfig_CreateConVar("missiles_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD = AutoExecConfig_CreateConVar("missiles_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cPriorityI = AutoExecConfig_CreateConVar("missiles_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cAmountT = AutoExecConfig_CreateConVar("missiles_amount_t", "0", "How much missiles can a traitor buy?");
    g_cAmountD = AutoExecConfig_CreateConVar("missiles_amount_d", "0", "How much missiles can a detective buy?");
    g_cAmountI = AutoExecConfig_CreateConVar("missiles_amount_i", "0", "How much missiles can a innocent buy?");
    g_cName = AutoExecConfig_CreateConVar("missiles_name", "Missile", "The name of the missile in the shop");
    
    g_cPriceT_F = AutoExecConfig_CreateConVar("missiles_following_price_t", "0", "Price for the following missile for Traitors", _, true, 0.0);
    g_cPriceD_F = AutoExecConfig_CreateConVar("missiles_following_price_d", "0", "Price for the following missile for Detectives", _, true, 0.0);
    g_cPriceI_F = AutoExecConfig_CreateConVar("missiles_following_price_i", "0", "Price for the following missile for Innos", _, true, 0.0);
    g_cPriorityT_F = AutoExecConfig_CreateConVar("missiles_following_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD_F = AutoExecConfig_CreateConVar("missiles_following_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cPriorityI_F = AutoExecConfig_CreateConVar("missiles_following_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cAmountT_F = AutoExecConfig_CreateConVar("missiles_following_amount_t", "0", "How much following missiles can a traitor buy?");
    g_cAmountD_F = AutoExecConfig_CreateConVar("missiles_following_amount_d", "0", "How much following missiles can a detective buy?");
    g_cAmountI_F = AutoExecConfig_CreateConVar("missiles_following_amount_i", "0", "How much following missiles can a innocent buy?");
    g_cName_F = AutoExecConfig_CreateConVar("missiles_following_name", "Following Missile", "The name of the following missile in the shop");
    g_cStandOffset_F = AutoExecConfig_CreateConVar("missiles_following_stand_position_offset", "50", "Units from the ground where the missile hits the player while he's standing. (Default: 50)");
    g_cDuckOffset_F = AutoExecConfig_CreateConVar("missiles_following_duck_position_offset", "35", "Units from the ground where the missile hits the player while he's ducked. (Default: 35)");

    g_cPriceT_C = AutoExecConfig_CreateConVar("missiles_control_price_t", "0", "Price for the control missile for Traitors", _, true, 0.0);
    g_cPriceD_C = AutoExecConfig_CreateConVar("missiles_control_price_d", "0", "Price for the control missile for Detectives", _, true, 0.0);
    g_cPriceI_C = AutoExecConfig_CreateConVar("missiles_control_price_i", "0", "Price for the control missile for Innos", _, true, 0.0);
    g_cPriorityT_C = AutoExecConfig_CreateConVar("missiles_control_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD_C = AutoExecConfig_CreateConVar("missiles_control_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cPriorityI_C = AutoExecConfig_CreateConVar("missiles_control_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cAmountT_C = AutoExecConfig_CreateConVar("missiles_control_amount_t", "0", "How much control missiles can a traitor buy?");
    g_cAmountD_C = AutoExecConfig_CreateConVar("missiles_control_amount_d", "0", "How much control missiles can a detective buy?");
    g_cAmountI_C = AutoExecConfig_CreateConVar("missiles_control_amount_i", "0", "How much control missiles can a innocent buy?");
    g_cName_C = AutoExecConfig_CreateConVar("missiles_control_name", "Controlling Missile", "The name of the control missile in the shop");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_Reset);
    HookEvent("player_death", Event_Reset);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnMapStart()
{
    float WorldMinHull[3]; 
    float WorldMaxHull[3];
    GetEntPropVector(0, Prop_Send, "m_WorldMins", WorldMinHull);
    GetEntPropVector(0, Prop_Send, "m_WorldMaxs", WorldMaxHull);
    g_fMaxWorldLength = GetVectorDistance(WorldMinHull, WorldMaxHull);
    
    int iIndex = PrecacheModel(MISSILE_MODEL);

    if (iIndex == 0)
    {
        SetFailState("Can't precache missile model!");
    }
    
    PrecacheSound(MISSILE_SOUND);
    AddFileToDownloadsTable("sound/" ... MISSILE_SOUND);

    PrecacheSound("weapons/hegrenade/explode5.wav");
}

public void OnConfigsExecuted()
{
    g_cNoblock = FindConVar("ttt_enable_noblock");
}

public void TTT_OnShopReady()
{
    char sName[32];

    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAME_T, sName, g_cPriceT.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT.IntValue);
    TTT_RegisterCustomItem(SHORT_NAME_I, sName, g_cPriceD.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD.IntValue);
    TTT_RegisterCustomItem(SHORT_NAME_D, sName, g_cPriceI.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI.IntValue);
    
    g_cName_F.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAMEF_T, sName, g_cPriceT_F.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT_F.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEF_I, sName, g_cPriceD_F.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD_F.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEF_D, sName, g_cPriceI_F.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI_F.IntValue);

    g_cName_C.GetString(sName, sizeof(sName));
    TTT_RegisterCustomItem(SHORT_NAMEC_T, sName, g_cPriceT_C.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT_C.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEC_I, sName, g_cPriceD_C.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD_C.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEC_D, sName, g_cPriceI_C.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI_C.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
    if(TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME_T, false))
        {
            if(!(g_iPAmount[client] < g_cAmountT.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAME_D, false))
        {
            if(!(g_iPAmount[client] < g_cAmountD.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAME_I, false))
        {
            if(!(g_iPAmount[client] < g_cAmountI.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEF_T, false))
        {
            if(!(g_iPAmount_F[client] < g_cAmountT_F.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveFollowingMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEF_D, false))
        {
            if(!(g_iPAmount_F[client] < g_cAmountD_F.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveFollowingMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEF_I, false))
        {
            if(!(g_iPAmount_F[client] < g_cAmountI_F.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveFollowingMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEC_T, false))
        {
            if(!(g_iPAmount_C[client] < g_cAmountT_C.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveControlMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEC_D, false))
        {
            if(!(g_iPAmount_C[client] < g_cAmountD_C.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveControlMissile(client);
        }
        else if(StrEqual(itemshort, SHORT_NAMEC_I, false))
        {
            if(!(g_iPAmount_C[client] < g_cAmountI_C.IntValue))
            {
                return Plugin_Stop;
            }
            
            GiveControlMissile(client);
        }

        if(strncmp(itemshort,"missile_",8,false) == 0)
        {
            GiveGrenade(client);
        }
    }
    return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "hegrenade_projectile", false))
    {
        HookSingleEntityOutput(entity, "OnUser2", InitMissile, true);
        
        char sOutputString[50] = "OnUser1 !self:FireUser2::0.0:1";
        SetVariantString(sOutputString);
        AcceptEntityInput(entity, "AddOutput");
        
        AcceptEntityInput(entity, "FireUser1");
    }
}

public int InitMissile(const char[] output, int caller, int activator, float delay)
{
    int iOwner = GetEntPropEnt(caller, Prop_Send, "m_hThrower");
    
    // assume other plugins don't set this on any projectiles they create, this avoids conflicts.
    if (!TTT_IsClientValid(iOwner))
    {
        return;
    }
    
    if ((!g_iMissile[iOwner] && !g_iMissile_F[iOwner] && !g_iMissile_C[iOwner]) || g_iType[iOwner] != tNone)
    {
        return;
    }
        
    if(g_iMissile_C[iOwner])
    {
        g_iMissile_C[iOwner]--;
        g_iType[iOwner] = tControl;
    }
    else if(g_iMissile_F[iOwner])
    {
        g_iMissile_F[iOwner]--;
        g_iType[iOwner] = tFollow;
    }
    else
    {
        g_iMissile[iOwner]--;
        g_iType[iOwner] = tNormal;
        GetClientEyeAngles(iOwner, g_fClientAngles[iOwner]);
        g_fClientAngles[iOwner][1] -= 90.0;
    }

    // stop the projectile thinking so it doesn't detonate.
    SetEntProp(caller, Prop_Data, "m_nNextThinkTick", -1);
    SetEntityMoveType(caller, MOVETYPE_FLY);
    SetEntityModel(caller, MISSILE_MODEL);
    // make it spin correctly.
    SetEntPropVector(caller, Prop_Data, "m_vecAngVelocity", g_fSpinVel);
    // stop it bouncing when it hits something
    SetEntPropFloat(caller, Prop_Send, "m_flElasticity", 0.0);
    SetEntPropVector(caller, Prop_Send, "m_vecMins", g_fMinNadeHull);
    SetEntPropVector(caller, Prop_Send, "m_vecMaxs", g_fMaxNadeHull);

    float fNadePos[3];
    GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fNadePos);
    
    float fAngles[3];
    GetClientEyeAngles(iOwner, fAngles);

    float fPosition[3];
    GetClientAbsOrigin(iOwner, fPosition);
    fPosition[2] += 50.0;

    TR_TraceRayFilter(fPosition, fAngles, MASK_SOLID, RayType_Infinite, DontHitOwnerOrNade, caller);

    float fInitPos[3];
    TR_GetEndPosition(fInitPos);

    float fInitVec[3];
    MakeVectorFromPoints(fNadePos, fInitPos, fInitVec);
    NormalizeVector(fInitVec, fInitVec);
    ScaleVector(fInitVec, g_cSpeed.FloatValue);

    float fInitAng[3];
    GetVectorAngles(fInitVec, fInitAng);
    fInitAng[1] -= 90.0;
    if (g_iType[iOwner] != tNormal)
    {
        TeleportEntity(caller, NULL_VECTOR, fInitAng, fInitVec);
    }
    else
    {
        TeleportEntity(caller, NULL_VECTOR, g_fClientAngles[iOwner], fInitVec);
    }
    // DispatchKeyValueVector(caller, "Angles", fInitAng);
    
    // EmitSoundToAll("weapons/rpg/rocket1.wav", caller, 1, 90);
    EmitAmbientSoundAny(MISSILE_SOUND, fAngles, caller, 90, _, g_cVolume.FloatValue);
    
    HookSingleEntityOutput(caller, "OnUser2", MissileThink);
    
    char sOutputString[] = "OnUser1 !self:FireUser2::0.1:-1";
    SetVariantString(sOutputString);
    AcceptEntityInput(caller, "AddOutput");
    
    AcceptEntityInput(caller, "FireUser1");
    
    SDKHook(caller, SDKHook_StartTouch, OnStartTouch);
    
    if(g_iType[iOwner] == tControl)
    {
        g_iMissileEnt[iOwner] = caller;
        SetClientViewEntity(iOwner, caller);
    }
}

public void MissileThink(const char[] output, int caller, int activator, float delay)
{
    int iOwner = GetEntPropEnt(caller, Prop_Send, "m_hThrower");

    if(!TTT_IsClientValid(iOwner))
    {
        return;
    }
    
    // detonate any missiles that stopped for any reason but didn't detonate.
    float fCheckVec[3];
    GetEntPropVector(caller, Prop_Send, "m_vecVelocity", fCheckVec);
    if ((fCheckVec[0] == 0.0) && (fCheckVec[1] == 0.0) && (fCheckVec[2] == 0.0))
    {
        StopSound(caller, 1, "weapons/rpg/rocket1.wav");
        CreateExplosion(caller);
        return;
    }
    
    float fNadePos[3];
    GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fNadePos);

    if (g_iType[iOwner] == tNormal)
    {
        TeleportEntity(caller, NULL_VECTOR, g_fClientAngles[iOwner], NULL_VECTOR);
    }
    else if (g_iType[iOwner] == tFollow)
    {
        float fClosestDistance = g_fMaxWorldLength;
        float fTargetVec[3];
        
        int iClosestEnemy;
        float fEnemyDistance;
        LoopValidClients(i)
        {
            if (TTT_IsPlayerAlive(i))
            {
                if(TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
                {
                    continue;
                }

                float fEnemyPos[3];
                GetClientAbsOrigin(i, fEnemyPos);
                fEnemyPos[2] += 50.0;
                TR_TraceHullFilter(fNadePos, fEnemyPos, g_fMinNadeHull, g_fMaxNadeHull, MASK_SOLID, DontHitOwnerOrNade, caller);
                if (TR_GetEntityIndex() == i)
                {
                    fEnemyDistance = GetVectorDistance(fNadePos, fEnemyPos);
                    if (fEnemyDistance < fClosestDistance)
                    {
                        iClosestEnemy = i;
                        fClosestDistance = fEnemyDistance;
                    }
                }
            }
        }
        // no target found, continue along current trajectory.
        if (!TTT_IsClientValid(iClosestEnemy))
        {
            AcceptEntityInput(caller, "FireUser1");
            return;
        }
        else
        {
            float fEnemyPos[3];
            GetClientAbsOrigin(iClosestEnemy, fEnemyPos);

            bool bDucked = view_as<bool>(GetEntProp(iClosestEnemy, Prop_Send, "m_bDucked"));
            bool bDucking = view_as<bool>(GetEntProp(iClosestEnemy, Prop_Send, "m_bDucking"));

            if (bDucked || bDucking)
            {
                fEnemyPos[2] += g_cDuckOffset_F.FloatValue;
            }
            else
            {
                fEnemyPos[2] += g_cStandOffset_F.FloatValue;
            }

            MakeVectorFromPoints(fNadePos, fEnemyPos, fTargetVec);
            NormalizeVector(fTargetVec, fTargetVec);
        }
        
        float fFinalVec[3];
        if (g_cArc.BoolValue && (fClosestDistance > 100.0))
        {
            float fCurrentVec[3];
            GetEntPropVector(caller, Prop_Send, "m_vecVelocity", fCurrentVec);
            NormalizeVector(fCurrentVec, fCurrentVec);
            ScaleVector(fTargetVec, g_cSpeed.FloatValue / 1000.0);
            AddVectors(fTargetVec, fCurrentVec, fFinalVec);
        }
        else
        {
            fFinalVec = fTargetVec;
        }
        
        NormalizeVector(fFinalVec, fFinalVec);
        ScaleVector(fFinalVec, g_cSpeed.FloatValue);
        float fFinalAng[3];
        GetVectorAngles(fFinalVec, fFinalAng);
        fFinalAng[1] -= 90.0;
        TeleportEntity(caller, NULL_VECTOR, fFinalAng, fFinalVec);

        if (g_cNoblock == null)
        {
            g_cNoblock = FindConVar("ttt_enable_noblock");
        }

        if (g_cNoblock.BoolValue)
        {
            float fEnemyPos[3];
            GetClientAbsOrigin(iClosestEnemy, fEnemyPos);
            fEnemyPos[2] += 50.0;

            float fDistance = 0.0;
            fDistance = GetVectorDistance(fNadePos, fEnemyPos);

            if(fDistance < 34.0)
            {
                CreateExplosion(caller);
            }

            /* Handle hTrace = TR_TraceRayFilterEx(fNadePos, fEnemyPos, MASK_PLAYERSOLID, RayType_Infinite, TR_DontHitSelf, caller);
            int iTarget = -1; 

            if (TR_DidHit(hTrace))
            {
                iTarget = TR_GetEntityIndex(hTrace);

                if (iTarget == iClosestEnemy)
                {
                    CreateExplosion(caller);
                }
            }

            delete hTrace; */
        }
    }
    else if (g_iType[iOwner] == tControl)
    {

        float fclientAngles[3];
        float fFinalVec[3];
        float fTargetVec[3];
        GetClientEyeAngles(iOwner, fclientAngles);

        Handle hTrace = INVALID_HANDLE;
        hTrace = TR_TraceRayFilterEx(fNadePos, fclientAngles, MASK_SOLID, RayType_Infinite, DontHitOwnerOrNade, caller);
        
        if (TR_DidHit(hTrace))
        {
            TR_GetEndPosition(fFinalVec, hTrace);
            
            MakeVectorFromPoints(fNadePos, fFinalVec, fTargetVec);
            NormalizeVector(fTargetVec, fTargetVec);
            GetVectorAngles(fTargetVec, fclientAngles);
            ScaleVector(fTargetVec, g_cSpeed.FloatValue * 1.2);
            TeleportEntity(caller, NULL_VECTOR, fclientAngles, fTargetVec);
        }
        
        delete hTrace;

        /*
        float fclientAngles[3];
        float fMissilePos[3];
        float fvecAngle[3];
        
        GetClientEyeAngles(iOwner, fclientAngles);
        GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fMissilePos);

        fvecAngle[0] = fMissilePos[0];
        fvecAngle[1] = fMissilePos[1];
        fvecAngle[2] = fMissilePos[2];

        GetAngleVectors(fvecAngle, fvecAngle, NULL_VECTOR, NULL_VECTOR);
        NormalizeVector(fvecAngle, fvecAngle);
        ScaleVector(fvecAngle, g_cSpeed.FloatValue / 2);
        AddVectors(fMissilePos, fvecAngle, fMissilePos);

        TeleportEntity(caller, NULL_VECTOR, fclientAngles, fvecAngle);
        
        GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fMissilePos);
        TeleportEntity(caller, fMissilePos, fclientAngles, NULL_VECTOR);
        */
    }
    AcceptEntityInput(caller, "FireUser1");
}

public bool TR_DontHitSelf(int entity, int mask, int data)
{
    return (entity != data);
}

public void OnGameFrame()
{
    LoopValidClients(i)
    {
        if (TTT_IsPlayerAlive(i) && g_iMissileEnt[i] != -1 && IsValidEntity(g_iMissileEnt[i]))
        {
            float fclientAngles[3];
            GetClientEyeAngles(i, fclientAngles);
            TeleportEntity(g_iMissileEnt[i], NULL_VECTOR, fclientAngles, NULL_VECTOR);
        }
    }
}

public bool DontHitOwnerOrNade(int entity, int contentsMask, any data)
{
    int iOwner = GetEntPropEnt(data, Prop_Send, "m_hThrower");
    return ((entity != data) && (entity != iOwner));
}

public Action OnStartTouch(int entity, int other) 
{
    if (other == 0)
    {
        // StopSound(entity, 1, "weapons/rpg/rocket1.wav");
        CreateExplosion(entity);
    } 
    else if((GetEntProp(other, Prop_Data, "m_nSolidType") != view_as<int>(SOLID_NONE)) && (!(GetEntProp(other, Prop_Data, "m_usSolidFlags") & FSOLID_NOT_SOLID)))
    {
        // StopSound(entity, 1, "weapons/rpg/rocket1.wav");
        CreateExplosion(entity);
        
    }
    return Plugin_Continue;
}

void CreateExplosion(int entity)
{
    UnhookSingleEntityOutput(entity, "OnUser2", MissileThink);
    
    float fMissilePos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fMissilePos);
    int iMissileOwner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
    int iMissileTeam = GetEntProp(entity, Prop_Send, "m_iTeamNum");
    
    if(g_iType[iMissileOwner] == tControl)
    {
        SetClientViewEntity(iMissileOwner, iMissileOwner);
        g_iMissileEnt[iMissileOwner] = -1;
    }

    g_iType[iMissileOwner] = tNone;
    
    int iExplosion = CreateEntityByName("env_explosion");
    if (iExplosion != -1)
    {
        DispatchKeyValue(iExplosion, "classname", "hegrenade_projectile");

        SetEntPropString(iExplosion, Prop_Data, "m_iGlobalname", "Missile");
        
        SetEntProp(iExplosion, Prop_Data, "m_spawnflags", 6146);
        SetEntProp(iExplosion, Prop_Data, "m_iMagnitude", g_cDamage.IntValue);
        SetEntProp(iExplosion, Prop_Data, "m_iRadiusOverride", g_cRadius.IntValue);
        
        DispatchSpawn(iExplosion);
        ActivateEntity(iExplosion);
        
        TeleportEntity(iExplosion, fMissilePos, NULL_VECTOR, NULL_VECTOR);
        SetEntPropEnt(iExplosion, Prop_Send, "m_hOwnerEntity", iMissileOwner);
        SetEntProp(iExplosion, Prop_Send, "m_iTeamNum", iMissileTeam);
        
        EmitSoundToAll("weapons/hegrenade/explode5.wav", iExplosion, 1, 90);
        
        AcceptEntityInput(iExplosion, "Explode");
        
        DispatchKeyValue(iExplosion,"classname","env_explosion");
        
        AcceptEntityInput(iExplosion, "Kill");
    }
    
    AcceptEntityInput(entity, "Kill");
}

public void Event_Reset(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (TTT_IsClientValid(client))
    {
        ResetClient(client);
    }
}

void GiveMissile(int client)
{
    g_iMissile[client]++;
    g_iPAmount[client]++;
}

void GiveControlMissile(int client)
{
    g_iMissile_C[client]++;
    g_iPAmount_C[client]++;
}

void GiveFollowingMissile(int client)
{
    g_iMissile_F[client]++;
    g_iPAmount_F[client]++;
}

void GiveGrenade(int client)
{
    int iAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", 4, 11);
    
    if (!iAmmo)
    {
        GivePlayerItem(client, "weapon_hegrenade");
    }
    
    /* if (iAmmo)
    {
        SetEntProp(client, Prop_Send, "m_iAmmo", g_iMissile[client] + g_iMissile_F[client], 4, 11);
    } */
}

void ResetClient(int client)
{
    if(g_iType[client] == tControl || g_iMissileEnt[client] != -1)
    {
        SetClientViewEntity(client, client);
    }
    
    g_iPAmount[client] = 0;
    g_iMissile[client] = 0;
    g_iPAmount_F[client] = 0;
    g_iMissile_F[client] = 0;
    g_iPAmount_C[client] = 0;
    g_iMissile_C[client] = 0;
    g_iMissileEnt[client] = -1;
    g_iType[client] = tNone;
}

