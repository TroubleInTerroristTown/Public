#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hide Radar"

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
	
	CreateConVar("ttt2_hide_radar_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);

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

	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", 1<<12);
	}
}

public Action Event_PlayerBlind(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) > 1)
	{
		float fDuration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
		CreateTimer(fDuration, RemoveRadar, userid);
	}
}
