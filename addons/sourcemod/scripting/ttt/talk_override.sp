#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"
#define LoopClients(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientInGame(%1))

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
	CreateTimer(1.0, Timer_OverrideListener, _, TIMER_REPEAT);
}

public Action Timer_OverrideListener(Handle timer)
{
	LoopClients(i)
	{
		if(IsFakeClient(i))
			continue;
		
		LoopClients(j)
		{
			if(IsFakeClient(j))
				continue;
			
			if(!TTT_IsRoundActive()){
				SetListenOverride(i, j, Listen_Yes);
				SetListenOverride(j, i, Listen_Yes);
			}
			else if(IsPlayerAlive(i) && IsPlayerAlive(j))
			{
				SetListenOverride(i, j, Listen_Yes);
				SetListenOverride(j, i, Listen_Yes);
			}
			else if(!IsPlayerAlive(i) && !IsPlayerAlive(j))
			{
				SetListenOverride(i, j, Listen_Yes);
				SetListenOverride(j, i, Listen_Yes);
			}
			else if(IsPlayerAlive(i) && !IsPlayerAlive(j))
			{
				SetListenOverride(j, i, Listen_Yes);
				SetListenOverride(i, j, Listen_No);
			}
			else if(!IsPlayerAlive(i) && IsPlayerAlive(j))
			{
				SetListenOverride(j, i, Listen_No);
				SetListenOverride(i, j, Listen_Yes);
			}
			else
			{
				SetListenOverride(i, j, Listen_No);
				SetListenOverride(j, i, Listen_No);
			}
		}
	}
}