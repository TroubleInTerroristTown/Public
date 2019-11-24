#if defined _CUSTOMKEYVALUES_INC_ 
	#endinput
#endif 
#define _CUSTOMKEYVALUES_INC_  

native bool GetCustomKeyValue( int entity, const char[] key, char[] value, int maxlen );
native bool SetCustomKeyValue( int entity, const char[] key, const char[] value, bool replace );

#if !defined REQUIRE_PLUGIN
public void __pl_customkeyvalues_SetNTVOptional()
{
    MarkNativeAsOptional("GetCustomKeyValue");
    MarkNativeAsOptional("SetCustomKeyValue");
}
#endif  

public SharedPlugin __pl_customkeyvalues = 
{
	name = "CustomKeyValues",
	file = "customkeyvalues.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};