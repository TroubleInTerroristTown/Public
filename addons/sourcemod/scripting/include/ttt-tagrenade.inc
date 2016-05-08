#if defined _TTT_TAGrenade_included
 #endinput
#endif
#define _TTT_TAGrenade_included

native bool TTT_TAGrenade(int target);

public SharedPlugin __pl_TTT_TAGrenade =
{
	name = "ttt_tagrenade",
	file = "ttt_tagrenade.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_TTT_TAGrenade_SetNTVOptional()
{
	MarkNativeAsOptional("");
}
#endif
