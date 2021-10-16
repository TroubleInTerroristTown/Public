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
#include <ttt_inventory>
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
ConVar g_cLimitT_F = null;
ConVar g_cPriceD_F = null;
ConVar g_cLimitD_F = null;
ConVar g_cPriceI_F = null;
ConVar g_cLimitI_F = null;
ConVar g_cPriorityT_F = null;
ConVar g_cPriorityD_F = null;
ConVar g_cPriorityI_F = null;
ConVar g_cCountFI = null;
ConVar g_cCountFT = null;
ConVar g_cCountFD = null;
ConVar g_cName_F = null;
ConVar g_cStandOffset_F = null;
ConVar g_cDuckOffset_F = null;
ConVar g_cPriceT_C = null;
ConVar g_cLimitT_C = null;
ConVar g_cPriceD_C = null;
ConVar g_cLimitD_C = null;
ConVar g_cPriceI_C = null;
ConVar g_cLimitI_C = null;
ConVar g_cPriorityT_C = null;
ConVar g_cPriorityD_C = null;
ConVar g_cPriorityI_C = null;
ConVar g_cCountCI = null;
ConVar g_cCountCT = null;
ConVar g_cCountCD = null;
ConVar g_cName_C = null;
ConVar g_cPriceT = null;
ConVar g_cLimitT = null;
ConVar g_cPriceD = null;
ConVar g_cLimitD = null;
ConVar g_cPriceI = null;
ConVar g_cLimitI = null;
ConVar g_cPriorityT = null;
ConVar g_cPriorityD = null;
ConVar g_cPriorityI = null;
ConVar g_cCountT = null;
ConVar g_cCountD = null;
ConVar g_cCountI = null;
ConVar g_cName = null;
ConVar g_cNoblock = null;

float g_fMinNadeHull[3] = {-2.5, -2.5, -2.5};
float g_fMaxNadeHull[3] = {2.5, 2.5, 2.5};
float g_fMaxWorldLength = 0.0;
float g_fSpinVel[3] = {0.0, 0.0, 200.0};

enum struct PlayerData {
    int FollowingAmount;
    int FollowingMissile;
    int ControlAmount;
    int ControlMissile;
    int MissileAmount;
    int MissileEntity;
    int Missile;

    MissileType Type;

    float Location[3];
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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

