#if defined _TTT_included
 #endinput
#endif
#define _TTT_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "TTT"
#define TTT_PLUGIN_AUTHOR "Bara, .#Zipcore, Darkness & whocodes"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "2.1.0"
#define TTT_PLUGIN_URL "git.tf/TTT/Plugin"

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
/*
 * Called when a body is found.
 *
 * @param client            The client who identified the body.
 * @param victim            The client whom the body belongs to.
 * @param deadPlayer        The name of the victim.
 */
forward void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer);
/*
 * Called when a body is scanned (by a Detective).
 *
 * @param client            The client who scanned the body.
 * @param victim            The client whom the body belongs to.
 * @param deadPlayer        The name of the victim.
 */
forward void TTT_OnBodyScanned(int client, int victim, const char[] deadPlayer);

/*
 * Called when an item is purchased in the menu.
 *
 * @param client            The client who purchased the item.
 * @param itemshort         The short-tag for the item's name.
 */

forward void TTT_OnItemPurchased(int client, const char[] itemshort);

/*
 * Called when a players credits are modified.
 *
 * @param client            Client index.
 * @param credits     	 	The amount of credits (negative or positive).
 */
forward void TTT_OnCreditsChanged(int client, int &credits);

/*
 * Checks if the round is active.
 */
native bool TTT_IsRoundActive();
/*
 * Retrieve a client's role.
 *
 * @param client            Client index.
 */
native int TTT_GetClientRole(int client);
/*
 * Retrieve a client's karma.
 *
 * @param client            Client index.
 */
native int TTT_GetClientKarma(int client);
/*
 * Retrieve a client's credits.
 *
 * @param client            Client index.
 */
native int TTT_GetClientCredits(int client);
/*
 * Set a client's role.
 *
 * @param client            Client index.
 */
native int TTT_SetClientRole(int client, int role);
/*
 * Set a client's karma.
 *
 * @param client            Client index.
 */
native int TTT_SetClientKarma(int client, int karma);
/*
 * Set a client's credits.
 *
 * @param client            Client index.
 */
native int TTT_SetClientCredits(int client, int credits);
/*
 * Determins whether a player's body was found (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyFound(int client);
/*
 * Determins whether a player's body was scanned (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyScanned(int client);

/*
 * Registers a custom item in the menu/shop.
 *
 * @param itemshort         The short-tag identifier of the item (must be unique).
 * @param itemlong          The long fancy name for the item.
 * @param price             The price of the item.
 * @param role              The optional role to restrict the item to.
 */
native bool TTT_RegisterCustomItem(const char[] itemshort, const char[] itemlong, int price, int role = 0);
/*
 * Retrieve a custom item's price.
 *
 * @param item              The short-tag identifier of the item.
 */
native int TTT_GetCustomItemPrice(const char[] item);
/*
 * Retrieve a custom item's role restriction.
 *
 * @param item              The short-tag identifier of the item.
 */
native int TTT_GetCustomItemRole(const char[] item);


/*
 * Check if TTT plugin is loaded and running.
 */
stock bool TTT_IsLoaded()
{
	return LibraryExists("ttt");
}

/*
 * Check if a client index is valid.
 */
stock bool TTT_IsClientValid(int client) 
{ 
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}

stock void TTT_IsGameCSGO()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Only CS:GO Support!");
		return;
	}
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