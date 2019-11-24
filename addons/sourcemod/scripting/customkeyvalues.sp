#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <customkeyvalues>
#include <dhooks>

public Plugin myinfo =
{
	name = "CustomKeyValues",
	author = "SlidyBat",
	description = "Allows easy transfer of data from maps to plugins",
	version = "1.0",
	url = ""
}

methodmap EntityMap < StringMap
{
	public EntityMap()
	{
		return view_as<EntityMap>( new StringMap() );
	}
	public bool GetEntityValue( int entity, const char[] key, char[] value, int maxlen )
	{
		if (entity > -1)
			entity = EntIndexToEntRef( entity );
		
		char refstring[8];
		IntToString( entity, refstring, sizeof(refstring) );
	
		StringMap keyvals;
		PrintToChatAll("GetEntityValue - 1");
		if( !this.GetValue( refstring, keyvals ) )
		{
			PrintToChatAll("GetEntityValue - 1.1");
			return false;
		}

		bool bValue = keyvals.GetString( key, value, maxlen );
		PrintToChatAll("GetEntityValue - 2 (keyvals.GetString->%d)", bValue);
		
		return bValue;
	}
	public bool SetEntityValue( int entity, const char[] key, const char[] value, bool replace = true )
	{
		if (entity > -1)
			entity = EntIndexToEntRef( entity );
		
		char refstring[8];
		IntToString( entity, refstring, sizeof(refstring) );
	
		StringMap keyvals;
		if( !this.GetValue( refstring, keyvals ) )
		{
			keyvals = new StringMap();
			if( !this.SetValue( refstring, keyvals ) )
			{
				return false;
			}
		}
		
		return keyvals.SetString( key, value, replace );
	}
	public void Close()
	{
		StringMapSnapshot snapshot = this.Snapshot();
		
		int len = snapshot.Length;
		for( int i = 0; i < len; i++ )
		{
			char key[128];
			snapshot.GetKey( i, key, sizeof(key) );
			
			StringMap sm;
			if( this.GetValue( key, sm ) )
			{
				delete sm;
			}
		}
		
		delete this;
	}
}

EntityMap g_EntityKeyValues;
Handle g_hOnKeyValue;

public APLRes AskPluginLoad2( Handle myself, bool late, char[] error, int err_max )
{
	CreateNative( "GetCustomKeyValue", Native_GetCustomKeyValue );
	CreateNative( "SetCustomKeyValue", Native_SetCustomKeyValue );
	
	RegPluginLibrary( "CustomKeyValues" );
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_EntityKeyValues = new EntityMap();
}

public void OnLevelInit( const char[] mapname, char mapEntities[2097152] )
{
	if( g_EntityKeyValues != null )
	{
		g_EntityKeyValues.Close();
	}
	
	g_EntityKeyValues = new EntityMap();
}

public void OnAllPluginsLoaded()
{
	if( g_hOnKeyValue == null && LibraryExists( "dhooks" ) )
	{
		Initialize();
	}
}

public void OnLibraryAdded( const char[] name )
{
	if( StrEqual( name, "dhooks" ) && g_hOnKeyValue == null )
	{
		Initialize();
    }
}

void Initialize()
{
	Handle hGameData = LoadGameConfigFile( "customkeyvalues.games" );
	if( hGameData == null )
		return;
	
	int offset = GameConfGetOffset( hGameData, "CBaseEntity::KeyValue" );
	
	delete hGameData;
	
	if( offset == -1 )
		return;
	
	g_hOnKeyValue = DHookCreate( offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, Hook_OnKeyValue );
	
	if(g_hOnKeyValue == null)
	{
		SetFailState("Failed to create CBaseEntity::KeyValue hook");
		return;
	}
	
	DHookAddParam( g_hOnKeyValue, HookParamType_CharPtr );
	DHookAddParam( g_hOnKeyValue, HookParamType_CharPtr );
}

public void OnEntityCreated( int entity, const char[] classname )
{
	DHookEntity( g_hOnKeyValue, true, entity );
}

public MRESReturn Hook_OnKeyValue( int pThis, Handle hReturn, Handle hParams )
{
    char classname[64];
    GetEntityClassname( pThis, classname, sizeof(classname) );
    if( !StrEqual( classname, "func_physbox" ) )
    {
        return MRES_Ignored;
    }

    LogMessage( "==== func_physbox KeyValue ====" );
    
    char key[128];
    DHookGetParamString( hParams, 1, key, sizeof(key) );
    char value[128];
    DHookGetParamString( hParams, 2, value, sizeof(value) );

    if( DHookGetReturn( hReturn ) )
    {
        LogMessage( "Ignoring game KV (%s : %s)", key, value );
        return MRES_Ignored;
    }
    
    LogMessage( "%s : %s", key, value );
    
    g_EntityKeyValues.SetEntityValue( pThis, key, value );
    
    return MRES_Ignored;
}

public int Native_GetCustomKeyValue( Handle plugin, int params )
{
	int entity = GetNativeCell( 1 );
	char key[128];
	GetNativeString( 2, key, sizeof(key) );
	char value[128];
	int maxlen = GetNativeCell( 4 );
	PrintToChatAll("Native_GetCustomKeyValue - 1");
	if( g_EntityKeyValues.GetEntityValue( entity, key, value, maxlen ) )
	{
		PrintToChatAll("Native_GetCustomKeyValue - 1.1");
		SetNativeString( 3, value, maxlen );
		return true;
	}
	PrintToChatAll("Native_GetCustomKeyValue - 2");
	
	return false;
}

public int Native_SetCustomKeyValue( Handle plugin, int params )
{
	int entity = GetNativeCell( 1 );
	char key[128];
	GetNativeString( 2, key, sizeof(key) );
	char value[128];
	GetNativeString( 3, value, sizeof(value) );
	bool replace = GetNativeCell( 4 );
	
	return g_EntityKeyValues.SetEntityValue( entity, key, value, replace );
}