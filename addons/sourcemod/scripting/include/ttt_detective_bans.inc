#if defined _ttt_detective_bans_included
    #endinput
#endif
#define _ttt_detective_bans_included

/**
 * Called when the player receives ban for playing on detectives team.
 *
 * @param client            The client index
 * @param time              Ban time in seconds
 * @param reason            Reason why he was banned
 */
forward void TTT_OnDetectiveBan(int client, int time, const char[] reason);

/**
 * Called when the player receives unban for playing on detectives team.
 *
 * @param client            The client index
 */
forward void TTT_OnDetectiveUnBan(int client);

/**
 * Check if client is banned for playing in detectives team
 *
 * @param client            The client index
 * 
 * @return                  True if banned, false otherwise
 */
native bool TTT_IsDetectiveBanned(int client);

/**
 * Ban player for playing in detectives team
 *
 * @param client            The client index
 * @param target            The target index
 * @param time              Ban length in seconds
 * @param reason            Ban reason
 */
native void TTT_AddDetectiveBan(int client, int target, int time, const char[] reason);

/**
 * Unban player for playing in detectives team
 *
 * @param client            The client index
 * @param target            The target index
 */
native void TTT_RemoveDetectiveBan(int client, int target);


public SharedPlugin __pl_ttt_detective_bans = 
{
    name = "ttt_detective_bans",
    file = "ttt_detective_bans.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_detective_bans_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_IsDetectiveBanned");
    MarkNativeAsOptional("TTT_AddDetectiveBan");
    MarkNativeAsOptional("TTT_RemoveDetectiveBan");
}
#endif
