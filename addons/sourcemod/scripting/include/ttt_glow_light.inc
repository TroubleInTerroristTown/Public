#if defined _ttt_glow_light_included
    #endinput
#endif
#define _ttt_glow_light_included

public SharedPlugin __pl_ttt_glow_light = 
{
    name = "ttt_glow_light",
    file = "ttt_glow_light.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

/**
 * Gets the Glow Skin of a client.
 *
 * @param client            Client index.
 *
 * @returns entity index.
 */
native void TTT_GetGlowSkinLight(int client);

/**
 * Sets the color of a clients glow.
 *
 * @param client            Client index.
 * @param color             Color of the glow.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_SetGlowColorLight(int client, int color[4], float duration = 0.0);

/**
 * Sets the color of a clients glow.
 *
 * @param client            Client index.
 * @param team              Which Team color to set the glow to.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_SetGlowTeamLight(int client, int team, float duration = 0.0);

/**
 * Lets a client see the targets glow for the given duration.
 *
 * @param client            Client index.
 * @param target            Target index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeGlowLight(int client, int target, float duration = 0.0);

/**
 * Lets a client see the glow pf the passed targets for the given duration.
 *
 * @param client            Client index.
 * @param targets           Target indexs.
 * @param target_count      The amount of targets.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeClientsGlowLight(int client, int[] targets, int target_count, float duration = 0.0);

/**
 * Lets a client see the glow of all players for the given duration.
 *
 * @param client            Client index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_CanSeeAllGlowLight(int client, float duration = 0.0);

/**
 * Lets all players see the clients glow for the given duration.
 *
 * @param client            Client index.
 * @param duration          Duration of the overide, default 0.0 = persistent.
 */
native void TTT_AllCanSeeGlowLight(int client, float duration = 0.0);

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_glow_light_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_GetGlowSkinLight");
    MarkNativeAsOptional("TTT_SetGlowColorLight");
    MarkNativeAsOptional("TTT_SetGlowTeamLight");
    MarkNativeAsOptional("TTT_CanSeeGlowLight");
    MarkNativeAsOptional("TTT_CanSeeClientsGlowLight");
    MarkNativeAsOptional("TTT_CanSeeAllGlowLight");
    MarkNativeAsOptional("TTT_AllCanSeeGlowLight");
}
#endif
