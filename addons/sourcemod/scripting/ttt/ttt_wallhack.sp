#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <CustomPlayerSkins>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "wh"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: " ... LONG_NAME

int g_iTraitorPrice;
int g_iDetectivePrice;

float g_fTraitorCooldown;
float g_fDetectiveCooldown;

float g_fTraitorActive;
float g_fDetectiveActive;

bool g_bOwnWH[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasWH[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH];

Handle g_hTimer[MAXPLAYERS + 1] =  { null, ... };

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
	CreateNative("TTT_Wallhack", Native_Wallhack);
	RegPluginLibrary("ttt_wallhack");
	return APLRes_Success;
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
	
	Config_Done();
	
	HookEvent("player_death", Event_PlayerReset);
	HookEvent("player_spawn", Event_PlayerReset);
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iTraitorPrice, TTT_TEAM_TRAITOR);
	TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iDetectivePrice, TTT_TEAM_DETECTIVE);
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
	{
		g_bHasWH[client] = false;
		g_bOwnWH[client] = false;
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false))
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR && TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE)
					return Plugin_Stop;
			
			g_bHasWH[client] = true;
			g_bOwnWH[client] = true;
			
			if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
				g_hTimer[client] = CreateTimer(g_fTraitorActive, Timer_WHActive, GetClientUserId(client));
			else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				g_hTimer[client] = CreateTimer(g_fDetectiveActive, Timer_WHActive, GetClientUserId(client));
		}
	}
	return Plugin_Continue;
}

public Action Timer_WHActive(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client) && g_bOwnWH[client] && g_bHasWH[client])
	{
		g_bHasWH[client] = false;
		g_hTimer[client] = null;
		
		if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			g_hTimer[client] = CreateTimer(g_fTraitorCooldown, Timer_WHCooldown, GetClientUserId(client));
		else if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
			g_hTimer[client] = CreateTimer(g_fDetectiveCooldown, Timer_WHCooldown, GetClientUserId(client));
	}
	
	return Plugin_Stop;
}

public Action Timer_WHCooldown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client) && g_bOwnWH[client] && !g_bHasWH[client])
	{
		g_bHasWH[client] = true;
		g_hTimer[client] = null;
		
		if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			g_hTimer[client] = CreateTimer(g_fTraitorActive, Timer_WHActive, GetClientUserId(client));
		else if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
			g_hTimer[client] = CreateTimer(g_fDetectiveActive, Timer_WHActive, GetClientUserId(client));
	}
	
	return Plugin_Stop;
}

public int Native_Wallhack(Handle plugin, int numParams)
{
	int target = GetNativeCell(1);
	
	if(g_bOwnWH[target] && g_bHasWH[target])
		return true;
	return false;
}

