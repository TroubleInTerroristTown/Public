#if defined _ttt_discord_included
    #endinput
#endif
#define _ttt_discord_included

native bool TTT_SendDiscordMessage(const char[] message, any ...);

public SharedPlugin __pl_ttt_discord = 
{
    name = "ttt_discord",
    file = "ttt_discord.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_discord_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_SendDiscordMessage");
}
#endif
