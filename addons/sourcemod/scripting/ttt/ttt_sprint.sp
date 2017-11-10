#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Sprint"
#define SHORT_NAME_D "sprint_d"
#define SHORT_NAME_T "sprint_d"

ConVar g_cPriceD = null;
ConVar g_cPriceT = null;
ConVar g_cPrioD = null;
ConVar g_cPrioT = null;
ConVar g_cNormal = null;
ConVar g_cSpeed = null;
ConVar g_cTime = null;
ConVar g_cCooldown = null;
ConVar g_cLongName = null;

Handle g_hTimer[MAXPLAYERS + 1] =  { null, ... };
Handle g_hCTimer[MAXPLAYERS + 1] =  { null, ... };


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

	LoadTranslations("ttt.phrases");

	StartConfig("sprint");
	CreateConVar("ttt2_sprint_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("sprint_name", "Sprint", "The name of this in Shop");
	g_cPriceD = AutoExecConfig_CreateConVar("sprint_price_detective", "9000", "The amount of credits sprint costs as detective. 0 to disable.");
	g_cPriceT = AutoExecConfig_CreateConVar("sprint_price_traitor", "9000", "The amount of credits sprint costs as traitor. 0 to disable.");
	g_cPrioD = AutoExecConfig_CreateConVar("sprint_sort_prio_detective", "0", "The sorting priority of the sprint in the shop menu for detectives.");
	g_cPrioT = AutoExecConfig_CreateConVar("sprint_sort_prio_traitor", "0", "The sorting priority of the sprint in the shop menu for traitors.");
	g_cNormal = AutoExecConfig_CreateConVar("sprint_normal_speed", "1.0", "Float value of default speed");
	g_cSpeed = AutoExecConfig_CreateConVar("sprint_speed", "1.33", "Float value of sprint speed (X.33 = 33%)");
	g_cTime = AutoExecConfig_CreateConVar("sprint_speed_time", "3.0", "Time in seconds with speed");
	g_cCooldown = AutoExecConfig_CreateConVar("sprint_cooldown_time", "7.0", "Time in seconds until next speed boost");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cPriceT.IntValue, TTT_TEAM_DETECTIVE, g_cPrioD.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cPriceD.IntValue, TTT_TEAM_TRAITOR, g_cPrioT.IntValue);
}

public void OnClientDisconnect(int client)
{
	ResetSprint(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_D, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_DETECTIVE && role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (g_hTimer[client] == null)
		{
			if (GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue") != g_cNormal.FloatValue)
			{
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_cNormal.FloatValue);
			}
			
			return Plugin_Continue;
		}
		
		if(buttons & IN_USE && g_hTimer[client] == null && g_hCTimer[client] == null)
		{
			g_hTimer[client] = CreateTimer(g_cTime.FloatValue, Timer_Sprint, GetClientUserId(client));
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_cSpeed.FloatValue);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_Sprint(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client))
	{
		if (IsPlayerAlive(client))
		{
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_cNormal.FloatValue);
			
			if(g_hCTimer[client] == null)
			{
				g_hCTimer[client] = CreateTimer(g_cCooldown.FloatValue, Timer_Cooldown, GetClientUserId(client));
			}
		}
		
		g_hTimer[client] = null;
	}
	
	return Plugin_Stop;
}

public Action Timer_Cooldown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client))
	{
		g_hCTimer[client] = null;
	}
	
	return Plugin_Stop;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetSprint(client);
	}
}

void ResetSprint(int client)
{
	g_hTimer[client] = null;
	g_hCTimer[client] = null;
}
