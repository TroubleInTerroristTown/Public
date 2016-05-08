#if defined _TTT_Wallhack_included
 #endinput
#endif
#define _TTT_Wallhack_included

native bool TTT_Wallhack(int target);

public SharedPlugin __pl_TTT_Wallhack =
{
	name = "ttt_Wallhack",
	file = "ttt_Wallhack.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_TTT_Wallhack_SetNTVOptional()
{
	MarkNativeAsOptional("TTT_Wallhack");
}
#endif
