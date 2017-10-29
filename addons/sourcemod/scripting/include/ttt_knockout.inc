#if defined _ttt_knockout_included
	#endinput
#endif
#define _ttt_knockout_included

native bool TTT_IsClientKnockout(int client);

public SharedPlugin __pl_ttt_knockout = 
{
	name = "ttt_knockout",
	file = "ttt_knockout.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_knockout_SetNTVOptional()
{
	MarkNativeAsOptional("TTT_IsClientKnockout");
}
#endif
