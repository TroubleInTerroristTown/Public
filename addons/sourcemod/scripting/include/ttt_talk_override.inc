#if defined _ttt_talk_override_included
    #endinput
#endif
#define _ttt_talk_override_included

forward Action TTT_OnTraitorVoice(int client, bool &status, bool &message);

native bool TTT_GetTraitorVoice(int client);
native bool TTT_SetTraitorVoice(int client, bool status, bool message = false);

public SharedPlugin __pl_ttt_talk_override = 
{
    name = "ttt_talk_override",
    file = "ttt_talk_override.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
