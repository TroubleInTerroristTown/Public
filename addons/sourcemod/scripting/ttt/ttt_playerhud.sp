#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hud"

ConVar g_cTextD = null;
ConVar g_cTextI = null;
ConVar g_cTextT = null;
ConVar g_cTextU = null;

int g_iTarget[MAXPLAYERS + 1] = {0, ...};
Handle g_hOnHudSend_Pre = null;

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
	g_hOnHudSend_Pre = CreateGlobalForward("TTT_OnHudSend_Pre", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);

	RegPluginLibrary("ttt_playerhud");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	StartConfig("playerhud");
	CreateConVar("ttt2_playerhud_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cTextD = AutoExecConfig_CreateConVar("hud_display_detective", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a detective. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
	g_cTextI = AutoExecConfig_CreateConVar("hud_display_innocent", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a innocent. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
	g_cTextT = AutoExecConfig_CreateConVar("hud_display_traitor", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a traitor. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
	g_cTextU = AutoExecConfig_CreateConVar("hud_display_unassigned", "{NAME}: {PLAYERNAME}\n{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a unassigned. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
	EndConfig();

	LoadTranslations("ttt.phrases");

	CreateTimer(0.3, Timer_UpdateText, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	char sFile[] = "ttt_player_hud.smx";
	Handle hPlugin = FindPluginByFile(sFile);
	
	if (hPlugin != null && GetPluginStatus(hPlugin) == Plugin_Running)
	{
		SetFailState("Old player hud file found! Please delete '%s'", sFile);
	}
}

public Action Timer_UpdateText(Handle timer)
{
	LoopValidClients(client)
	{
		if (IsPlayerAlive(client))
		{
			int iTarget = TraceClientViewEntity(client);
			if (iTarget != g_iTarget[client])
			{
				g_iTarget[client] = iTarget;

				if (!TTT_IsClientValid(iTarget))
				{
					continue;
				}

				char sName[32];
				char sPlayerName[64];
				char sHealth[32];
				char sPlayerHealth[64];
				char sKarma[32];
				char sPlayerKarma[32];
				char sHintText[512];

				if (PrepareText(client, iTarget, sName, sizeof(sName), sPlayerName, sizeof(sPlayerName), sHealth, sizeof(sHealth), sPlayerHealth, sizeof(sPlayerHealth), sKarma, sizeof(sKarma), sPlayerKarma, sizeof(sPlayerKarma), sHintText, sizeof(sHintText)))
				{
					PrintHintText(client, sHintText);
				}
			}
		}
	}

	return Plugin_Continue;
}

public bool PrepareText(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength, char[] sHintText, int iHintTextLength)
{
	int iHealth = GetClientHealth(target);
	int iKarma = TTT_GetClientKarma(target, false);
	
	Format(sName, iNameLength, "%T", "Hud Name", client);
	Format(sHealth, iHealthLength, "%T", "Hud Health", client);
	Format(sPlayerHealth, iPlayerHealthLength, "%T", "Hud PlayerHealth", client, iHealth);
	Format(sKarma, iKarmaLength, "%T", "Hud Karma", client);
	Format(sPlayerKarma, iPlayerKarmaLength, "%T", "Hud PlayerKarma", client, iKarma);
	
	int iRole = TTT_GetClientRole(client);
	int iTRole = TTT_GetClientRole(target);
	
	char sText[512];
	
	if (iRole == TTT_TEAM_TRAITOR)
	{
		g_cTextT.GetString(sText, sizeof(sText));
		strcopy(sHintText, iHintTextLength, sText);
		
		if (iTRole == TTT_TEAM_TRAITOR)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-T", client, target);
		}
		else if (iTRole == TTT_TEAM_DETECTIVE)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-D", client, target);
		}
		else if (iTRole == TTT_TEAM_INNOCENT)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-I", client, target);
		}
		else if (iTRole == TTT_TEAM_UNASSIGNED)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName T-U", client, target);
		}
	}
	else if (iRole == TTT_TEAM_DETECTIVE)
	{
		g_cTextD.GetString(sText, sizeof(sText));
		strcopy(sHintText, iHintTextLength, sText);
		
		if (iTRole == TTT_TEAM_TRAITOR)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-T", client, target);
		}
		else if (iTRole == TTT_TEAM_DETECTIVE)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-D", client, target);
		}
		else if (iTRole == TTT_TEAM_INNOCENT)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-I", client, target);
		}
		else if (iTRole == TTT_TEAM_UNASSIGNED)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName D-U", client, target);
		}
	}
	else if (iRole == TTT_TEAM_INNOCENT)
	{
		g_cTextI.GetString(sText, sizeof(sText));
		strcopy(sHintText, iHintTextLength, sText);
		
		if (iTRole == TTT_TEAM_TRAITOR)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-T", client, target);
		}
		else if (iTRole == TTT_TEAM_DETECTIVE)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-D", client, target);
		}
		else if (iTRole == TTT_TEAM_INNOCENT)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-I", client, target);
		}
		else if (iTRole == TTT_TEAM_UNASSIGNED)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName I-U", client, target);
		}
	}
	else if (iRole == TTT_TEAM_UNASSIGNED)
	{
		g_cTextU.GetString(sText, sizeof(sText));
		strcopy(sHintText, iHintTextLength, sText);
		
		if (iTRole == TTT_TEAM_TRAITOR)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName U-T", client, target);
		}
		else if (iTRole == TTT_TEAM_DETECTIVE)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName U-D", client, target);
		}
		else if (iTRole == TTT_TEAM_INNOCENT)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName U-I", client, target);
		}
		else if (iTRole == TTT_TEAM_UNASSIGNED)
		{
			Format(sPlayerName, iPlayerNameLength, "%T", "Hud PlayerName U-U", client, target);
		}
	}

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnHudSend_Pre);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushStringEx(sName, iNameLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iNameLength);
	Call_PushStringEx(sPlayerName, iPlayerNameLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iPlayerNameLength);
	Call_PushStringEx(sHealth, iHealthLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iHealthLength);
	Call_PushStringEx(sPlayerHealth, iPlayerHealthLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iPlayerHealthLength);
	Call_PushStringEx(sKarma, iKarmaLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iKarmaLength);
	Call_PushStringEx(sPlayerKarma, iPlayerKarmaLength, 0, SM_PARAM_COPYBACK & SM_PARAM_STRING_COPY);
	Call_PushCell(iPlayerKarmaLength);
	Call_Finish(res);
	if (res >= Plugin_Handled)
	{
		return false;
	}

	ReplaceString(sHintText, iHintTextLength, "{Name}", sName, false);
	ReplaceString(sHintText, iHintTextLength, "{PlayerName}", sPlayerName, false);
	ReplaceString(sHintText, iHintTextLength, "{Health}", sHealth, false);
	ReplaceString(sHintText, iHintTextLength, "{PlayerHealth}", sPlayerHealth, false);
	ReplaceString(sHintText, iHintTextLength, "{Karma}", sKarma, false);
	ReplaceString(sHintText, iHintTextLength, "{PlayerKarma}", sPlayerKarma, false);

	return true;
}

stock int TraceClientViewEntity(int client)
{
	float m_vecOrigin[3];
	float m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_SOLID, RayType_Infinite, TRDontHitSelf, client);
	int pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		delete(tr);
		return pEntity;
	}

	if (tr != null)
	{
		delete(tr);
	}

	return -1;
}

public bool TRDontHitSelf(int entity, int mask, int data)
{
	return (entity != data);
}
