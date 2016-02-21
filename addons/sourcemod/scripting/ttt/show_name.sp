#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Show Nickname & Spec Menu"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

bool g_bKarma = true;
bool g_bHealth = false;
char g_sCFile[PLATFORM_MAX_PATH + 1];

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sCFile, sizeof(g_sCFile), "configs/ttt/config.cfg");

	Config_Setup("TTT", g_sCFile);
	g_bKarma = Config_LoadBool("ttt_public_karma", false, "Show karma as points (or another way?)");
	g_bHealth = Config_LoadBool("ttt_display_health", false, "If show_name.smx is running, should we display a word-based health measurement on the HUD?");
	Config_Done();

	CreateTimer(0.3, Timer_UpdateText, _, TIMER_REPEAT);
}

public Action Timer_UpdateText(Handle timer)
{
	LoopValidClients(client)
	{
		if (IsPlayerAlive(client))
		{
			int target = TraceClientViewEntity(client);

			if(!TTT_IsClientValid(target))
				continue;

			if(!IsPlayerAlive(target))
				continue;

			if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			{
				if (TTT_GetClientRole(target) == TTT_TEAM_TRAITOR)
					PrintHintText(client, "Player: <font color='#ff0000'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //red color
				else if (TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE)
					PrintHintText(client, "Player: <font color='#0000ff'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //blue color
				else if (TTT_GetClientRole(target) == TTT_TEAM_INNOCENT)
					PrintHintText(client, "Player: <font color='#008000'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //green color
			}
			else
			{
				if (TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE)
					PrintHintText(client, "Player: <font color='#0000ff'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //blue color
				else
					PrintHintText(client, "Player: \"%N\"\nKarma: %d", target, TTT_GetClientKarma(target)); //default
			}
		}
		else
		{
			int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (!TTT_IsClientValid(iTarget))
				continue;

			if(!IsPlayerAlive(iTarget))
				continue;

			if(iMode == 4 || iMode == 5)
				PrintHintText(client, "Player: \"%N\"\nKarma: %d", iTarget, TTT_GetClientKarma(iTarget));
		}
	}

	return Plugin_Continue;
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
