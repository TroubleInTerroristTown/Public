#include <sourcemod>
#include <sdkhooks>
#include <ttt>
#include <CustomPlayerSkins>
#include <config_loader>

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow"

bool g_bDGlow = false;
bool g_bTGlow = false;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

bool g_bCPS = false;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara & zipcore",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/glow.cfg");

	Config_Setup("TTT-Glow", g_sConfigFile);
	
	g_bDGlow = Config_LoadBool("glow_detective_enable", true, "Detectives see the glows of other detectives. 0 to disable.");
	g_bTGlow = Config_LoadBool("glow_traitor_enable", true, "Traitors see the glows of other traitors. 0 to disable.");
	
	Config_Done();
	
	HookEvent("player_spawn", Event_PlayerReset);
	HookEvent("player_death", Event_PlayerReset);
	HookEvent("round_end", Event_RoundReset);
	
	g_bCPS = LibraryExists("CustomPlayerSkins");
	
	if (g_bCPS)
	{
		CreateTimer(0.5, Timer_SetupGlow, _, TIMER_REPEAT);
	}
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
	if (!g_bCPS)
	{
		SetFailState("CustomPlayerSkins not loaded!");
	}
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
			SDKUnhook(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin)
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
	if (!TTT_IsRoundActive())
	{
		return Plugin_Handled;
	}
	
	if (IsFakeClient(client) || IsClientSourceTV(client))
	{
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	if (!g_bDGlow && TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		return Plugin_Handled;
	}
	
	if (!g_bTGlow && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		return Plugin_Handled;
	}
	
	int target = -1;
	LoopValidClients(i)
	{
		if (target < 1)
		{
			continue;
		}
		
		if (client == target)
		{
			continue;
		}
			
		if (IsFakeClient(target))
		{
			continue;
		}
		
		if (!IsPlayerAlive(target))
		{
			continue;
		}
		
		if (!CPS_HasSkin(target))
		{
			continue;
		}
			
		if (EntRefToEntIndex(CPS_GetSkin(target)) != skin)
		{
			continue;
		}

		target = i;
	}
	
	if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE && TTT_GetClientRole(client) == TTT_GetClientRole(target))
	{
		return Plugin_Continue;
	}
	
	if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR && TTT_GetClientRole(client) == TTT_GetClientRole(target))
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}
