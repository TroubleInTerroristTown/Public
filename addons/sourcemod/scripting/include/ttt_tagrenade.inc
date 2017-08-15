#if defined _ttt_tagrenade_included
	#endinput
#endif
#define _ttt_tagrenade_included

native bool TTT_CheckTAGrenade(int client, int target);

public SharedPlugin __pl_ttt_tagrenade = 
{
	name = "ttt_tagrenade",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_tagrenade_SetNTVOptional()
{
	MarkNativeAsOptional("TTT_CheckTAGrenade");
}
#endif