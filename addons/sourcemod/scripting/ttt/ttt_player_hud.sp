#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hud"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

char g_sTextD[512];
char g_sTextI[512];
char g_sTextT[512];
char g_sCFile[PLATFORM_MAX_PATH + 1];

int g_iTarget[MAXPLAYERS + 1] = {-1, ...};
Handle g_hOnHudSend_Pre = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnHudSend_Pre = CreateGlobalForward("TTT_OnHudSend_Pre", ET_Event);
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sCFile, sizeof(g_sCFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sCFile);
	Config_Remove("ttt_public_karma");
	Config_Done();

	BuildPath(Path_SM, g_sCFile, sizeof(g_sCFile), "configs/ttt/hud.cfg");
	Config_Setup("TTT - HUD", g_sCFile);
	Config_LoadString("hud_display_detective", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a detective", g_sTextD, sizeof(g_sTextD));
	Config_LoadString("hud_display_innocent", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a innocent", g_sTextI, sizeof(g_sTextI));
	Config_LoadString("hud_display_traitor", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a traitor", g_sTextT, sizeof(g_sTextT));
	Config_Done();
	
	LoadTranslations("ttt.phrases");
	
	CreateTimer(0.3, Timer_UpdateText, _, TIMER_REPEAT);
}

public Action Timer_UpdateText(Handle timer)
{
	LoopValidClients(client)
	{
		if (IsPlayerAlive(client))
		{
			int iTarget = TraceClientViewEntity(client);
			
			if(iTarget != g_iTarget[client])
			{	
				g_iTarget[client] = iTarget;
				
				if(!TTT_IsClientValid(iTarget))
					continue;
				
				char sName[32];
				char sPlayerName[64];
				char sHealth[32];
				char sPlayerHealth[64];
				char sKarma[32];
				char sPlayerKarma[32];
				char sHintText[512];

				PrepareText(client, iTarget, sName, sizeof(sName), sPlayerName, sizeof(sPlayerName), sHealth, sizeof(sHealth), sPlayerHealth, sizeof(sPlayerHealth), sKarma, sizeof(sKarma), sPlayerKarma, sizeof(sPlayerKarma), sHintText, sizeof(sHintText));
				
				PrintHintText(client, sHintText);
			}
		}
	}

	return Plugin_Continue;
}

public bool PrepareText(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength, char[] sHintText, int iHintTextLength)
{
	Format(sName, iNameLength, "%T", "Hud Name", client);
	Format(sHealth, iHealthLength, "%T", "Hud Health", client);
	Format(sPlayerHealth, iPlayerHealthLength, "%T", "Hud PlayerHealth", client, GetClientHealth(client));
	Format(sKarma, iKarmaLength, "%T", "Hud Karma", client);
	Format(sPlayerKarma, iPlayerKarmaLength, "%T", "Hud PlayerKarma", client, TTT_GetClientKarma(client));
	if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		strcopy(sHintText, iHintTextLength, g_sTextT);
		if (TTT_GetClientRole(target) == TTT_TEAM_TRAITOR)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-T", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-D", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_INNOCENT)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-I", client, target);
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		strcopy(sHintText, iHintTextLength, g_sTextD);
		if (TTT_GetClientRole(target) == TTT_TEAM_TRAITOR)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-T", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-D", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_INNOCENT)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-I", client, target);
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		strcopy(sHintText, iHintTextLength, g_sTextI);
		if (TTT_GetClientRole(target) == TTT_TEAM_TRAITOR)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-T", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-D", client, target);
		else if(TTT_GetClientRole(target) == TTT_TEAM_INNOCENT)
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-I", client, target);
	}
	
	Action res = Plugin_Continue;
	Call_StartForward(g_hOnHudSend_Pre);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushStringEx(sName, iNameLength, 0, SM_PARAM_COPYBACK);
	Call_PushStringEx(sPlayerName, iPlayerNameLength, 0, SM_PARAM_COPYBACK);
	Call_PushStringEx(sHealth, iHealthLength, 0, SM_PARAM_COPYBACK);
	Call_PushStringEx(sPlayerHealth, iPlayerHealthLength, 0, SM_PARAM_COPYBACK);
	Call_PushStringEx(sKarma, iKarmaLength, 0, SM_PARAM_COPYBACK);
	Call_PushStringEx(sPlayerKarma, iPlayerKarmaLength, 0, SM_PARAM_COPYBACK);
	Call_Finish(res);

	if (res >= Plugin_Handled)
		return false;
	
	ReplaceString(sHintText, iHintTextLength, "{Name}", sName);
	ReplaceString(sHintText, iHintTextLength, "{PlayerName}", sPlayerName);
	ReplaceString(sHintText, iHintTextLength, "{Health}", sHealth);
	ReplaceString(sHintText, iHintTextLength, "{PlayerHealth}", sPlayerHealth);
	ReplaceString(sHintText, iHintTextLength, "{Karma}", sKarma);
	ReplaceString(sHintText, iHintTextLength, "{PlayerKarma}", sPlayerKarma);
	return true;
}

stock int TraceClientViewEntity(int client)
{
	float m_vecOrigin[3];
	float m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_SHOT, RayType_Infinite, TRDontHitSelf, client);
	int pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		delete(tr);
		return pEntity;
	}

	if(tr != null)
		delete(tr);

	return -1;
}

public bool TRDontHitSelf(int entity, int mask, int data)
{
	return (1 <= entity <= MaxClients && entity != data);
}
