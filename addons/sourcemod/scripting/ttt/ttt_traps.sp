#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Traps"

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = TTT_PLUGIN_AUTHOR ... ", R3TROATTACK",
	description = TTT_PLUGIN_DESCRIPTION, 
	version = TTT_PLUGIN_VERSION, 
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();
}

// Re-assign values on round start to make sure if a traitor needs to open a door or use a trap, they can.
public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
	LoopValidClients(client) {
		AssignValues(client);
	}
}

public void TTT_OnUpdate1(int client) 
{
	AssignValues(client);
}

public void AssignValues(int client) 
{
	switch(TTT_GetClientRole(client))
	{
		case TTT_TEAM_TRAITOR:
			DispatchKeyValue(client, "targetname", "TRAITOR");
		case TTT_TEAM_DETECTIVE:
			DispatchKeyValue(client, "targetname", "DETECTIVE");
		case TTT_TEAM_INNOCENT:
			DispatchKeyValue(client, "targetname", "INNOCENT");
		case TTT_TEAM_UNASSIGNED:
			DispatchKeyValue(client, "targetname", "UNASSIGNED");
				
	}
}
