#if defined _ttt_grabbermod_included
    #endinput
#endif
#define _ttt_grabbermod_included

/*
 * Call while grabbing.
 * By returning Plugin_Handled or Plugin_Stop you can stop grabbing
 *
 * @param client                The client index.
 * @param entity                The entity index which was grabbed by the client.
 */
forward Action TTT_OnGrabbing(int client, int entity);

/*
 * Get valid client object. 
 *
 * @param client                The client index
 *
 * @return                      Entity reference (use EntRefToEntIndex to get index) [-1 otherwise]
 */
native int TTT_GetClientGrabEntity(int client);

/*
 * Resets client grab (similar to droping object).
 *
 * @param client                The client index
 *
 * @noreturn
 */
native void TTT_ResetClientGrab(int client);

/*
 * Client index of entity.
 *
 * @param entity                The entity index.
 *
 * @return                      The client index (0 on failure)
 */
native int TTT_GetEntityGrabber(int entity);

/*
 * Reset all clients that grabbed the specific entity
 *
 * @param entity                The entity index
 *
 * @noreturn
 */
native void TTT_ResetClientGrabByEntity(int entity);

public SharedPlugin __pl_ttt_grabbermod = 
{
    name = "ttt_grabbermod",
    file = "ttt_grabbermod.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_grabbermod_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_GetClientGrabEntity");
    MarkNativeAsOptional("TTT_ResetClientGrab");
    MarkNativeAsOptional("TTT_GetEntityGrabber");
    MarkNativeAsOptional("TTT_ResetClientGrabByEntity");
}
#endif
