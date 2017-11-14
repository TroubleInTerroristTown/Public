#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <cstrike>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Overlays"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

ConVar g_cTraitorIcon = null;
ConVar g_cDetectiveIcon = null;
ConVar g_cInnocentIcon = null;
ConVar g_coverlayDWin = null;
ConVar g_coverlayTWin = null;
ConVar g_coverlayIWin = null;
ConVar g_cEnableHud = null;
ConVar g_cPosRX = null;
ConVar g_cPosRY = null;
ConVar g_cPosDX = null;
ConVar g_cPosDY = null;
ConVar g_cPosIX = null;
ConVar g_cPosIY = null;
ConVar g_cPosTX = null;
ConVar g_cPosTY = null;
ConVar g_cColorR = null;
ConVar g_cColorD = null;
ConVar g_cColorI = null;
ConVar g_cColorT = null;

bool g_bEndOverlay = false;

Handle g_hSyncR = null;
Handle g_hSyncD = null;
Handle g_hSyncI = null;
Handle g_hSyncT = null;

public void OnPluginStart()
{
	StartConfig("overlay");
	CreateConVar("ttt2_overlay_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cDetectiveIcon = AutoExecConfig_CreateConVar("ttt_overlay_detective", "darkness/ttt/overlayDetective", "The overlay to display for detectives during the round.");
	g_cTraitorIcon = AutoExecConfig_CreateConVar("ttt_overlay_traitor", "darkness/ttt/overlayTraitor", "The overlay to display for detectives during the round.");
	g_cInnocentIcon = AutoExecConfig_CreateConVar("ttt_overlay_inno", "darkness/ttt/overlayInnocent", "The overlay to display for detectives during the round.");
	g_coverlayDWin = AutoExecConfig_CreateConVar("ttt_overlay_detective_win", "overlays/ttt/detectives_win", "The overlay to display when detectives win.");
	g_coverlayTWin = AutoExecConfig_CreateConVar("ttt_overlay_traitor_win", "overlays/ttt/traitors_win", "The overlay to display when traitors win.");
	g_coverlayIWin = AutoExecConfig_CreateConVar("ttt_overlay_inno_win", "overlays/ttt/innocents_win", "The overlay to display when innocent win.");
	g_cEnableHud = AutoExecConfig_CreateConVar("ttt_hud_text_enable", "0", "Enable hud_text? (it's a bit buggy with 4:3 and 16:9 resolutions)", _, true, 0.0, true, 1.0);
	g_cPosRX = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_x_position", "0.28", "Remaining position (Default Horizontal: 0.28 Vertical: 0.2) (<X>-POSITION>)");
	g_cPosDX = AutoExecConfig_CreateConVar("ttt_hud_text_detective_x_position", "0.37", "Detective position (Default Horizontal: 0.37 Vertical: 0.3) (<X>-POSITION>)");
	g_cPosIX = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_x_position", "0.48", "Innocent position (Default Horizontal: 0.48 Vertical: 0.3,) (<X>-POSITION>)");
	g_cPosTX = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_x_position", "0.586", "Traitor position (Default Horizontal: 0.586 Vertical: 0.3) (<X>-POSITION>)");
	g_cPosRY = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_y_position", "0.0", "Remaining position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
	g_cPosDY = AutoExecConfig_CreateConVar("ttt_hud_text_detective_y_position", "0.0", "Detective position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
	g_cPosIY = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_y_position", "0.0", "Innocent position (Default Horizontal: 0.0 Vertical: 0.05) (<Y>-POSITION>)");
	g_cPosTY = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_y_position", "0.0", "Traitor position (Default Horizontal: 0.0 Vertical: 0.1) (<Y>-POSITION>)");
	g_cColorR = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_color", "255;255,255", "Remaining color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
	g_cColorD = AutoExecConfig_CreateConVar("ttt_hud_text_detective_color", "0;0;255", "Detective color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
	g_cColorI = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_color", "0;255;0", "Innocent color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
	g_cColorT = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_color", "255;0;0", "Traitor color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
	EndConfig();

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);

	g_hSyncR = CreateHudSynchronizer();
	g_hSyncD = CreateHudSynchronizer();
	g_hSyncI = CreateHudSynchronizer();
	g_hSyncT = CreateHudSynchronizer();

	CreateTimer(3.0, Timer_HUD, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);
	
	g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);


	g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);
	
	g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);


	g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);
	
	g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);

	g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);


	g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);


	g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBuffer);

	PrecacheDecal(sBuffer, true);

}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ShowOverlayToAll(" ");
}

