#if defined _ttt_icon_included
    #endinput
#endif
#define _ttt_icon_included

native void TTT_SetIcon(int client, int role);

forward Action Icon_OnPrecache(char[] path, int maxlen);
forward Action Icon_OnIconCreate(int client, char[] path, int maxlen, bool &treatAsTraitor);

public SharedPlugin __pl_ttt_icon = 
{
    name = "ttt_icon",
    file = "ttt_icon.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_icon_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_SetIcon");
}
#endif
