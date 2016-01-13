#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <config_loader>
#include <CustomPlayerSkins>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "wh"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Glow & " ... LONG_NAME

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

int g_iTraitorPrice;
int g_iDetectivePrice;

float g_fTraitorCooldown;
float g_fDetectiveCooldown;

float g_fTraitorActive;
float g_fDetectiveActive;

bool g_bOwnRadar[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasRadar[MAXPLAYERS + 1] =  { false, ... };

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

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/wh.cfg");

	Config_Setup("TTT-Wallhack", g_sConfigFile);
	
	g_iTraitorPrice = Config_LoadInt("wh_traitor_price", 9000, "The amount of credits the Traitor-Wallhack costs. 0 to disable.");
	g_iDetectivePrice = Config_LoadInt("wh_detective_price", 9000, "The amount of credits the Dective-Wallhack costs. 0 to disable.");
	
	g_fTraitorCooldown = Config_LoadFloat("wh_traitor_cooldown", 15.0, "Time of the cooldown for Traitor-Wallhack");
	g_fDetectiveCooldown = Config_LoadFloat("wh_detective_cooldown", 15.0, "Time of the cooldown for Dective-Wallhack");
	
	g_fTraitorActive = Config_LoadFloat("wh_traitor_active", 3.0, "Active time for Traitor-Wallhack");
	g_fDetectiveActive = Config_LoadFloat("wh_detective_active", 3.0, "Active time for Dective-Wallhack");
	
	StartGlowTimer();
}

void StartGlowTimer()
{
	PrintToServer("Called StartGlowTimer");
	CreateTimer(1.5, Timer_SetupGlow, _, TIMER_REPEAT);
}

public Action Timer_SetupGlow(Handle timer, any data)
{
	PrintToServer("Called Timer_SetGlow");
	LoopValidClients(client)
		if (IsPlayerAlive(client) && g_bHasRadar[client])
			SetupGlowSkin(client);
	
	return Plugin_Continue;
}


void SetupGlowSkin(int client)
{
	PrintToChat(client, "Called SetupGlowSkin");
	CPS_RemoveSkin(client);
	
	if(!TTT_IsRoundActive())
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));
	CPS_SetSkin(client, sModel, CPS_RENDER);
		
	int iSkin = CPS_GetSkin(client);
	
	if(iSkin == -1)
		return;
		
	PrintToChat(client, "Called SetupGlowSkin");
	
	SetupGlow(client, iSkin);
		
	SDKHookEx(iSkin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
		
}

void SetupGlow(int client, int iSkin)
{
	int iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow");
	
	if (iOffset == -1)
		return;
	
	SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", true, true);
	
	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		iRed = g_iColorDetective[0];
		iGreen = g_iColorDetective[1];
		iBlue = g_iColorDetective[2];
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		iRed = g_iColorTraitor[0];
		iGreen = g_iColorTraitor[1];
		iBlue = g_iColorTraitor[2];
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		iRed = g_iColorInnocent[0];
		iGreen = g_iColorInnocent[1];
		iBlue = g_iColorInnocent[2];
	}
	
	SetEntData(iSkin, iOffset, iRed, _, true);
	SetEntData(iSkin, iOffset + 1, iGreen, _, true);
	SetEntData(iSkin, iOffset + 2, iBlue, _, true);
	SetEntData(iSkin, iOffset + 3, 255, _, true);
}

public void OnAllPluginsLoaded()
{
	if(g_iTraitorPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iTraitorPrice, TTT_TEAM_TRAITOR);
	
	if(g_iDetectivePrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iDetectivePrice, TTT_TEAM_DETECTIVE);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(strcmp(itemshort, SHORT_NAME, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR && TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE)
					return Plugin_Stop;
			
			g_bHasRadar[client] = true;
			g_bOwnRadar[client] = true;
			
			PrintToChat(client, "Called TTT_OnItemPurchased! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
			
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
	PrintToServer("Called Timer_WHActive!");
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client) && g_bOwnRadar[client] && g_bHasRadar[client])
	{
		PrintToChat(client, "Called Timer_WHActive! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
		
		g_bHasRadar[client] = false;
		g_hTimer[client] = null;
		
		PrintToChat(client, "Called Timer_WHActive! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
		
		if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			g_hTimer[client] = CreateTimer(g_fTraitorCooldown, Timer_WHCooldown, GetClientUserId(client));
		else if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
			g_hTimer[client] = CreateTimer(g_fDetectiveCooldown, Timer_WHCooldown, GetClientUserId(client));
	}
	
	return Plugin_Stop;
}

public Action Timer_WHCooldown(Handle timer, any userid)
{
	PrintToServer("Called Timer_WHCooldown!");
	int client = GetClientOfUserId(userid);
	
	if(TTT_IsClientValid(client) && g_bOwnRadar[client] && !g_bHasRadar[client])
	{
		PrintToChat(client, "Called Timer_WHCooldown! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
		g_bHasRadar[client] = true;
		g_hTimer[client] = null;
		PrintToChat(client, "Called Timer_WHCooldown! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
		if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			g_hTimer[client] = CreateTimer(g_fTraitorActive, Timer_WHActive, GetClientUserId(client));
		else if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
			g_hTimer[client] = CreateTimer(g_fDetectiveActive, Timer_WHActive, GetClientUserId(client));
	}
	
	return Plugin_Stop;
}

public Action OnSetTransmit_GlowSkin(int iSkin, int client)
{
	if(IsFakeClient(client))
		return Plugin_Handled;
		
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
	
	if(!g_bOwnRadar[client] || !g_bHasRadar[client])
		return Plugin_Handled;
		
	int target = -1;
	LoopValidClients(i)
	{
		if(IsFakeClient(i)
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(!CPS_HasSkin(i))
			continue;
			
		if(EntRefToEntIndex(CPS_GetSkin(i)) != iSkin)
			continue;
			
		if(TTT_IsClientValid(i))
		{
			PrintToChat(client, "Spieler: %N", i);
			PrintToChat(client, "Called OnSetTransmit_GlowSkin! Own: %d Has: %d", g_bOwnRadar[client], g_bHasRadar[client]);
			return Plugin_Continue;
		}
	}
	
	return Plugin_Handled;
}
