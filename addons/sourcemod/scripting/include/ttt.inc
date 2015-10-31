#if defined _TTT_included
 #endinput
#endif
#define _TTT_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "TTT - Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "Bara & Franc1sco"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "2.0.6-testing"
#define TTT_PLUGIN_URL "git.tf/TTT"

#define TTT_TEAM_UNASSIGNED 0
#define TTT_TEAM_INNOCENT 1
#define TTT_TEAM_TRAITOR 2
#define TTT_TEAM_DETECTIVE 3

forward void TTT_OnRoundStart(int innocents, int traitors, int detective);
forward void TTT_OnRoundStartFailed(int players, int requiredPlayers, int detective);
forward void TTT_OnClientGetRole(int client, int role);
forward void TTT_OnClientDeath(int victim, int attacker);
forward void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer);

native int TTT_GetClientRole(int client);
native int TTT_GetClientKarma(int client);
native int TTT_GetClientCredits(int client);
native int TTT_SetClientRole(int client, int role);
native int TTT_SetClientKarma(int client, int karma);
native int TTT_SetClientCredits(int client, int credits);
native bool TTT_WasBodyFound(int client);
native bool TTT_WasBodyScanned(int client);

stock bool TTT_IsLoaded()
{
	return LibraryExists("ttt");
}

stock bool TTT_IsClientValid(int client) 
{ 
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}
