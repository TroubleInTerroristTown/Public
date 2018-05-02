#if defined _ttt_grabbermod_included
	#endinput
#endif
#define _ttt_grabbermod_included

/*
 * Call while grabbing.
 * By returning Plugin_Handled or Plugin_Stop you can stop grabbing
 *
 * @param client            	The client index.
 * @param entity            	The entity index which was grabbed by the client.
 */
forward bool TTT_OnGrabbing(int client, int entity);

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
	// MarkNativeAsOptional("");
}
#endif
