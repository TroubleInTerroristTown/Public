#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Hide Radar",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "git.tf/TTT"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_blind", Event_PlayerBlind, EventHookMode_Post);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.0, RemoveRadar, event.GetInt("userid"));
}

public Action RemoveRadar(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", 1<<12);
	}
}

public Action Event_PlayerBlind(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = userid;
	
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) > 1)
	{
		float fDuration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
		CreateTimer(fDuration, RemoveRadar, userid);
	}
}