    g_cName = AutoExecConfig_CreateConVar("missiles_name", "Missile", "The name of the missile in the shop");
    g_cPriceT = AutoExecConfig_CreateConVar("missiles_price_t", "7500", "Price for the missile for Traitors", _, true, 0.0);
    g_cLimitT = AutoExecConfig_CreateConVar("missiles_limit_t", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceD = AutoExecConfig_CreateConVar("missiles_price_d", "0", "Price for the missile for Detectives", _, true, 0.0);
    g_cLimitD = AutoExecConfig_CreateConVar("missiles_limit_d", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceI = AutoExecConfig_CreateConVar("missiles_price_i", "0", "Price for the missile for Innos", _, true, 0.0);
    g_cLimitI = AutoExecConfig_CreateConVar("missiles_limit_i", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriorityT = AutoExecConfig_CreateConVar("missiles_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD = AutoExecConfig_CreateConVar("missiles_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cPriorityI = AutoExecConfig_CreateConVar("missiles_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cCountI = AutoExecConfig_CreateConVar("missiles_amount_i", "0", "How often the item (Missile) can be bought per round as an innocent (0 - Disabled).");
    g_cCountT = AutoExecConfig_CreateConVar("missiles_amount_t", "2", "How often the item (Missile) can be bought per round as a traitor (0 - Disabled).");
    g_cCountD = AutoExecConfig_CreateConVar("missiles_amount_d", "0", "How often the item (Missile) can be bought per round as a detective (0 - Disabled).");
    
    g_cName_F = AutoExecConfig_CreateConVar("missiles_following_name", "Following Missile", "The name of the following missile in the shop");
    g_cPriceI_F = AutoExecConfig_CreateConVar("missiles_following_price_i", "0", "Price for the following missile for Innos", _, true, 0.0);
    g_cLimitI_F = AutoExecConfig_CreateConVar("missiles_following_limit_i", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceT_F = AutoExecConfig_CreateConVar("missiles_following_price_t", "10000", "Price for the following missile for Traitors", _, true, 0.0);
    g_cLimitT_F = AutoExecConfig_CreateConVar("missiles_following_limit_t", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceD_F = AutoExecConfig_CreateConVar("missiles_following_price_d", "0", "Price for the following missile for Detectives", _, true, 0.0);
    g_cLimitD_F = AutoExecConfig_CreateConVar("missiles_following_limit_d", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriorityI_F = AutoExecConfig_CreateConVar("missiles_following_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cPriorityT_F = AutoExecConfig_CreateConVar("missiles_following_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD_F = AutoExecConfig_CreateConVar("missiles_following_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cCountFI = AutoExecConfig_CreateConVar("missiles_following_amount_i", "0", "How often the item (Following Missile) can be bought per round as an innocent (0 - Disabled).");
    g_cCountFT = AutoExecConfig_CreateConVar("missiles_following_amount_t", "2", "How often the item (Following Missile) can be bought per round as a traitor (0 - Disabled).");
    g_cCountFD = AutoExecConfig_CreateConVar("missiles_following_amount_d", "0", "How often the item (Following Missile) can be bought per round as a detective (0 - Disabled).");
    g_cStandOffset_F = AutoExecConfig_CreateConVar("missiles_following_stand_position_offset", "50", "Units from the ground where the missile hits the player while he's standing. (Default: 50)");
    g_cDuckOffset_F = AutoExecConfig_CreateConVar("missiles_following_duck_position_offset", "35", "Units from the ground where the missile hits the player while he's ducked. (Default: 35)");

    g_cName_C = AutoExecConfig_CreateConVar("missiles_control_name", "Controlling Missile", "The name of the control missile in the shop");
    g_cPriceI_C = AutoExecConfig_CreateConVar("missiles_control_price_i", "0", "Price for the control missile for Innos", _, true, 0.0);
    g_cLimitI_C = AutoExecConfig_CreateConVar("missiles_control_limit_i", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceT_C = AutoExecConfig_CreateConVar("missiles_control_price_t", "10000", "Price for the control missile for Traitors", _, true, 0.0);
    g_cLimitT_C = AutoExecConfig_CreateConVar("missiles_control_limit_t", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriceD_C = AutoExecConfig_CreateConVar("missiles_control_price_d", "0", "Price for the control missile for Detectives", _, true, 0.0);
    g_cLimitD_C = AutoExecConfig_CreateConVar("missiles_control_limit_d", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cPriorityI_C = AutoExecConfig_CreateConVar("missiles_control_priority_i", "0", "Priority in shop list for Innos", _, true, 0.0);
    g_cPriorityT_C = AutoExecConfig_CreateConVar("missiles_control_priority_t", "0", "Priority in shop list for Traitors", _, true, 0.0);
    g_cPriorityD_C = AutoExecConfig_CreateConVar("missiles_control_priority_d", "0", "Priority in shop list for Detectives", _, true, 0.0);
    g_cCountCI = AutoExecConfig_CreateConVar("missiles_control_amount_i", "0", "How often the item (Controlling Missile) can be bought per round as an innocent (0 - Disabled).");
    g_cCountCT = AutoExecConfig_CreateConVar("missiles_control_amount_t", "2", "How often the item (Controlling Missile) can be bought per round as a traitor (0 - Disabled).");
    g_cCountCD = AutoExecConfig_CreateConVar("missiles_control_amount_d", "0", "How often the item (Controlling Missile) can be bought per round as a detective (0 - Disabled).");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_Reset);
    HookEvent("player_death", Event_Reset);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_I);
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
        TTT_RemoveShopItem(SHORT_NAMEF_I);
        TTT_RemoveShopItem(SHORT_NAMEF_T);
        TTT_RemoveShopItem(SHORT_NAMEF_D);
        TTT_RemoveShopItem(SHORT_NAMEC_I);
        TTT_RemoveShopItem(SHORT_NAMEC_T);
        TTT_RemoveShopItem(SHORT_NAMEC_D);
    }
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
    
    TTT_OnShopReady();
}

public void TTT_OnShopReady()
{
    char sName[32];

    g_cName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME_I, sName, g_cPriceD.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD.IntValue, g_cCountI.IntValue, g_cLimitD.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_T, sName, g_cPriceT.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT.IntValue, g_cCountT.IntValue, g_cLimitT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sName, g_cPriceI.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI.IntValue, g_cCountD.IntValue, g_cLimitI.IntValue, OnItemPurchased);
    
    g_cName_F.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAMEF_I, sName, g_cPriceD_F.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD_F.IntValue, g_cCountFI.IntValue, g_cLimitD_F.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAMEF_T, sName, g_cPriceT_F.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT_F.IntValue, g_cCountFT.IntValue, g_cLimitT_F.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAMEF_D, sName, g_cPriceI_F.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI_F.IntValue, g_cCountFD.IntValue, g_cLimitI_F.IntValue, OnItemPurchased);

    g_cName_C.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAMEC_I, sName, g_cPriceD_C.IntValue, TTT_TEAM_DETECTIVE, g_cPriorityD_C.IntValue, g_cCountCI.IntValue, g_cLimitD_C.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAMEC_T, sName, g_cPriceT_C.IntValue, TTT_TEAM_TRAITOR, g_cPriorityT_C.IntValue, g_cCountCT.IntValue, g_cLimitT_C.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAMEC_D, sName, g_cPriceI_C.IntValue, TTT_TEAM_INNOCENT, g_cPriorityI_C.IntValue, g_cCountCD.IntValue, g_cLimitI_C.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (StrEqual(itemshort, SHORT_NAME_I, false) || StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
    {
        GiveMissile(client);
        GiveGrenade(client);

        TTT_AddItemUsage(client, itemshort);
        
    }
    else if (StrEqual(itemshort, SHORT_NAMEF_I, false) || StrEqual(itemshort, SHORT_NAMEF_T, false) || StrEqual(itemshort, SHORT_NAMEF_D, false))
    {
        GiveFollowingMissile(client);
        GiveGrenade(client);

        TTT_AddItemUsage(client, itemshort);
    }
    else if (StrEqual(itemshort, SHORT_NAMEC_I, false) || StrEqual(itemshort, SHORT_NAMEC_T, false) || StrEqual(itemshort, SHORT_NAMEC_D, false))
    {
        GiveControlMissile(client);
        GiveGrenade(client);

        TTT_AddItemUsage(client, itemshort);
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
    
    if ((!g_iPlayer[iOwner].Missile && !g_iPlayer[iOwner].FollowingMissile && !g_iPlayer[iOwner].ControlMissile) || g_iPlayer[iOwner].Type != tNone)
    {
        return;
    }
        
    if(g_iPlayer[iOwner].ControlMissile)
    {
        g_iPlayer[iOwner].ControlMissile--;
        g_iPlayer[iOwner].Type = tControl;
    }
    else if(g_iPlayer[iOwner].FollowingMissile)
    {
        g_iPlayer[iOwner].FollowingMissile--;
        g_iPlayer[iOwner].Type = tFollow;
    }
    else
    {
        g_iPlayer[iOwner].Missile--;
        g_iPlayer[iOwner].Type = tNormal;

        GetClientEyeAngles(iOwner, g_iPlayer[iOwner].Location);
        g_iPlayer[iOwner].Location[1] - 90.0;
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
    if (g_iPlayer[iOwner].Type != tNormal)
    {
        TeleportEntity(caller, NULL_VECTOR, fInitAng, fInitVec);
    }
    else
    {
        TeleportEntity(caller, NULL_VECTOR, g_iPlayer[iOwner].Location, fInitVec);
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
    
    if(g_iPlayer[iOwner].Type == tControl)
    {
        g_iPlayer[iOwner].MissileEntity = caller;
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

    if (g_iPlayer[iOwner].Type == tNormal)
    {
        TeleportEntity(caller, NULL_VECTOR, g_iPlayer[iOwner].Location, NULL_VECTOR);
    }
    else if (g_iPlayer[iOwner].Type == tFollow)
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
    else if (g_iPlayer[iOwner].Type == tControl)
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
        if (TTT_IsPlayerAlive(i) && g_iPlayer[i].MissileEntity != -1 && IsValidEntity(g_iPlayer[i].MissileEntity))
        {
            float fclientAngles[3];
            GetClientEyeAngles(i, fclientAngles);
            TeleportEntity(g_iPlayer[i].MissileEntity, NULL_VECTOR, fclientAngles, NULL_VECTOR);
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
    
    if(g_iPlayer[iMissileOwner].Type == tControl)
    {
        SetClientViewEntity(iMissileOwner, iMissileOwner);
        g_iPlayer[iMissileOwner].MissileEntity = -1;
    }

    g_iPlayer[iMissileOwner].Type = tNone;
    
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
    g_iPlayer[client].Missile++;
    g_iPlayer[client].MissileAmount++;
}

void GiveControlMissile(int client)
{
    g_iPlayer[client].ControlMissile++;
    g_iPlayer[client].ControlAmount++;
}

void GiveFollowingMissile(int client)
{
    g_iPlayer[client].FollowingMissile++;
    g_iPlayer[client].FollowingAmount++;
}

void GiveGrenade(int client)
{
    int iAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", 4, 11);
    
    if (!iAmmo)
    {
        GivePlayerItem(client, "weapon_hegrenade");
    }
    
    if (iAmmo)
    {
        SetEntProp(client, Prop_Send, "m_iAmmo", g_iPlayer[client].Missile + g_iPlayer[client].FollowingMissile, 4, 11);
    }
}

void ResetClient(int client)
{
    if(g_iPlayer[client].Type == tControl || g_iPlayer[client].MissileEntity != -1)
    {
        SetClientViewEntity(client, client);
    }
    
    g_iPlayer[client].MissileAmount = 0;
    g_iPlayer[client].Missile = 0;
    g_iPlayer[client].FollowingAmount = 0;
    g_iPlayer[client].FollowingMissile = 0;
    g_iPlayer[client].ControlAmount = 0;
    g_iPlayer[client].ControlMissile = 0;
    g_iPlayer[client].MissileEntity = -1;
    g_iPlayer[client].Type = tNone;
}

