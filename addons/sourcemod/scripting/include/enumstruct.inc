#if defined _enumstruct_included
    #endinput
#endif
#define _enumstruct_included

native PlayerData[] ES_ClientTest(int client);

public SharedPlugin __pl_enumstruct = 
{
    name = "enumstruct",
    file = "enumstruct.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_enumstruct_SetNTVOptional()
{
    MarkNativeAsOptional("ES_ClientTest");
}
#endif