public void TTT_OnRoundEnd(int winner)
{
	ConVar cCvar = FindConVar("ttt_after_round_delay");
	
	if (cCvar.FloatValue > 0.0)
	{
		g_bEndOverlay = true;
		CreateTimer(cCvar.FloatValue, Delay_Timer);
	}
	
	char sBuffer[PLATFORM_MAX_PATH];
	if (winner == TTT_TEAM_TRAITOR)
	{
		g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToAll(sBuffer);
	}
	else if (winner == TTT_TEAM_INNOCENT)
	{
		g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToAll(sBuffer);
	}
	else if (winner == TTT_TEAM_DETECTIVE)
	{
		g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToAll(sBuffer);
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
}

public Action Timer_HUD(Handle timer)
{
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

	if (g_cEnableHud.BoolValue)
	{
		char sBuffer[32];
		char sCR[4][4], sCD[4][4], sCI[4][4], sCT[4][4];
		char sR[24], sD[24], sI[24], sT[24];
		
		g_cColorR.GetString(sBuffer, sizeof(sBuffer));
		Format(sR, sizeof(sR), "Remaining:");
		ExplodeString(sBuffer, ";", sCR, sizeof(sCR), sizeof(sCR[]));

		if (iDet == 1)
		{
			Format(sD, sizeof(sD), "%d Detective", iDet);
		}
		else if (iDet > 1)
		{
			Format(sD, sizeof(sD), "%d Detectives", iDet);
		}
		g_cColorD.GetString(sBuffer, sizeof(sBuffer));
		ExplodeString(sBuffer, ";", sCD, sizeof(sCD), sizeof(sCD[]));

		if (iInn == 1)
		{
			Format(sI, sizeof(sI), "%d Innocent", iInn);
		}
		else if (iInn > 1)
		{
			Format(sI, sizeof(sI), "%d Innocents", iInn);
		}
		g_cColorI.GetString(sBuffer, sizeof(sBuffer));
		ExplodeString(sBuffer, ";", sCI, sizeof(sCI), sizeof(sCI[]));

		if (iTra == 1)
		{
			Format(sT, sizeof(sT), "%d Traitor", iTra);
		}
		else if (iTra > 1)
		{
			Format(sT, sizeof(sT), "%d Traitors", iTra);
		}
		g_cColorT.GetString(sBuffer, sizeof(sBuffer));
		ExplodeString(sBuffer, ";", sCT, sizeof(sCT), sizeof(sCT[]));

		showHudToAll(g_hSyncR, sR, g_cPosRX.FloatValue, g_cPosRY.FloatValue, sCR[0], sCR[1], sCR[2], sCR[3]);
		showHudToAll(g_hSyncD, sD, g_cPosDX.FloatValue, g_cPosDY.FloatValue, sCD[0], sCD[1], sCD[2], sCD[3]);
		showHudToAll(g_hSyncI, sI, g_cPosIX.FloatValue, g_cPosIY.FloatValue, sCI[0], sCI[1], sCI[2], sCI[3]);
		showHudToAll(g_hSyncT, sT, g_cPosTX.FloatValue, g_cPosTY.FloatValue, sCT[0], sCT[1], sCT[2], sCT[3]);
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

	char sBuffer[PLATFORM_MAX_PATH];
	if (role == TTT_TEAM_DETECTIVE)
	{
		g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToClient(client, sBuffer);
	}
	else if (role == TTT_TEAM_TRAITOR)
	{
		g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToClient(client, sBuffer);
	}
	else if (role == TTT_TEAM_INNOCENT)
	{
		g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));
		ShowOverlayToClient(client, sBuffer);
	}
}

void showHudToAll(Handle sync, char[] message, float x, float y, const char[] red, const char[] green, const char[] blue, const char[] alpha)
{
	LoopValidClients(client)
	{
		SetHudTextParams(x, y, 1.1, StringToInt(red), StringToInt(green), StringToInt(blue), StringToInt(alpha), 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, sync, message);
	}
}
