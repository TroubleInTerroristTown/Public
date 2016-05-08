#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Overlays"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

char g_sTraitorIcon[PLATFORM_MAX_PATH] = "";
char g_sDetectiveIcon[PLATFORM_MAX_PATH] = "";
char g_sInnocentIcon[PLATFORM_MAX_PATH] = "";
char g_sConfigFile[PLATFORM_MAX_PATH] = "";

char g_soverlayDWin[PLATFORM_MAX_PATH] = "";
char g_soverlayTWin[PLATFORM_MAX_PATH] = "";
char g_soverlayIWin[PLATFORM_MAX_PATH] = "";

bool g_bEndwithD;
bool g_bEndOverlay = false;

float g_fDelay;

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	g_bEndwithD = Config_LoadBool("ttt_end_with_detective", false, "Allow the round to end if Detectives remain alive. 0 = Disabled (default). 1 = Enabled.");
	g_fDelay = Config_LoadFloat("ttt_after_round_delay", 7.0, "The amount of seconds to use for round-end delay. Use 0.0 for default.");
	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/overlay.cfg");
	Config_Setup("TTT-Overlay", g_sConfigFile);
	
	Config_LoadString("ttt_overlay_detective", "darkness/ttt/overlayDetective", "The overlay to display for detectives during the round.", g_sDetectiveIcon, sizeof(g_sDetectiveIcon));
	Config_LoadString("ttt_overlay_traitor", "darkness/ttt/overlayTraitor", "The overlay to display for detectives during the round.", g_sTraitorIcon, sizeof(g_sTraitorIcon));
	Config_LoadString("ttt_overlay_inno", "darkness/ttt/overlayInnocent", "The overlay to display for detectives during the round.", g_sInnocentIcon, sizeof(g_sInnocentIcon));
	
	Config_LoadString("ttt_overlay_detective_win", "overlays/ttt/detectives_win", "The overlay to display when detectives win.", g_soverlayDWin, sizeof(g_soverlayDWin));
	Config_LoadString("ttt_overlay_traitor_win", "overlays/ttt/traitors_win", "The overlay to display when traitors win.", g_soverlayTWin, sizeof(g_soverlayTWin));
	Config_LoadString("ttt_overlay_inno_win", "overlays/ttt/innocents_win", "The overlay to display when innocent win.", g_soverlayIWin, sizeof(g_soverlayIWin));
	
	Config_Done();

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sDetectiveIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sDetectiveIcon);
	AddFileToDownloadsTable(g_sDetectiveIcon);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sDetectiveIcon);
	PrecacheDecal(sBuffer, true);
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sTraitorIcon);
	PrecacheDecal(sBuffer, true);
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sInnocentIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sInnocentIcon);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sInnocentIcon);
	PrecacheDecal(sBuffer, true);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayTWin);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayTWin);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayTWin);
	PrecacheDecal(sBuffer, true);
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayIWin);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayIWin);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayIWin);
	PrecacheDecal(sBuffer, true);

	if(g_bEndwithD)
	{
		Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayDWin);
		AddFileToDownloadsTable(sBuffer);

		Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayDWin);
		AddFileToDownloadsTable(sBuffer);
		
		Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayDWin);
		PrecacheDecal(g_soverlayDWin, true);
	}

}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ShowOverlayToAll("");
}

public void TTT_OnRoundEnd(int winner)
{
	if(g_fDelay > 0.0)
	{
		g_bEndOverlay = true;
		CreateTimer(g_fDelay, Delay_Timer);
	}
	
	if(!g_bEndwithD)
		if(winner == TTT_TEAM_DETECTIVE)
			winner = TTT_TEAM_INNOCENT;
	
	LoopValidClients(client)
	{
		char sBuffer[PLATFORM_MAX_PATH];
		
		if(winner == TTT_TEAM_DETECTIVE)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayDWin);
		else if(winner == TTT_TEAM_TRAITOR)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayTWin);
		else if(winner == TTT_TEAM_INNOCENT)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_soverlayIWin);
		
		ShowOverlayToClient(client, sBuffer);
	}
		
}

public Action Delay_Timer(Handle timer, any data)
{
	g_bEndOverlay = false;
}

public void TTT_OnClientGetRole(int client, int role)
{
	AssignOverlay(client, role);
}

public void TTT_OnUpdate()
{	
	if(g_bEndOverlay)
		return;
	
	LoopValidClients(i)
		AssignOverlay(i, TTT_GetClientRole(i));
}

public void AssignOverlay(int client, int role)
{
	if(TTT_IsClientValid(client))
	{
		if(!IsPlayerAlive(client))
			ShowOverlayToClient(client, "");
		
		char sBuffer[PLATFORM_MAX_PATH];

		if(role == TTT_TEAM_DETECTIVE)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sDetectiveIcon);
		else if(role == TTT_TEAM_TRAITOR)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sTraitorIcon);
		else if(role == TTT_TEAM_INNOCENT)
			Format(sBuffer, sizeof(sBuffer), "%s.vtf", g_sInnocentIcon);
		else
			Format(sBuffer, sizeof(sBuffer), "");
		
		ShowOverlayToClient(client, sBuffer);
	}
}