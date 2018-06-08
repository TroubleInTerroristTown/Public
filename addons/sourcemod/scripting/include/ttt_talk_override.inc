#if defined _ttt_talk_override_included
	#endinput
#endif
#define _ttt_talk_override_included

/*
 * TODO: Add Description
 */
forward ListenOverride TTT_OnListenOverride(int receiver, int sender, ListenOverride &status);

/*
 * TODO: Add Description
 */
native ListenOverride TTT_SetListenOverride(int receiver, int sender);

/*
 * TODO: Add Description
 */
native ListenOverride TTT_GetListenOverride(int receiver, int sender);

public SharedPlugin __pl_ttt_talk_override = 
{
	name = "ttt_talk_override",
	file = "ttt_talk_override.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_talk_override_SetNTVOptional()
{
	MarkNativeAsOptional("TTT_GetGrabEntity");
}
#endif
