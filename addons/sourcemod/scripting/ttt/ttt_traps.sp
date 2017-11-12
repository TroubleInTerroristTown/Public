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
	CreateTimer(0.5, Timer_AssignValues, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
}

public Action Timer_AssignValues(Handle timer) 
{
	AssignValues();
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
	AssignValues();
}

public void AssignValues() 
{
	LoopValidClients(i) {
		switch(TTT_GetClientRole(i))
		{
			case TTT_TEAM_TRAITOR:
				DispatchKeyValue(i, "targetname", "TRAITOR");
			case TTT_TEAM_DETECTIVE:
				DispatchKeyValue(i, "targetname", "DETECTIVE");
			case TTT_TEAM_INNOCENT:
				DispatchKeyValue(i, "targetname", "INNOCENT");
			case TTT_TEAM_UNASSIGNED:
				DispatchKeyValue(i, "targetname", "UNASSIGNED");
				
		}
	}
}
