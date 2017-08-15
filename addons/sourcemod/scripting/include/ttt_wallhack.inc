#if defined _ttt_wallhack_included
	#endinput
#endif
#define _ttt_wallhack_included

native bool TTT_HasActiveWallhack(int client);

public SharedPlugin __pl_ttt_wallhack = 
{
	name = "ttt_wallhack",
	file = "ttt_wallhack.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_wallhack_SetNTVOptional()
{
	MarkNativeAsOptional("TTT_HasActiveWallhack");
}
#endif