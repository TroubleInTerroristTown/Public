#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new FreezeSpeed = 500;
new RemoveSpeed = 4000;

new FreezeTime = 3;

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "prop_ragdoll"))
		SDKHook(entity, SDKHook_SpawnPost, Spawned);
}

public Spawned(entity)
{
	SDKHook(entity, SDKHook_Think, OnThink);
}

public OnEntityDestroyed(entity)
{
	if(!IsValidEdict(entity) || !IsValidEntity(entity))
		return;
	
	decl String:classname[128];
	GetEdictClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "prop_ragdoll"))
		SDKUnhook(entity, SDKHook_Think, OnThink);
}

public OnThink(entity)
{
	decl Float:fVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
	new Float:speed = GetVectorLength(fVelocity);
	if(speed >= RemoveSpeed)
		RemoveEdict(entity);
	else if(speed >= FreezeSpeed)
		if(!(GetEntityFlags(entity) & FL_FROZEN))
			KillVelocity(entity);
}

KillVelocity(entity)
{
	new flags = GetEntityFlags(entity);
	SetEntityFlags(entity, flags|FL_FROZEN);
	CreateTimer(FreezeTime * 1.0, Restore, EntIndexToEntRef(entity));
}

public Action:Restore(Handle:timer, any:ref2)
{
	new entity = EntRefToEntIndex(ref2);
	if(entity != INVALID_ENT_REFERENCE)
	{
		if(GetEntityFlags(entity) & FL_FROZEN)
		{
			new flags = GetEntityFlags(entity);
			SetEntityFlags(entity, flags&~FL_FROZEN);
		}
	}
}