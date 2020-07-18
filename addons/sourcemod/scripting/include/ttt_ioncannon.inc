#if defined _ttt_ioncannon_included
    #endinput
#endif
#define _ttt_ioncannon_included

/**
 * Check whether client have ion cannon or not.
 *
 * @param client            The client index.
 *
 * @return bool             True if have, false otherwise.
 */
native bool TTT_HasIonCannon(int client);

/**
 * Check whether client have automatic ion cannon or not.
 *
 * @param client            The client index.
 *
 * @return bool             True if have, false otherwise.
 */
native bool TTT_HasAutoIonCannon(int client);

/**
 * Get client bought ion cannons.
 *
 * @param client            The client index.
 *
 * @return int              Number of ion cannons.
 */
native int TTT_GetIonCannon(int client);

/**
 * Get client automatic ion cannon target.
 *
 * @param client            The client index.
 *
 * @return int              Target index, -1 otherwise.
 */
native int TTT_GetAutoIonCannon(int client);

/**
 * Add client ion cannon/s.
 *
 * @param client            The client index.
 * @param amount            How many should player receive? Default 1.
 *
 * @return int              Number of ion cannons.
 */
native int TTT_AddIonCannon(int client, int amount = 1);

/**
 * Set client ion cannon/s.
 *
 * @param client            The client index.
 * @param amount            How many should player have?.
 *
 * @return int              Number of ion cannons.
 */
native int TTT_SetIonCannon(int client, int cannons = 0);

/**
 * Check if traitor friendly fire is enabled.
 *
 * @return bool             True if enabled, false otherwise.
 */
native bool TTT_IsFriendlyFired();

public SharedPlugin __pl_ttt_ioncannon = 
{
    name = "ttt_ioncannon",
    file = "ttt_ioncannon.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_ioncannon_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_HasIonCannon");
    MarkNativeAsOptional("TTT_HasAutoIonCannon");
    MarkNativeAsOptional("TTT_GetIonCannon");
    MarkNativeAsOptional("TTT_GetAutoIonCannon");
    MarkNativeAsOptional("TTT_AddIonCannon");
    MarkNativeAsOptional("TTT_SetIonCannon");
    MarkNativeAsOptional("TTT_IsFriendlyFired");
}
#endif
