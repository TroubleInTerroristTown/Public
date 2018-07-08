#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>

public void OnPluginStart()
{
	RegConsoleCmd("sm_checkGOTV", Command_CheckGOTV);
	RegConsoleCmd("sm_panorama", Command_Panorama);
}

public Action Command_CheckGOTV(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		ReplyToCommand(client, "i: %d, Name: %N, IsFakeClient: %d, IsClientSourceTV: %d, IsClientConnected: %d, IsClientInGame: %d", i, i, IsFakeClient(i), IsClientSourceTV(i), IsClientConnected(i), IsClientInGame(i));
	}
}

public Action Command_Panorama(int client, int args)
{
	LoopValidClients(i)
	{
		ReplyToCommand(client, "%N panorama: %d", i, TTT_UseClientPanorama(i));
	}
}
