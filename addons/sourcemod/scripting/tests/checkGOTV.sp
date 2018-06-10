#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_check", Command_Check);
}

public Action Command_Check(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		ReplyToCommand(client, "i: %d, Name: %N, IsFakeClient: %d, IsClientSourceTV: %d, IsClientConnected: %d, IsClientInGame: %d", i, i, IsFakeClient(i), IsClientSourceTV(i), IsClientConnected(i), IsClientInGame(i));
	}
}
