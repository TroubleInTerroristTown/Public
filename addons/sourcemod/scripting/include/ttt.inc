#if defined _TTT_included
 #endinput
#endif
#define _TTT_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "TTT"
#define TTT_PLUGIN_AUTHOR "Bara, .#Zipcore, Darkness & whocodes"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "2.1.<ID>"
#define TTT_PLUGIN_URL "git.tf/TTT/Plugin"

#define TTT_TEAM_UNASSIGNED 0
#define TTT_TEAM_INNOCENT 1
#define TTT_TEAM_TRAITOR 2
#define TTT_TEAM_DETECTIVE 3

#define MAX_CUSTOM_ITEMS 64

enum eConfig
{
	i_shopDNA,
	i_shopID,
	i_shopFAKEID,
	i_shopT,
	i_shopD,
	i_shopTASER,
	i_shopJIHADBOMB,
	i_shopC4,
	i_requiredPlayersD,
	i_requiredPlayers,
	i_startKarma,
	i_karmaBan,
	i_karmaBanLength,
	i_maxKarma,
	i_spawnHPT,
	i_spawnHPD,
	i_spawnHPI,
	i_karmaII,
	i_karmaIT,
	i_karmaID,
	i_karmaTI,
	i_karmaTT,
	i_karmaTD,
	i_karmaDI,
	i_karmaDT,
	i_karmaDD,
	i_creditsII,
	i_creditsIT,
	i_creditsID,
	i_creditsTI,
	i_creditsTT,
	i_creditsTD,
	i_creditsDI,
	i_creditsDT,
	i_creditsDD,
	i_creditsFoundBody,
	i_creditsTaserHurtTraitor,
	i_traitorloseAliveNonTraitors,
	i_traitorloseDeadNonTraitors,
	i_traitorwinAliveTraitors,
	i_traitorwinDeadTraitors,
	bool:b_showDeathMessage,
	bool:b_showKillMessage,
	bool:b_showEarnKarmaMessage,
	bool:b_showEarnCreditsMessage,
	bool:b_showLoseKarmaMessage,
	bool:b_showLoseCreditsMessage,
	i_messageTypKarma,
	i_messageTypCredits,
	bool:b_blockSuicide,
	bool:b_allowFlash,
	bool:b_blockLookAtWeapon,
	bool:b_blockGrenadeMessage,
	bool:b_blockRadioMessage,
	bool:b_enableNoBlock,
	String:s_pluginTag[250],
	bool:b_kadRemover,
	i_rulesClosePunishment,
	i_punishInnoKills,
	i_punishTraitorKills,
	i_punishDetectiveKills,
	i_timeToReadRules,
	i_timeToReadDetectiveRules,
	bool:b_showRulesMenu,
	bool:b_showDetectiveMenu,
	String:s_kickImmunity[16],
	bool:b_updateClientModel,
	bool:b_removeHostages,
	bool:b_removeBomb,
	bool:b_roleAgain,
	i_traitorRatio,
	i_detectiveRatio,
	bool:b_taserAllow,
	Float:f_jihadPreparingTime,
	bool:b_denyFire,
	bool:b_slayAfterStart,
	i_c4ShakeRadius,
	Float:f_c4DamageRadius,
	i_startCredits,
	bool:b_removeBuyzone,
	bool:b_forceTeams,
	bool:b_randomWinner,
	bool:b_forceModel,
	String:s_modelCT[PLATFORM_MAX_PATH],
	String:s_modelT[PLATFORM_MAX_PATH],
	String:s_overlayTWin[PLATFORM_MAX_PATH],
	String:s_overlayDWin[PLATFORM_MAX_PATH],
	String:s_overlayIWin[PLATFORM_MAX_PATH],
	String:s_overlayTCorner[PLATFORM_MAX_PATH],
	String:s_overlayDCorner[PLATFORM_MAX_PATH],
	String:s_overlayICorner[PLATFORM_MAX_PATH],
	String:s_logFile[PLATFORM_MAX_PATH],
	String:s_errFile[PLATFORM_MAX_PATH],
	String:s_defaultPri_D[64],
	String:s_defaultSec[64],
	bool:b_endwithD,
	bool:b_hideTeams,
	bool:b_publicKarma,
	bool:b_karmaRound,
	bool:b_stripWeapons,
	bool:b_C4Beam,
	bool:b_karmaDMG,
	bool:b_karmaDMG_up,
	Float:f_roundDelay,
	bool:b_nextRoundAlert,
	bool:b_endroundDMG,
	bool:bResetCreditsEachRound,
	bool:b_ignoreDeaths,
	bool:b_ignoreRDMMenu,
	bool:b_deadPlayersCanSeeOtherRules,
	bool:b_sortItems,
	i_sortItemsOrder
};

/*
 * Called every 5 seconds
 */
forward void TTT_OnUpdate();

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
 * Called when an item is purchased in the menu. Return Plugin_Stop
 * to prevent us subtracting credits and informing the player that
 * the item was purchased.
 *
 * @param client            The client who purchased the item.
 * @param itemshort         The short-tag for the item's name.
 */
forward Action TTT_OnItemPurchased(int client, const char[] itemshort);

/*
 * Called before a players credits are modified.
 *
 * @param client            Client index.
 * @param oldcredits        The old amount of credits.
 * @param newcredits     	 The new amount of credits.
 */
forward Action TTT_OnCreditsChanged_Pre(int client, int oldcredits, int &newcredits);

/*
 * Called after a players credits are modified.
 *
 * @param client            Client index.
 * @param credits     	    The new amount of credits.
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
 * Determines if a player is dead and has had their body found.
 *
 * @param client              The client index to lookup.
 */
native bool TTT_GetFoundStatus(int client);

/*
 * Set whether a player appears dead and body found.
 *
 * @param client             The client index to change.
 * @param found             True if found & dead, false else.
 */
native void TTT_SetFoundStatus(int client, bool found);

/*
 * Overrides a config setting.
 *
 * @param configIndex       The config index to change. Use eConfig for this.
 * @param value             Value to set.
 */
native void TTT_OverrideConfigInt(int configIndex, int value);

/*
 * Overrides a config setting.
 *
 * @param configIndex       The config index to change. Use eConfig for this.
 * @param value             Value to set.
 */
native void TTT_OverrideConfigBool(int configIndex, bool value);

/*
 * Overrides a config setting.
 *
 * @param configIndex       The config index to change. Use eConfig for this.
 * @param value             Value to set.
 */
native void TTT_OverrideConfigFloat(int configIndex, float value);

/*
 * Overrides a config setting.
 *
 * @param configIndex       The config index to change. Use eConfig for this.
 * @param buffer            String to set.
 */
native void TTT_OverrideConfigString(int configIndex, char[] buffer);

/*
 * Reloads the config.
 */
native void TTT_ReloadConfig();

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


stock void ShowOverlayToClient(int client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock void ShowOverlayToAll(const char[] overlaypath)
{
	LoopValidClients(i)
		if(!IsFakeClient(i))
			ShowOverlayToClient(i, overlaypath);
}
