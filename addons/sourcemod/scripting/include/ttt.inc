#if defined _TTT_included
 #endinput
#endif
#define _TTT_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "TTT - Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "Bara, .#Zipcore & Darkness"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "2.0.0"
#define TTT_PLUGIN_URL "git.tf/TTT"

#define TTT_TEAM_UNASSIGNED 0
#define TTT_TEAM_INNOCENT 1
#define TTT_TEAM_TRAITOR 2
#define TTT_TEAM_DETECTIVE 3

#define MAX_CUSTOM_ITEMS 32

/* 
 * Called before players roles are picked/assigned.
 * Return Plugin_Handled or higher to prevent round start.
 * You could slay players here to force them to sit out.
 */
forward Action TTT_OnRoundStart_Pre();

/*
 * Called when the actual TTT round starts (after selection time).
 *
 * @param innocents         Count of innocent players.
 * @param traitors          Count of traitor players.
 * @param detective         Count of detective players.
 */
forward void TTT_OnRoundStart(int innocents, int traitors, int detective);

/*
 * Called when round start is failed or prevented.
 *
 * @param players           The amount of players we have.
 *                          -1 if this round was prevented by
 *                          another plugin.
 * @param requiredPlayers   The amount of players we need.
 * @param detective         The amount needed for detective.
 */
forward void TTT_OnRoundStartFailed(int players, int requiredPlayers, int detective);

/*
 * Called when a client's role is assigned.
 * 
 * @param client            Client index.
 * @param role              Role.
 */
forward void TTT_OnClientGetRole(int client, int role);
/*
 * Called when a client dies.
 *
 * @param victim            Person who died.
 * @param attacker          Attacker.
 */
forward void TTT_OnClientDeath(int victim, int attacker);
forward void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer);
forward void TTT_OnBodyScanned(int client, int victim, const char[] deadPlayer);

forward void TTT_OnItemPurchased(int client, const char[] itemshort);

native int TTT_GetClientRole(int client);
native int TTT_GetClientKarma(int client);
native int TTT_GetClientCredits(int client);
native int TTT_SetClientRole(int client, int role);
native int TTT_SetClientKarma(int client, int karma);
native int TTT_SetClientCredits(int client, int credits);
native bool TTT_WasBodyFound(int client);
native bool TTT_WasBodyScanned(int client);


native bool TTT_RegisterCustomItem(const char[] itemshort, const char[] itemlong, int price, int role = 0);
native int TTT_GetCustomItemPrice(const char[] item);
native int TTT_GetCustomItemRole(const char[] item);

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

stock bool TTT_HasFlags(int client, AdminFlag flags[16])
{
	int iFlags = GetUserFlagBits(client);
	
	if(iFlags & ADMFLAG_ROOT)
		return true;
	
	for(new i = 0; i < sizeof(flags); i++)
		if(iFlags & FlagToBit(flags[i]))
			return true;
	
	return false;
}