#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#include <ttt>
#include <config_loader>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"

bool g_bEnableTVoice = false;
bool g_bTVoice[MAXPLAYERS + 1] =  { false, ... };
char g_sConfigFile[PLATFORM_MAX_PATH];

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/talk_override.cfg");
	Config_Setup("TTT-TalkOverride", g_sConfigFile);
	g_bEnableTVoice = Config_LoadBool("tor_traitor_voice_chat", true, "Enable traitor voice chat (command for players: sm_tvoice)?");
	Config_Done();
	
	RegConsoleCmd("sm_tvoice", Command_TVoice);
	
	HookEvent("player_death", Event_PlayerDeath);
	
	CreateTimer(1.0, Timer_OverrideListener, _, TIMER_REPEAT);
}

public Action Command_TVoice(int client, int args)
{
	if(client < 1)
		return Plugin_Handled;
	
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
	
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
		return Plugin_Handled;
	
	if(g_bTVoice[client])
	{
		PrintToChat(client, "Traitor Voice Chat: Disabled!");
		g_bTVoice[client] = false;
	}
	else
	{
		PrintToChat(client, "Traitor Voice Chat: Enabled!");
		g_bTVoice[client] = true;
	}
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	LoopValidClients(i)
		if(IsPlayerAlive(i))
			SetListenOverride(i, client, Listen_No);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	LoopValidClients(i)
		if(IsPlayerAlive(i))
			SetListenOverride(i, victim, Listen_No);
}

public void TTT_OnClientGetRole(int client, int role)
{
	LoopValidClients(i)
		if(role == TTT_TEAM_TRAITOR && g_bTVoice[client])
			SetListenOverride(i, client, Listen_Yes);
}

public Action Timer_OverrideListener(Handle timer)
{
	LoopValidClients(i)
	{
		if(IsFakeClient(i))
			continue;
		
		LoopValidClients(j)
		{
			if(IsFakeClient(j))
				continue;
			
			if(!TTT_IsRoundActive())
				SetListenOverride(i, j, Listen_Yes);
				
			else if(IsPlayerAlive(i) && TTT_GetClientRole(j) == TTT_TEAM_UNASSIGNED)
				SetListenOverride(i, j, Listen_No);
				
			else if(IsPlayerAlive(i) && !IsPlayerAlive(j))
				SetListenOverride(i, j, Listen_No);
				
			else if(!IsPlayerAlive(i) && IsPlayerAlive(j))
				SetListenOverride(i, j, Listen_Yes);
			
			else if(!IsPlayerAlive(i) && !IsPlayerAlive(j))
				SetListenOverride(i, j, Listen_Yes);
				
			else if(IsPlayerAlive(i) && IsPlayerAlive(j))
				SetListenOverride(i, j, Listen_Yes);
			
			if(g_bEnableTVoice && TTT_GetClientRole(j) == TTT_TEAM_TRAITOR && g_bTVoice[j])
			{
				if(TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
					SetListenOverride(i, j, Listen_Yes);
				else
					SetListenOverride(i, j, Listen_No);
			}
		}
	}
}