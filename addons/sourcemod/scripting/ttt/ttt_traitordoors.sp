#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Doors"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "zipcore",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	CreateConVar("ttt2_traitor_door_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	
	HookEvent("round_start", Event_OnRoundStart);
}

public void OnMapStart()
{
	SetupDoors();
}

public Action Event_OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetupDoors();

	return Plugin_Continue;
}

Handle g_aDoors = null;

stock void SetupDoors()
{
	if (g_aDoors == null)
	{
		g_aDoors = CreateArray(1);
	}
	else
	{
		ClearArray(g_aDoors);
	}

	int maxent = GetMaxEntities();
	char sClass[64];
	char sName[64];
	for (int i = MaxClients; i < maxent; i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i))
		{
			GetEdictClassname(i, sClass, sizeof(sClass));
			GetEntPropString(i, Prop_Data, "m_iName", sName, sizeof(sName));

			if (StrContains(sClass, "_door", false) != -1 && StrContains(sName, "traitor", false) != -1)
			{
				AcceptEntityInput(i, "Lock");

				HookSingleEntityOutput(i, "OnLockedUse", OnLockedUse);
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if (!(buttons & IN_USE))
	{
		return Plugin_Continue;
	}

	if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
	{
		return Plugin_Continue;
	}

	int target = GetClientAimTarget(client, false);

	if (!IsValidEntity(target) || !IsValidEdict(target))
	{
		return Plugin_Continue;
	}

	char sClass[64];
	char sName[64];
	GetEdictClassname(target, sClass, sizeof(sClass));
	GetEntPropString(target, Prop_Data, "m_iName", sName, sizeof(sName));

	if (StrContains(sClass, "_door", false) != -1 && StrContains(sName, "traitor", false) != -1)
	{
		AcceptEntityInput(target, "Unlock");
		AcceptEntityInput(target, "Open");
		AcceptEntityInput(target, "Lock");
	}

  	return Plugin_Continue;
}

public int OnLockedUse(const char[] output, int caller, int attacker, float data)
{
	if (TTT_GetClientRole(attacker) != TTT_TEAM_TRAITOR)
	{
		return;
	}

	AcceptEntityInput(caller, "Unlock");
	AcceptEntityInput(caller, "Open");
	AcceptEntityInput(caller, "Lock");
}
