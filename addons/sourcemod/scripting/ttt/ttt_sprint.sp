#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Sprint"
#define SHORT_NAME_D "sprint_d"
#define SHORT_NAME_T "sprint_d"

int g_iPriceD = 0;
int g_iPriceT = 0;
int g_iPrioD = 0;
int g_iPrioT = 0;

float g_fNormal = 0.0;
float g_fSpeed = 0.0;
float g_fTime = 0.0;
float g_fCooldown = 0.0;

bool g_bHasItem[MAXPLAYERS + 1] =  { false, ... };

Handle g_hTimer[MAXPLAYERS + 1] =  { null, ... };
Handle g_hCTimer[MAXPLAYERS + 1] =  { null, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

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

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/sprint.cfg");
	Config_Setup("TTT-Sprint", g_sConfigFile);

	Config_LoadString("sprint_name", "Sprint", "The name of this in Shop", g_sLongName, sizeof(g_sLongName));
	g_iPriceD = Config_LoadInt("sprint_price_detective", 9000, "The amount of credits sprint costs as detective. 0 to disable.");
	g_iPriceT = Config_LoadInt("sprint_price_traitor", 9000, "The amount of credits sprint costs as traitor. 0 to disable.");
	g_iPrioD = Config_LoadInt("sprint_sort_prio_detective", 0, "The sorting priority of the sprint in the shop menu for detectives.");
	g_iPrioT = Config_LoadInt("sprint_sort_prio_traitor", 0, "The sorting priority of the sprint in the shop menu for traitors.");
	
	g_fNormal = Config_LoadFloat("sprint_normal_speed", 1.0, "Float value of default speed");
	g_fSpeed = Config_LoadFloat("sprint_speed", 1.33, "Float value of sprint speed (X.33 = 33%)");
	g_fTime = Config_LoadFloat("sprint_speed_time", 3.0, "Time in seconds with speed");
	g_fCooldown = Config_LoadFloat("sprint_cooldown_time", 7.0, "Time in seconds until next speed boost");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);
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

			g_bHasItem[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (g_hCTimer[client] != null || g_hTimer[client] != null)
		{
			return Plugin_Continue;
		}
		
		if(buttons & IN_USE)
		{
			g_hTimer[client] = CreateTimer(g_fTime, Timer_Sprint, GetClientUserId(client));
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fSpeed);
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
			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_fNormal);
			
			if(g_hCTimer[client] == null)
			{
				g_hCTimer[client] = CreateTimer(g_fCooldown, Timer_Cooldown, GetClientUserId(client));
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

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME_D, g_sLongName, g_iPriceT, TTT_TEAM_DETECTIVE, g_iPrioD);
	TTT_RegisterCustomItem(SHORT_NAME_T, g_sLongName, g_iPriceD, TTT_TEAM_TRAITOR, g_iPrioT);
}

void ResetSprint(int client)
{
	g_hTimer[client] = null;
	g_hCTimer[client] = null;
	g_bHasItem[client] = false;
}
