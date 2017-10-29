#pragma semicolon 1

#define PLUGIN_VERSION "1.3.1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

public Plugin myinfo = 
{
	name = "No Weapon Fix",
	author = ".#Zipcore",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define LoopIngamePlayers(%1) for(int %1=1;%1<=MaxClients;++%1)\
if(IsClientInGame(%1) && !IsFakeClient(%1))

#define EF_NODRAW 32

int g_iFakeWeaponRef[MAXPLAYERS + 1];

ConVar cvEnable;
bool g_bEnable;

public void OnPluginStart()
{
	CreateConVar("no_weapon_fix_version", PLUGIN_VERSION, "No Weapon Fix Version", FCVAR_DONTRECORD|0|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	cvEnable = CreateConVar("no_weapon_fix_enable", "1", "Set to 0 to disable this plugin.");
	g_bEnable = GetConVarBool(cvEnable);
	HookConVarChange(cvEnable, OnSettingChanged);
	
	LoopIngamePlayers(client)
		OnClientPutInServer(client);
}

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == cvEnable)
		g_bEnable = view_as<bool>(StringToInt(newValue));
}

public void OnClientPutInServer(int client)
{
	g_iFakeWeaponRef[client] = 0;
	
	SDKHook(client, SDKHook_WeaponEquip, WeaponSwitch);
	SDKHook(client, SDKHook_WeaponDrop, WeaponDrop);
}

public Action WeaponSwitch(int client, int weapon)
{
	int iEntity = EntRefToEntIndex(g_iFakeWeaponRef[client]);
	if(IsValidEntity(weapon) && weapon != iEntity && iEntity > MaxClients && iEntity != INVALID_ENT_REFERENCE)
	{
		RemovePlayerItem(client, iEntity);
		AcceptEntityInput(iEntity, "Kill");
	}
	return Plugin_Continue;
}

public Action WeaponDrop(int client, int weapon)
{
	int iEntity = EntRefToEntIndex(g_iFakeWeaponRef[client]);
	if(IsValidEntity(weapon) && weapon == iEntity)
		AcceptEntityInput(iEntity, "Kill");
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!g_bEnable || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	int iEntity = EntRefToEntIndex(g_iFakeWeaponRef[client]);
	if (iEntity > MaxClients)
	{
		float fUnlockTime = GetGameTime() + 0.5;
		
		SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 0);
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", fUnlockTime);
		SetEntPropFloat(iEntity, Prop_Send, "m_flNextPrimaryAttack", fUnlockTime);
	}
	else SetEntProp(client, Prop_Data, "m_bDrawViewmodel", 1);
	
	if(weapon <= 0)
		weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon <= 0 && iEntity <= 0)
	{
		int iWeapon = GivePlayerItem(client, "weapon_decoy");
		
		float fUnlockTime = GetGameTime() + 0.5;
		
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", fUnlockTime);
		SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fUnlockTime);
	
		g_iFakeWeaponRef[client] = EntIndexToEntRef(iWeapon);
		return Plugin_Continue;
	}
  	
  	return Plugin_Continue;
}