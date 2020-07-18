#if defined _ttt_haste_included
    #endinput
#endif
#define _ttt_haste_included


native bool TTT_IsHasteActive();
native int TTT_SetHasteTime(int time);
native int TTT_AddHasteTime(int time);
native int TTT_RemoveHasteTime(int time);

public SharedPlugin __pl_ttt_haste = 
{
    name = "ttt_haste",
    file = "ttt_haste.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ttt_haste_SetNTVOptional()
{
    MarkNativeAsOptional("TTT_IsHasteActive");
    MarkNativeAsOptional("TTT_SetHasteTime");
    MarkNativeAsOptional("TTT_AddHasteTime");
    MarkNativeAsOptional("TTT_RemoveHasteTime");
}
#endif
