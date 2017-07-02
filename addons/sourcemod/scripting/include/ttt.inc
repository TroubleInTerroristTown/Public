#if defined _ttt_included
	#endinput
#endif
#define _ttt_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "TTT-Contributors"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "2.1.<ID>"
#define TTT_PLUGIN_URL "https://github.com/Bara20/TroubleinTerroristTown"

#define TTT_TEAM_UNASSIGNED (1 << 0)
#define TTT_TEAM_INNOCENT (1 << 1)
#define TTT_TEAM_TRAITOR (1 << 2)
#define TTT_TEAM_DETECTIVE (1 << 3)

#define MAX_CUSTOM_ITEMS 64

#define WEAPON_TASER 31

#define TTT_ITEM_SIZE 512

enum eConfig
{
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
	bool:b_showDeathMessage, 
	bool:b_showKillMessage, 
	bool:b_showEarnKarmaMessage, 
	bool:b_showLoseKarmaMessage, 
	i_messageTypKarma, 
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
	String:s_logsAccess[16],
	bool:bLogsDeadOnly,
	bLogsNotifyAlive,
	bool:b_updateClientModel, 
	bool:b_removeHostages, 
	bool:b_removeBomb, 
	bool:b_roleAgain, 
	i_traitorRatio, 
	i_detectiveRatio, 
	bool:b_denyFire, 
	bool:b_slayAfterStart, 
	bool:b_removeBuyzone, 
	bool:b_forceTeams, 
	bool:b_randomWinner, 
	bool:b_forceModel, 
	String:s_modelCT[PLATFORM_MAX_PATH], 
	String:s_modelT[PLATFORM_MAX_PATH], 
	String:s_logFile[PLATFORM_MAX_PATH], 
	String:s_errFile[PLATFORM_MAX_PATH], 
	String:s_logDateFormat[24],
	String:s_defaultPri_D[64], 
	String:s_defaultSec[64], 
	bool:b_endwithD, 
	bool:b_hideTeams, 
	bool:b_publicKarma, 
	bool:b_karmaRound, 
	bool:b_stripWeapons, 
	bool:b_karmaDMG, 
	bool:b_karmaDMG_up, 
	Float:f_roundDelay, 
	bool:b_nextRoundAlert, 
	bool:b_endroundDMG, 
	bool:b_ignoreDeaths, 
	bool:b_ignoreRDMMenu, 
	bool:b_deadPlayersCanSeeOtherRules,
	i_RoundStartedFontSize,
	String:s_RoundStartedFontColor[12],
	i_RoundStartFontSize,
	String:s_RoundStartFontColor[12],
	bool:b_tChatToDead,
	bool:b_dChatToDead,
	bool:bTranfserArmor,
	bool:bShowTraitors,
	bool:bRespawnDeadPlayers,
	i_maxTraitors,
	i_maxDetectives,
	i_minKarmaDetective,
	bool:bEnableDamage,
	bool:bGiveWeaponsOnFailStart,
	String:sFSPrimary[32],
	String:sFSSecondary[32],
	bool:b_showKarmaOnSpawn,
	bool:bDebugMessages
};

enum Ragdolls
{
	Ent, 
	Victim, 
	Attacker,
	VictimTeam,
	AttackerTeam,
	String:VictimName[MAX_NAME_LENGTH], 
	String:AttackerName[MAX_NAME_LENGTH], 
	bool:Scanned, 
	Float:GameTime, 
	String:Weaponused[32], 
	bool:Found
}

/*
 * Called every 5 seconds
 *
 * @param client            Client index.
 */
forward void TTT_OnUpdate5(int client);

/*
 * Called every 3 seconds
 *
 * @param client            Client index.
 */
forward void TTT_OnUpdate3(int client);

/*
 * Called every second
 *
 * @param client            Client index.
 */
forward void TTT_OnUpdate1(int client);

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
 * Called when the actual TTT round ended.
 *
 * @param winner         	The Winning Team.
 */
forward void TTT_OnRoundEnd(int winner);

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
 * @param ragdoll            The Array with Ragdoll informations (by refrence).
 */
forward Action TTT_OnBodyChecked(int client, int[] ragdoll);

forward int TTT_OnButtonPress(int client, int button);
forward int TTT_OnButtonRelease(int client, int button);

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
 * Retrieve the Radgoll Info.
 *
 * @param client            The victims index.
 * @param radgoll           The array to save the ragoll infos.
 */
native int TTT_GetClientRagdoll(int victim, int[] ragdoll);

/*
 * Push a ragdoll to the global Ragdoll array (will get cleaned on Round Start).
 *
 * @param radgoll           The array to save as Ragdoll.
 */
native int TTT_SetRagdoll(int[] ragdoll);

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
 * Add a client's karma (currentKarma+karma).
 *
 * @param client            Client index.
 */
native int TTT_AddClientKarma(int client, int karma);

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
 * Log a String to the ingame Log.
 *
 * @param string            The message that should get logged.
 */
native void TTT_LogString(const char[] format, any ...);

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
 * Force a player to be traitor next round. (If there are enough Traitors)
 *
 * @param client             The client index to change.
 * @return False if the client's role already forced for the next round.
 */
native bool TTT_ForceTraitor(int client);

/*
 * Force a player to be detective next round. (If there are enough Detectives)
 *
 * @param client             The client index to change.
 * @return False if the client's role is already forced for the next round.
 */
native bool TTT_ForceDetective(int client);

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
	{
		return true;
	}
	return false;
}

stock void TTT_IsGameCSGO()
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Only CS:GO Support!");
		return;
	}
}

stock bool TTT_HasFlags(int client, AdminFlag flags[16])
{
	int iFlags = GetUserFlagBits(client);
	
	if (iFlags & ADMFLAG_ROOT)
	{
		return true;
	}
	
	for (int i = 0; i < sizeof(flags); i++)
	{
		if (iFlags & FlagToBit(flags[i]))
		{
			return true;
		}
	}
	
	return false;
}

stock void ShowOverlayToClient(int client, const char[] overlaypath)
{
	int iFlags = GetCommandFlags("r_screenoverlay");

	SetCommandFlags("r_screenoverlay", iFlags &~ FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
	SetCommandFlags("r_screenoverlay", iFlags);
}

stock void ShowOverlayToAll(const char[] overlaypath)
{
	LoopValidClients(i)
	{
		if (!IsFakeClient(i))
		{
			ShowOverlayToClient(i, overlaypath);
		}
	}
}

stock bool IsWorldDamage(int iAttacker, int damagetype)
{
	if (damagetype == DMG_FALL
		 || damagetype == DMG_GENERIC
		 || damagetype == DMG_CRUSH
		 || damagetype == DMG_SLASH
		 || damagetype == DMG_BURN
		 || damagetype == DMG_VEHICLE
		 || damagetype == DMG_FALL
		 || damagetype == DMG_BLAST
		 || damagetype == DMG_SHOCK
		 || damagetype == DMG_SONIC
		 || damagetype == DMG_ENERGYBEAM
		 || damagetype == DMG_DROWN
		 || damagetype == DMG_PARALYZE
		 || damagetype == DMG_NERVEGAS
		 || damagetype == DMG_POISON
		 || damagetype == DMG_ACID
		 || damagetype == DMG_AIRBOAT
		 || damagetype == DMG_PLASMA
		 || damagetype == DMG_RADIATION
		 || damagetype == DMG_SLOWBURN
		 || iAttacker == 0
		)
	{
		return true;
	}
	return false;
}
