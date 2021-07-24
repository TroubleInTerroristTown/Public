#if defined _ttt_overlay_included
    #endinput
#endif
#define _ttt_overlay_included

/*
 * If you want to display your own overlay for a few seconds
 * NOTE: Time Overlays will be not disabled!
 *
 * @param client            Client index.
 * @param client            Karma that will be added.
 */
native void TTT_DisableRoleOverlays(float fTime);

native void TTT_PrecacheWinOverlay(const char[] role);
native void TTT_PrecacheIconOverlay(const char[] role);

forward Action Overlay_OnPrecacheWinOverlay(char[] path, int maxlen);
forward Action Overlay_OnPrecacheRoleOverlay(char[] path, int maxlen);
forward Action Overlay_OnWinOverlay(int team, int role, char[] path, int maxlen);
forward Action Overlay_OnRoleOverlay(int client, char[] path, int maxlen);

public SharedPlugin __pl_ttt_overlay = 
{
    name = "ttt_overlay",
    file = "ttt_overlay.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_overlay_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_DisableRoleOverlay");
}
#endif
