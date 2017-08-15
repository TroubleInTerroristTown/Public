#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <CustomPlayerSkins>
#include <multicolors>

#define SHORT_NAME_T "wallhack_t"
#define SHORT_NAME_D "wallhack_d"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: " ... LONG_NAME

int g_iTraitorPrice = -1;
int g_iDetectivePrice = -1;

int g_iTraitor_Prio = -1;
int g_iDetective_Prio = -1;

float g_fTraitorCooldown = -1.0;
float g_fDetectiveCooldown = -1.0;

float g_fTraitorActive = -1.0;
float g_fDetectiveActive = -1.0;

bool g_bOwnWH[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasWH[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH];

Handle g_hTimer[MAXPLAYERS + 1] =  { null, ... };

bool g_bCPS = false;
bool g_bGlow = false;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_HasActiveWallhack", Native_HasActiveWallhack);
	
	RegPluginLibrary("ttt_wallhack");

	return APLRes_Success;
}

public int Native_HasActiveWallhack(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bHasWH[client] && g_bOwnWH[client])
	{
		return true;
	}
	
	return false;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/wh.cfg");

	Config_Setup("TTT-Wallhack", g_sConfigFile);

	g_iTraitorPrice = Config_LoadInt("wh_traitor_price", 9000, "The amount of credits the Traitor-Wallhack costs. 0 to disable.");
	g_iDetectivePrice = Config_LoadInt("wh_detective_price", 9000, "The amount of credits the Dective-Wallhack costs. 0 to disable.");

	g_fTraitorCooldown = Config_LoadFloat("wh_traitor_cooldown", 15.0, "Time of the cooldown for Traitor-Wallhack (time in seconds)");
	g_fDetectiveCooldown = Config_LoadFloat("wh_detective_cooldown", 15.0, "Time of the cooldown for Dective-Wallhack (time in seconds)");

	g_fTraitorActive = Config_LoadFloat("wh_traitor_active", 3.0, "Active time for Traitor-Wallhack (time in seconds)");
	g_fDetectiveActive = Config_LoadFloat("wh_detective_active", 3.0, "Active time for Dective-Wallhack (time in seconds)");

	g_iTraitor_Prio = Config_LoadInt("wh_traitor_sort_prio", 0, "The sorting priority of the Traitor - Wallhack in the shop menu.");
	g_iDetective_Prio = Config_LoadInt("wh_detective_sort_prio", 0, "The sorting priority of the Detective - Wallhack in the shop menu.");

	Config_Done();
	
	HookEvent("player_spawn", Event_PlayerReset);
	HookEvent("player_death", Event_PlayerReset);
	HookEvent("round_end", Event_RoundReset);

	g_bCPS = LibraryExists("CustomPlayerSkins");
	g_bGlow = LibraryExists("ttt_glow");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = true;
	}
	
	if (StrEqual(name, "ttt_glow"))
	{
		g_bGlow = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = false;
	}
	
	if (StrEqual(name, "ttt_glow"))
	{
		g_bGlow = false;
	}
}

public void OnAllPluginsLoaded()
{
	if (g_bCPS && g_bGlow)
	{
		TTT_RegisterCustomItem(SHORT_NAME_T, LONG_NAME, g_iTraitorPrice, TTT_TEAM_TRAITOR, g_iTraitor_Prio);
		TTT_RegisterCustomItem(SHORT_NAME_D, LONG_NAME, g_iDetectivePrice, TTT_TEAM_DETECTIVE, g_iDetective_Prio);
	}
	else if (!g_bCPS)
	{
		SetFailState("CustomPlayerSkins not loaded!");
	}
	else if (!g_bGlow)
	{
		if (!LibraryExists("ttt_glow"))
		{
			SetFailState("TTT-Glow not loaded!");
		}
		else
		{
			g_bGlow = true;
		}
	}
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		g_bHasWH[client] = false;
		g_bOwnWH[client] = false;
	}
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
	LoopValidClients(client)
	{
		g_bHasWH[client] = false;
		g_bOwnWH[client] = false;
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR && TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE)
					return Plugin_Stop;

			g_bHasWH[client] = true;
			g_bOwnWH[client] = true;

			if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			{
				g_hTimer[client] = CreateTimer(g_fTraitorActive, Timer_WHActive, GetClientUserId(client));
			}
			else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
			{
				g_hTimer[client] = CreateTimer(g_fDetectiveActive, Timer_WHActive, GetClientUserId(client));
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_WHActive(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client) && g_bOwnWH[client] && g_bHasWH[client])
	{
		g_bHasWH[client] = false;
		g_hTimer[client] = null;

		if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		{
			g_hTimer[client] = CreateTimer(g_fTraitorCooldown, Timer_WHCooldown, GetClientUserId(client));
		}
		else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
		{
			g_hTimer[client] = CreateTimer(g_fDetectiveCooldown, Timer_WHCooldown, GetClientUserId(client));
		}
	}

	return Plugin_Stop;
}

public Action Timer_WHCooldown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client) && g_bOwnWH[client] && !g_bHasWH[client])
	{
		g_bHasWH[client] = true;
		g_hTimer[client] = null;

		if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		{
			g_hTimer[client] = CreateTimer(g_fTraitorActive, Timer_WHActive, GetClientUserId(client));
		}
		else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
		{
			g_hTimer[client] = CreateTimer(g_fDetectiveActive, Timer_WHActive, GetClientUserId(client));
		}
	}

	return Plugin_Stop;
}
