#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#undef REQUIRE_EXTENSIONS
#tryinclude <vphysics>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Crash Catcher"

int FreezeSpeed = 500;
int RemoveSpeed = 4000;

int FreezeTime = 3;

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

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "prop_ragdoll"))
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
    if (!IsValidEdict(entity) || !IsValidEntity(entity))
    {
        return;
    }

    char classname[128];
    GetEdictClassname(entity, classname, sizeof(classname));
    if (StrEqual(classname, "prop_ragdoll"))
    {
        SDKUnhook(entity, SDKHook_Think, OnThink);
    }
}

public void OnThink(int entity)
{
    float fVelocity[3];
    GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
    float speed = GetVectorLength(fVelocity);
    if (speed >= RemoveSpeed)
    {
        RemoveEdict(entity);
    }
    else if (speed >= FreezeSpeed)
    {
        if (!(GetEntityFlags(entity) & FL_FROZEN))
        {
            KillVelocity(entity);
        }
    }
}

void KillVelocity(int entity)
{
    int flags = GetEntityFlags(entity);
    SetEntityFlags(entity, flags|FL_FROZEN);
    CreateTimer(FreezeTime * 1.0, Timer_Restore, EntIndexToEntRef(entity));
}

public Action Timer_Restore(Handle timer, any ref2)
{
    int entity = EntRefToEntIndex(ref2);
    if (entity != INVALID_ENT_REFERENCE)
    {
        if (GetEntityFlags(entity) & FL_FROZEN)
        {
            int flags = GetEntityFlags(entity);
            SetEntityFlags(entity, flags&~FL_FROZEN);
        }
    }
}

#if defined _sdktools_phys_included
public void Phys_OnObjectWake(int entity)
{
    if (IsValidEntity(entity))
    {
        char sClass[64];
        GetEntityClassname(entity, sClass, sizeof(sClass));

        if (StrEqual(sClass, "prop_ragdoll", false))
        {
            if (Phys_IsPhysicsObject(entity))
            {
                Phys_Sleep(entity);
            }
        }
    }
}
#endif