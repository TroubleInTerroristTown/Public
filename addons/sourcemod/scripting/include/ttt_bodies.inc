#if defined _ttt_bodies_included
    #endinput
#endif
#define _ttt_bodies_included

#include <ttt_ragdoll>

/**
 * Called when a clients ragdoll entity is about to be created.
 *
 * @param client            The client
 * @param attacker          The attacker.
 */
forward Action TTT_OnClientRagdollCreate(int client, int attacker, const char[] weapon);

/**
 * Called when a body is found.
 * Use must use TTT_GetEntityRefRagdoll(client, entityref) to get the enum struct.
 *
 * @param client            The client who identified the body.
 * @param victim            The client whom the body belongs to. (-1 for invalid index)
 * @param victimRole        The role of victim
 * @param attackerRole        The role of attacker
 * @param entityref         The entity reference to find the correct ragdoll
 * @param silentID          True if body was silenced id and false if normal inspect
 */
forward void TTT_OnBodyFound(int client, int victim, int victimRole, int attackerRole, int entityref, bool silentID);

/**
 * Called before a body will be scanned.
 * Use must use TTT_GetEntityRefRagdoll(client, entityref) to get the enum struct.
 *
 * @param client            The client who scanned the body.
 * @param entityref            The entity reference to find the correct ragdoll
 */
forward Action TTT_OnBodyCheck(int client, int entityref);

/**
 * Retrieve the Radgoll Info.
 *
 * @param client            The clients index.
 * @param radgoll           The array to save the ragoll infos.
 */
native bool TTT_GetClientRagdoll(int client, any[] ragdoll);

/**
 * Retrieve the entity index of a clients ragdoll.
 *
 * @param client            The clients index.
 *
 * @return                  Entity index of the ragdoll.
 */
native int TTT_GetClientRagdollEntIndex(int client);

/**
 * Retrieve the Radgoll Info.
 *
 * @param entityref         The entity reference.
 * @param radgoll           The array to save the ragoll infos.
 */
native bool TTT_GetEntityRefRagdoll(int entityref, any[] ragdoll);

/**
 * Retrieve the client index.
 *
 * @param ragdoll           The ragdoll index.
 * @return                  The client index
 */
native int TTT_GetClientByRagdollID(int ragdoll);

/**
 * Push a ragdoll to the global Ragdoll array (will get cleaned on Round Start).
 *
 * @param radgoll           The enum struct to save as Ragdoll.
 * @param size              The enum struct size.
 */
native int TTT_PushRagdoll(any[] ragdoll, int size);

/**
 * Sets a ragdoll to the global Ragdoll array (will get cleaned on Round Start).
 *
 * @param radgoll           The enum struct to save as Ragdoll.
 * @param size              The enum struct size.
 */
native bool TTT_SetRagdoll(any[] ragdoll, int size);

/**
 * Determins whether a player's body was found (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyFound(int client);

/**
 * Determins whether a player's body was scanned (if dead).
 *
 * @param client            Client index.
 */
native bool TTT_WasBodyScanned(int client);

/**
 * Determines if a player is dead and has had their body found.
 *
 * @param client              The client index to lookup.
 */
native bool TTT_GetFoundStatus(int client);

/**
 * Set whether a player appears dead and body found.
 *
 * @param client             The client index to change.
 * @param found             True if found & dead, false else.
 */
native void TTT_SetFoundStatus(int client, bool found);

/**
 * Spawn client ragdoll based on ttt spawn type.
 *
 * @param client            The client index
 */
native int TTT_CreateClientRagdoll(int client);

/**
 * Removes a clients ragdoll.
 *
 * @param client            The client index
 */
native int TTT_RemoveClientRagdoll(int client);

/**
 * Gets the status of which bodies have been found.
 */
native int TTT_GetFoundArray(int[] found, int size);

/*
 * Remove entity from ragdoll array
 *
 * @param entity            The entity index
 */
native bool TTT_RemoveRagdollFromArray(int entity);

public SharedPlugin __pl_ttt_bodies = 
{
    name = "ttt_bodies",
    file = "ttt_bodies.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_bodies_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_GetClientRagdoll");
    MarkNativeAsOptional("TTT_GetClientRagdollEntIndex");
    MarkNativeAsOptional("TTT_GetEntityRefRagdoll");
    MarkNativeAsOptional("TTT_GetClientByRagdollID");
    MarkNativeAsOptional("TTT_PushRagdoll");
    MarkNativeAsOptional("TTT_SetRagdoll");
    MarkNativeAsOptional("TTT_WasBodyFound");
    MarkNativeAsOptional("TTT_WasBodyScanned");
    MarkNativeAsOptional("TTT_GetFoundStatus");
    MarkNativeAsOptional("TTT_SetFoundStatus");
    MarkNativeAsOptional("TTT_CreateClientRagdoll");
    MarkNativeAsOptional("TTT_RemoveClientRagdoll");
    MarkNativeAsOptional("TTT_GetFoundArray");
}
#endif
