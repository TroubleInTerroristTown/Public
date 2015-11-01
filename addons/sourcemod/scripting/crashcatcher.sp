#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#pragma newdecls required

int FreezeSpeed = 500;
int RemoveSpeed = 4000;

int FreezeTime = 3;

public Plugin myinfo =
{
	name = "Crash Catcher",
	author = "Franc1sco & Bara",
	description = "",
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

#if SOURCEMOD_V_MAJOR >= 1 && (SOURCEMOD_V_MINOR >= 8 || SOURCEMOD_V_MINOR >= 7 && SOURCEMOD_V_RELEASE >= 2)
public void OnEntityCreated(int entity, const char[] classname)
#else
public int OnEntityCreated(int entity, const char[] classname)
#endif
{
	if(StrEqual(classname, "prop_ragdoll"))
		SDKHook(entity, SDKHook_SpawnPost, Spawned);
}

public void Spawned(int entity)
{
	SDKHook(entity, SDKHook_Think, OnThink);
}

#if SOURCEMOD_V_MAJOR >= 1 && (SOURCEMOD_V_MINOR >= 8 || SOURCEMOD_V_MINOR >= 7 && SOURCEMOD_V_RELEASE >= 2)
public void OnEntityDestroyed(int entity)
#else
public int OnEntityDestroyed(int entity)
#endif
{
	if(!IsValidEdict(entity) || !IsValidEntity(entity))
		return;
	
	char classname[128];
	GetEdictClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "prop_ragdoll"))
		SDKUnhook(entity, SDKHook_Think, OnThink);
}

public void OnThink(int entity)
{
	float fVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
	float speed = GetVectorLength(fVelocity);
	if(speed >= RemoveSpeed)
		RemoveEdict(entity);
	else if(speed >= FreezeSpeed)
		if(!(GetEntityFlags(entity) & FL_FROZEN))
			KillVelocity(entity);
}

stock void KillVelocity(int entity)
{
	int flags = GetEntityFlags(entity);
	SetEntityFlags(entity, flags|FL_FROZEN);
	CreateTimer(FreezeTime * 1.0, Restore, EntIndexToEntRef(entity));
}

public Action Restore(Handle timer, any ref2)
{
	int entity = EntRefToEntIndex(ref2);
	if(entity != INVALID_ENT_REFERENCE)
	{
		if(GetEntityFlags(entity) & FL_FROZEN)
		{
			int flags = GetEntityFlags(entity);
			SetEntityFlags(entity, flags&~FL_FROZEN);
		}
	}
}