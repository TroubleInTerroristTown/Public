#if defined _ttt_glow_included
    #endinput
#endif
#define _ttt_glow_included

/**
 * Gets the Glow Skin of a client.
 *
 * @param client            Client index.
 *
 * @returns entity index.
 */
native void TTT_GetGlowSkin(int client);

/**
 * Sets the color of a clients glow.
 *
 * @param client            Client index.
 * @param color             Color of the glow.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_SetGlowColor(int client, int color[4], float duration = 0.0);

/**
 * Sets the color of a clients glow.
 *
 * @param client            Client index.
 * @param team              Which Team color to set the glow to.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_SetGlowTeam(int client, int team, float duration = 0.0);

/**
 * Lets a client see the targets glow for the given duration.
 *
 * @param client            Client index.
 * @param target            Target index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeGlow(int client, int target, float duration = 0.0);

/**
 * Lets a client see the glow pf the passed targets for the given duration.
 *
 * @param client            Client index.
 * @param targets           Target indexs.
 * @param target_count      The amount of targets.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeClientsGlow(int client, int[] targets, int target_count, float duration = 0.0);

/**
 * Lets a client see the targets glow of all players for the given duration.
 *
 * @param client            Client index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeAllGlow(int client, float duration = 0.0);

/**
 * Lets all players see the clients glow for the given duration.
 *
 * @param client            Client index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_AllCanSeeGlow(int client, float duration = 0.0);

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

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_glow_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_GetGlowSkin");
    MarkNativeAsOptional("TTT_SetGlowColor");
    MarkNativeAsOptional("TTT_SetGlowTeam");
    MarkNativeAsOptional("TTT_CanSeeGlow");
    MarkNativeAsOptional("TTT_CanSeeClientsGlow");
    MarkNativeAsOptional("TTT_CanSeeAllGlow");
    MarkNativeAsOptional("TTT_AllCanSeeGlow");
}
#endif
