#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#undef REQUIRE_EXTENSIONS
#include <vphysics>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Crash Catcher"

int g_iFreezeSpeed = 500;
int g_iRemoveSpeed = 4000;
float g_fFreezeTime = 3.0;

ConVar g_cSpawnType = null;

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
    
    CreateConVar("ttt2_crashcatcher_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
}

public void OnConfigsExecuted()
{
    g_cSpawnType = FindConVar("ttt_spawn_type");
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (g_cSpawnType == null)
    {
        g_cSpawnType = FindConVar("ttt_spawn_type");
    }

    if (g_cSpawnType != null && g_cSpawnType.IntValue == 0 && StrEqual(classname, "prop_ragdoll"))
    {
        SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
    }
}

public void OnSpawnPost(int entity)
{
    SDKHook(entity, SDKHook_Think, OnThink);
}

public void OnEntityDestroyed(int entity)
{
    if (g_cSpawnType == null)
    {
        g_cSpawnType = FindConVar("ttt_spawn_type");
    }

    if (g_cSpawnType != null && g_cSpawnType.IntValue != 0)
    {
        return;
    }

    if (!IsValidEntity(entity) || !IsValidEdict(entity))
    {
        return;
    }

    char sClassname[128];
    GetEdictClassname(entity, sClassname, sizeof(sClassname));
    if (StrEqual(sClassname, "prop_ragdoll"))
    {
        SDKUnhook(entity, SDKHook_Think, OnThink);
    }
}

public void OnThink(int entity)
{
    float fVelocity[3];
    GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);

    float fSpeed = GetVectorLength(fVelocity);

    if (fSpeed >= g_iRemoveSpeed)
    {
        RemoveEdict(entity);
    }
    else if (fSpeed >= g_iFreezeSpeed)
    {
        if (!(GetEntityFlags(entity) & FL_FROZEN))
        {
            KillVelocity(entity);
        }
    }
}

void KillVelocity(int entity)
{
    int iFlags = GetEntityFlags(entity);
    SetEntityFlags(entity, iFlags|FL_FROZEN);
    CreateTimer(g_fFreezeTime, Timer_Restore, EntIndexToEntRef(entity));
}

public Action Timer_Restore(Handle timer, any ref)
{
    int iEntity = EntRefToEntIndex(ref);

    if (IsValidEntity(iEntity))
    {
        if (GetEntityFlags(iEntity) & FL_FROZEN)
        {
            int iFlags = GetEntityFlags(iEntity);
            SetEntityFlags(iEntity, iFlags&~FL_FROZEN);
        }
    }
    
    return Plugin_Handled;
}

public void Phys_OnObjectWake(int entity)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }
    
    if (g_cSpawnType == null)
    {
        g_cSpawnType = FindConVar("ttt_spawn_type");
    }

    if (g_cSpawnType != null && g_cSpawnType.IntValue != 0)
    {
        return;
    }

    if (IsValidEntity(entity))
    {
        char sClassname[64];
        GetEntityClassname(entity, sClassname, sizeof(sClassname));

        if (StrEqual(sClassname, "prop_ragdoll", false))
        {
            if (Phys_IsPhysicsObject(entity))
            {
                Phys_Sleep(entity);
            }
        }
    }
}
