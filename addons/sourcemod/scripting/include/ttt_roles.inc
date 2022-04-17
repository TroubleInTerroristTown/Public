#if defined _ttt_karma_included
    #endinput
#endif
#define _ttt_karma_included

#define TTT_ROLE_DEFAULT 0

/**
 * Called when roles should be registered.
 */
forward void TTT_RolesRegister();

/**
 * Called after roles have been registered.
 */
forward void TTT_RolesReady();

/**
 * Returns whether the role manager is ready.
 *
 * @return                  Is ready.
 */
native bool TTT_IsRolesReady();

/**
 * Register a role, this should be done in TTT_RolesRegister.
 *
 * @param key               The roles key (4 chars)
 * @param team              TTT Team index.
 * @param id                Unique ID (Four CC).
 * @param name              The roles name.
 * @param rarity            How rare the role should be (0.01 - 1.0).
 * @param minPlayersReq     The minimum amount of players for this role to be availible.
 * @param maxAmount         The maximim amount of players that can recieve this role in a round.
 */
native void TTT_RegisterRole(const char[] key, int team, int id, float rarity, int minPlayersReq, int maxAmount);

/**
 * Gets an array of random role IDs for a specific team, the amount of role IDs
 * is equal to the count.
 *
 * @param team              TTT Team index.
 * @param count             Amount of players on the team.
 * @param playerCount       Amount of active players on the server.
 * @param roles             Output role array.
 */
native void TTT_GetTeamRoles(int team, int count, int playerCount, int[] roles);

/**
 * Gets all of the unique role IDs for a given team.
 *
 * @param team              TTT Team index.
 * @param roles             Output role array.
 * @param size              Size of roles array.
 * @return                  The amount of roles written.
 */
native int TTT_GetRoleIDs(int team, int[] roles, int size);

stock bool TTT_CheckRoleLibraryExists()
{
    return LibraryExists("ttt-roles");
}

stock bool TTT_CheckRoleLibraryName(const char[] name)
{
    return strcmp(name, "ttt-roles", true) == 0;
}

public SharedPlugin __pl_ttt_roles = 
{
    name = "ttt-roles",
    file = "ttt_roles.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_roles_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_IsRolesReady");
    MarkNativeAsOptional("TTT_RegisterRole");
    MarkNativeAsOptional("TTT_GetTeamRoles");
    MarkNativeAsOptional("TTT_GetRoleIDs");
}
#endif
