#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>
#include <cstrike>

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

bool g_bEndOverlay = false;

bool g_bEnableHud = false;

float g_fPosRX = -1.0;
float g_fPosRY = -1.0;

float g_fPosDX = -1.0;
float g_fPosDY = -1.0;

float g_fPosIX = -1.0;
float g_fPosIY = -1.0;

float g_fPosTX = -1.0;
float g_fPosTY = -1.0;

char g_sColorR[32];
char g_sColorD[32];
char g_sColorI[32];
char g_sColorT[32];

float g_fDelay = -1.0;

Handle g_hSyncR = null;
Handle g_hSyncD = null;
Handle g_hSyncI = null;
Handle g_hSyncT = null;

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
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
	
	g_bEnableHud = Config_LoadBool("ttt_hud_text_enable", false, "Enable hud_text? (it's a bit buggy with 4:3 and 16:9 resolutions)");
	
	g_fPosRX = Config_LoadFloat("ttt_hud_text_remaining_x_position", 0.28, "Remaining position (Default Horizontal: 0.28 Vertical: 0.2) (<X>-POSITION>)");
	g_fPosDX = Config_LoadFloat("ttt_hud_text_detective_x_position", 0.37, "Detective position (Default Horizontal: 0.37 Vertical: 0.3) (<X>-POSITION>)");
	g_fPosIX = Config_LoadFloat("ttt_hud_text_innocent_x_position", 0.48, "Innocent position (Default Horizontal: 0.48 Vertical: 0.3,) (<X>-POSITION>)");
	g_fPosTX = Config_LoadFloat("ttt_hud_text_traitor_x_position", 0.586, "Traitor position (Default Horizontal: 0.586 Vertical: 0.3) (<X>-POSITION>)");
	
	g_fPosRY = Config_LoadFloat("ttt_hud_text_remaining_y_position", 0.0, "Remaining position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
	g_fPosDY = Config_LoadFloat("ttt_hud_text_detective_y_position", 0.0, "Detective position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
	g_fPosIY = Config_LoadFloat("ttt_hud_text_innocent_y_position", 0.0, "Innocent position (Default Horizontal: 0.0 Vertical: 0.05) (<Y>-POSITION>)");
	g_fPosTY = Config_LoadFloat("ttt_hud_text_traitor_y_position", 0.0, "Traitor position (Default Horizontal: 0.0 Vertical: 0.1) (<Y>-POSITION>)");
	
	Config_LoadString("ttt_hud_text_remaining_color", "255;255,255", "Remaining color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)", g_sColorR, sizeof(g_sColorR));
	Config_LoadString("ttt_hud_text_detective_color", "0;0;255", "Detective color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)", g_sColorD, sizeof(g_sColorD));
	Config_LoadString("ttt_hud_text_innocent_color", "0;255;0", "Innocent color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)", g_sColorI, sizeof(g_sColorI));
	Config_LoadString("ttt_hud_text_traitor_color", "255;0;0", "Traitor color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)", g_sColorT, sizeof(g_sColorT));
	
	Config_Done();

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
	
	g_hSyncR = CreateHudSynchronizer();
	g_hSyncD = CreateHudSynchronizer();
	g_hSyncI = CreateHudSynchronizer();
	g_hSyncT = CreateHudSynchronizer();
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayTWin);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayTWin);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_soverlayTWin, true);


	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayIWin);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayIWin);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_soverlayIWin, true);


	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_soverlayDWin);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_soverlayDWin);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_soverlayDWin, true);


	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sDetectiveIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sDetectiveIcon);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_sDetectiveIcon, true);


	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_sTraitorIcon, true);


	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sInnocentIcon);
	AddFileToDownloadsTable(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sInnocentIcon);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(g_sInnocentIcon, true);

}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ShowOverlayToAll(" ");
}

