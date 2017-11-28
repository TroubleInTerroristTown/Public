#if defined _ttt_glow_included
	#endinput
#endif
#define _ttt_glow_included

forward Action TTT_OnGlowCheck(int client, int target, bool &seeTarget, bool &overrideColor, int &red, int &green, int &blue, int &alpha);

public SharedPlugin __pl_ttt_glow = 
{
	name = "ttt_glow",
	file = "ttt_glow.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
