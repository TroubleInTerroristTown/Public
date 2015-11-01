#include <sourcemod>
#include <sdktools>
#include <ttt>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Show Nickname",
	author = "Bara",
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
			int target = GetClientAimTarget(i) ;
			if(target > 0 && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target))
			{
				PrintHintText(i, "Player: \"%N\"\nKarma: %d", target, TTT_GetClientKarma(target));
			}
		}
	}
	return Plugin_Continue; 
}