public void TTT_OnRoundEnd(int winner)
{
	if (g_fDelay > 0.0)
	{
		g_bEndOverlay = true;
		CreateTimer(g_fDelay, Delay_Timer);
	}
	
	if (winner == TTT_TEAM_TRAITOR)
	{
		ShowOverlayToAll(g_soverlayTWin);
	}
	else if (winner == TTT_TEAM_INNOCENT)
	{
		ShowOverlayToAll(g_soverlayIWin);
	}
	else if (winner == TTT_TEAM_DETECTIVE)
	{
		ShowOverlayToAll(g_soverlayDWin);
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

public void TTT_OnUpdate1(int client)
{
	if (!g_bEndOverlay)
	{
		AssignOverlay(client, TTT_GetClientRole(client));
	}
	
	if (!TTT_IsRoundActive())
	{
		return;
	}
	
	int iDet = 0;
	int iInn = 0;
	int iTra = 0;
	
	LoopValidClients(i)
	{
		if (!TTT_WasBodyFound(i))
		{
			if (TTT_GetClientRole(i) == TTT_TEAM_DETECTIVE)
			{
				iDet++;
			}
			else if (TTT_GetClientRole(i) == TTT_TEAM_INNOCENT)
			{
				iInn++;
			}
			else if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
			{
				iTra++;
			}
		}
	}
	
	if (g_bEnableHud)
	{
		char sCR[4][4], sCD[4][4], sCI[4][4], sCT[4][4];
		char sR[24], sD[24], sI[24], sT[24];
		
		Format(sR, sizeof(sR), "Remaining:");
		ExplodeString(g_sColorR, ";", sCR, sizeof(sCR), sizeof(sCR[]));
		
		if (iDet == 1)
		{
			Format(sD, sizeof(sD), "%d Detective", iDet);
		}
		else if (iDet > 1)
		{
			Format(sD, sizeof(sD), "%d Detectives", iDet);
		}
		ExplodeString(g_sColorD, ";", sCD, sizeof(sCD), sizeof(sCD[]));
		
		if (iInn == 1)
		{
			Format(sI, sizeof(sI), "%d Innocent", iInn);
		}
		else if (iInn > 1)
		{
			Format(sI, sizeof(sI), "%d Innocents", iInn);
		}
		ExplodeString(g_sColorI, ";", sCI, sizeof(sCI), sizeof(sCI[]));
		
		if (iTra == 1)
		{
			Format(sT, sizeof(sT), "%d Traitor", iTra);
		}
		else if (iTra > 1)
		{
			Format(sT, sizeof(sT), "%d Traitors", iTra);
		}
		ExplodeString(g_sColorT, ";", sCT, sizeof(sCT), sizeof(sCT[]));
		
		LoopValidClients(i)
		{
			showHud(g_hSyncR, i, sR, g_fPosRX, g_fPosRY, sCR[0], sCR[1], sCR[2], sCR[3]);
			showHud(g_hSyncD, i, sD, g_fPosDX, g_fPosDY, sCD[0], sCD[1], sCD[2], sCD[3]);
			showHud(g_hSyncI, i, sI, g_fPosIX, g_fPosIY, sCI[0], sCI[1], sCI[2], sCI[3]);
			showHud(g_hSyncT, i, sT, g_fPosTX, g_fPosTY, sCT[0], sCT[1], sCT[2], sCT[3]);
		}
	}
}

public void AssignOverlay(int client, int role)
{
	if (TTT_GetClientRole(client) < TTT_TEAM_INNOCENT)
	{
		ShowOverlayToClient(client, " ");
	}
	if (!IsPlayerAlive(client))
	{
		ShowOverlayToClient(client, " ");
	}
	
	if (role == TTT_TEAM_DETECTIVE)
	{
		ShowOverlayToClient(client, g_sDetectiveIcon);
	}
	else if (role == TTT_TEAM_TRAITOR)
	{
		ShowOverlayToClient(client, g_sTraitorIcon);
	}
	else if (role == TTT_TEAM_INNOCENT)
	{
		ShowOverlayToClient(client, g_sInnocentIcon);
	}
}

void showHud(Handle sync, int client, char[] message, float x, float y, const char[] red, const char[] green, const char[] blue, const char[] alpha)
{
	SetHudTextParams(x, y, 1.1, StringToInt(red), StringToInt(green), StringToInt(blue), StringToInt(alpha), 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, sync, message);
}

