#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>

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

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	CreateTimer(0.1, Timer_UpdateText, _, TIMER_REPEAT);
}

public Action Timer_UpdateText(Handle timer)
{
	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			int target = TraceClientViewEntity(i);
			
			if(!TTT_IsClientValid(target))
				continue;
			
			if(!IsPlayerAlive(target))
				continue;
			
			if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
			{
				if (TTT_GetClientRole(target) == TTT_TEAM_TRAITOR) 
					PrintHintText(i, "Player: <font color='#ff0000'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //red color
				else if (TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE) 
					PrintHintText(i, "Player: <font color='#0000ff'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //blue color
				else if (TTT_GetClientRole(target) == TTT_TEAM_INNOCENT) 
					PrintHintText(i, "Player: <font color='#008000'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //green color
			}
			else 
			{
				if (TTT_GetClientRole(target) == TTT_TEAM_DETECTIVE) 
					PrintHintText(i, "Player: <font color='#0000ff'>\"%N\"</font>\nKarma: %d", target, TTT_GetClientKarma(target)); //blue color
				else 
					PrintHintText(i, "Player: \"%N\"\nKarma: %d", target, TTT_GetClientKarma(target)); //default
			}
		}
		else
		{
			int iMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			int iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			
			if (!TTT_IsClientValid(iTarget))
				continue;
			
			if(!IsPlayerAlive(iTarget))
				continue;
			
			if(iMode == 4 || iMode == 5)
				PrintHintText(i, "Player: \"%N\"\nKarma: %d", iTarget, TTT_GetClientKarma(iTarget));
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