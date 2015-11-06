#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>

#pragma newdecls required

public Plugin myinfo =
{
	name = "Show Nickname & Spec Menu",
	author = "Bara & .#Zipcore",
	description = "",
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	CreateTimer(0.1, Timer_UpdateText, _, TIMER_REPEAT);
}

public Action Timer_UpdateText(Handle timer)
{
	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			int target = GetClientAimTarget(i);
			
			if(!TTT_IsClientValid(target))
				continue;
			
			if(!IsPlayerAlive(target))
				continue;
			
			PrintHintText(i, "Player: \"%N\"\nKarma: %d", target, TTT_GetClientKarma(target));
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