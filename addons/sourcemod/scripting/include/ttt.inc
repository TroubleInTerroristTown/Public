#if defined _ttt_included
	#endinput
#endif
#define _ttt_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_PLUGIN_NAME "Trouble in Terrorist Town"
#define TTT_PLUGIN_AUTHOR "TTT-Contributors"
#define TTT_PLUGIN_DESCRIPTION "The game is about a group of \"terrorists\" who have traitors among them, out to kill everyone who's not a traitor."
#define TTT_PLUGIN_VERSION "<VERSION>"
#define TTT_PLUGIN_URL "https://github.com/Bara20/TroubleinTerroristTown"

#define TTT_TEAM_UNASSIGNED (1 << 0)
#define TTT_TEAM_INNOCENT (1 << 1)
#define TTT_TEAM_TRAITOR (1 << 2)
#define TTT_TEAM_DETECTIVE (1 << 3)

#define MAX_CUSTOM_ITEMS 64
#define MAX_ITEM_LENGTH 64

#define WEAPON_TASER 31

#define TTT_LOG_SIZE 512

#include <autoexecconfig>

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
 * @param ragdoll           The Array with Ragdoll informations (by refrence).
 */
forward Action TTT_OnBodyChecked(int client, int[] ragdoll);

/*
 * Called on updated player models
 * (if ttt_update_client_model is true)
 *
 * @param client            The client index after updated model
 * @param model             Path of current model
 */
forward void TTT_OnModelUpdate(int client, const char[] model);

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
native int TTT_GetClientKarma(int client, bool publicKarma = true);

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
 * Sets the karma of a client.
 *
 * @param client            Client index.
 */
native int TTT_SetClientKarma(int client, int karma, bool force);

/*
 * Add karma to a client (currentKarma+karma).
 *
 * @param client            Client index.
 * @param client            Karma that will be added.
 */
native int TTT_AddClientKarma(int client, int karma, bool force);

/*
 * Remove karma from a client (currentKarma-karma).
 *
 * @param client            Client index.
 * @param client            Karma to remove.
 */
native int TTT_RemoveClientKarma(int client, int karma, bool force);

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
 * NO DESCRIPTION
 *
 * @param client             The client index.
 * @param rounds             The amount of rounds to add.
 * @param force             Begin directly if client is alive.
 * @return Returns the amount of rounds, otherwise the client index is invalid
 */
native int TTT_AddRoundSlays(int client, int rounds, bool force);

/*
 * NO DESCRIPTION
 *
 * @param client             The client index.
 * @param rounds             The amount of rounds.
 * @param force             Begin directly if client is alive.
 * @return Returns the amount of rounds, otherwise the client index is invalid
 */
native int TTT_SetRoundSlays(int client, int rounds, bool force);

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

stock bool TTT_HasFlags(int client, const char[] flags)
{
	AdminFlag aFlags[16];
	FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));
	
	return tHasFlags(client, aFlags);
}

stock bool tHasFlags(int client, AdminFlag flags[16])
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

stock bool TTT_SafeRemoveWeapon(int iClient, int iWeapon)
{
	if (!IsValidEntity(iWeapon) || !IsValidEdict(iWeapon))
		return false;

	if (!HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity"))
		return false;

	int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");

	if (iOwnerEntity != iClient)
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);

	CS_DropWeapon(iClient, iWeapon, false);

	if (HasEntProp(iWeapon, Prop_Send, "m_hWeaponWorldModel"))
	{
		int iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");

		if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
			if (!AcceptEntityInput(iWorldModel, "Kill"))
				return false;
	}

	if (!AcceptEntityInput(iWeapon, "Kill"))
	{
		return false;
	}

	return true;
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

stock void StartConfig(char[] file, char[] directory = "ttt")
{
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile(file, directory);
	AutoExecConfig_CacheConvars();
}

stock void EndConfig()
{
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}
