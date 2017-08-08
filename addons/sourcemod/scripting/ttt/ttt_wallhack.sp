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

#define SHORT_NAME_T "wh_t"
#define SHORT_NAME_D "wh_d"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: " ... LONG_NAME

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

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

bool g_bDebug = false;

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
	
	RegAdminCmd("sm_dwallhack", Command_DWallhack, ADMFLAG_ROOT);
	
	g_bCPS = LibraryExists("CustomPlayerSkins");
}

public Action Command_DWallhack(int client, int args)
{
	if (g_bDebug)
		g_bDebug = false;
	else
		g_bDebug = true;
	
	PrintToChat(client, "Debug: %d", g_bDebug);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = false;
	}
}

public void OnAllPluginsLoaded()
{
	if (g_bCPS)
	{
		TTT_RegisterCustomItem(SHORT_NAME_T, LONG_NAME, g_iTraitorPrice, TTT_TEAM_TRAITOR, g_iTraitor_Prio);
		TTT_RegisterCustomItem(SHORT_NAME_D, LONG_NAME, g_iDetectivePrice, TTT_TEAM_DETECTIVE, g_iDetective_Prio);
		
		CreateTimer(0.5, Timer_SetupGlow, _, TIMER_REPEAT);
	}
	else
	{
		SetFailState("CustomPlayerSkins not loaded!");
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
			
			if (g_bDebug && CheckCommandAccess(client, "sm_dwallhack", ADMFLAG_ROOT, true)) PrintToChat(client, "TTT_OnItemPurchased");
			
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
		if (g_bDebug && CheckCommandAccess(client, "sm_dwallhack", ADMFLAG_ROOT, true)) PrintToChat(client, "WH deactived...");
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
		if (g_bDebug && CheckCommandAccess(client, "sm_dwallhack", ADMFLAG_ROOT, true)) PrintToChat(client, "WH actived...");
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

public Action Timer_SetupGlow(Handle timer, any data)
{
	if(!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}
	
	LoopValidClients(i)
	{
		if (!IsPlayerAlive(i))
		{
			continue;
		}
		
		SetupGlowSkin(i);
	}
	
	return Plugin_Continue;
}

void SetupGlowSkin(int client)
{
	UnHookSkin(client);
	CPS_RemoveSkin(client);
	
	if (!TTT_IsRoundActive())
	{
		return;
	}
	
	if (IsFakeClient(client) || IsClientSourceTV(client))
	{
		return;
	}
	
	if (!IsPlayerAlive(client))
	{
		return;
	}
	
	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof(model));
	int skin = CPS_SetSkin(client, model, CPS_RENDER);
	
	if(skin == -1)
	{
		return;
	}
	if (SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
	{
		SetupGlow(client, skin);
	}
}

void UnHookSkin(int client)
{
	if(CPS_HasSkin(client))
	{
		int skin = EntRefToEntIndex(CPS_GetSkin(client));
		
		if(IsValidEntity(skin))
		{
			SDKUnhook(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
		}
	}
}

void SetupGlow(int client, int skin)
{
	int iOffset;
	
	if ((iOffset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
	{
		return;
	}
	
	SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(skin, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	
	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;
	
	if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		iRed = g_iColorDetective[0];
		iGreen = g_iColorDetective[1];
		iBlue = g_iColorDetective[2];
	}
	else if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		iRed = g_iColorTraitor[0];
		iGreen = g_iColorTraitor[1];
		iBlue = g_iColorTraitor[2];
	}
	else if (TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		iRed = g_iColorInnocent[0];
		iGreen = g_iColorInnocent[1];
		iBlue = g_iColorInnocent[2];
	}
	
	SetEntData(skin, iOffset, iRed, _, true);
	SetEntData(skin, iOffset + 1, iGreen, _, true);
	SetEntData(skin, iOffset + 2, iBlue, _, true);
	SetEntData(skin, iOffset + 3, 255, _, true);
}

public Action OnSetTransmit_GlowSkin(int skin, int client)
{
	LoopValidClients(i)
	{
		if (i < 1)
		{
			continue;
		}
		
		if (client == i)
		{
			continue;
		}
		
		if (IsFakeClient(i))
		{
			continue;
		}
		
		if (!IsPlayerAlive(i))
		{
			continue;
		}
		
		if (!CPS_HasSkin(i))
		{
			continue;
		}
		
		if (EntRefToEntIndex(CPS_GetSkin(i)) != skin)
		{
			continue;
		}
	}
	
	if (g_bHasWH[client] && g_bOwnWH[client])
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}
