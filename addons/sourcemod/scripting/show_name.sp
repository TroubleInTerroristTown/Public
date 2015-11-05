#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>

#pragma newdecls required

public Plugin myinfo =
{
	name = "Show Nickname",
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
	}
	
	return Plugin_Continue; 
}