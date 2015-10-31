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
