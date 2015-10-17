#if defined _convar_append_included
 #endinput
#endif
#define _convar_append_included

#define _convar_append_v2_1
#define CONVAR_APPEND_MAXCHARS 4096 // change "4096" to higher if AutoExecConfigAppend do not append all ConVars

// ConVarAppend by Raska aka KissLick, feel free to modify but credit me please.. :-)

/**
 * Append new ConVars to config file on new plugin version.
 *
 * @param name			Name of the config file, excluding the .cfg extension.
 *						If empty, <plugin.filename.cfg> is assumed.
 * @param folder		Folder under cfg/ to use.  By default this is "sourcemod."
 * @param AppendNote	Note for server master about appended ConVars or just about appending.
 * @param AlwaysAppend	Always try to append new ConVars and do not look at plugin version. (useful for developer release)
 * @noreturn
 */
stock AutoExecConfigAppend( const String:name[] = "", const String:folder[] = "sourcemod", String:AppendNote[ 512 ] = "", bool:AlwaysAppend = false )
{
	decl String:CommandOutPut[ CONVAR_APPEND_MAXCHARS ];
	decl String:PluginFileName[ 256 ];
	decl String:PluginVersion[ 16 ];
	decl String:ConfigName[ PLATFORM_MAX_PATH ];
	new Handle:FileHandle = INVALID_HANDLE;
	decl String:FileLine[ 256 ];
	GetPluginFilename( INVALID_HANDLE , PluginFileName, sizeof( PluginFileName ) );	
	GetPluginInfo( INVALID_HANDLE, PlInfo_Version, PluginVersion, sizeof( PluginVersion ) );
	
	strcopy( ConfigName, FindCharInString( PluginFileName, '.' ) + 1, PluginFileName );
	if( strlen( name ) == 0 )
	{
		Format( ConfigName, sizeof( ConfigName ), "plugin.%s", ConfigName );
	}
	else
	{
		strcopy( ConfigName, sizeof( ConfigName ), name );
	}
	
	AutoExecConfig( false, ConfigName, folder );
	
	// Build path
	Format( ConfigName, sizeof( ConfigName ), "cfg/%s/%s.cfg", folder, ConfigName );
	
	// Check plugin version
	new bool:VersionAlreadyAppended = false;
	FileHandle = OpenFile( ConfigName, "r" );
	if( FileHandle != INVALID_HANDLE )
	{
		while( !IsEndOfFile( FileHandle ) && ReadFileLine( FileHandle, FileLine, sizeof( FileLine ) ) )
		{
			TrimString( FileLine );
			
			if( strlen( FileLine ) == 0 )
				continue;
			
			if( FileLine[ 0 ] != '/' || FileLine[ 1 ] != '/' )
				continue;
			
			if( ReplaceStringEx( FileLine, sizeof( FileLine ), "// @version:", "" ) != -1 )
			{
				TrimString( FileLine );
				
				if( StrEqual( FileLine, PluginVersion ) )
					VersionAlreadyAppended = true;
			}
		}
		CloseHandle( FileHandle );
	}
	
	if( VersionAlreadyAppended && !AlwaysAppend )
		return;
	
	// Append info about new version	
	if( !VersionAlreadyAppended )
	{
		FileHandle = OpenFile( ConfigName, "a" );	
		WriteFileLine( FileHandle, "// Append new ConVars for plugin %s", PluginFileName );
		WriteFileLine( FileHandle, "// @version: %s", PluginVersion );
		if( strlen( AppendNote ) != 0 )
		{
			ReplaceString( AppendNote, sizeof( AppendNote ), "\n", "\n// " );
			WriteFileLine( FileHandle, "// @note: %s", AppendNote );
		}
		WriteFileLine( FileHandle, "" );	
		LogMessage( "ConVars appended to file \"%s\" (version: \"%s\")", ConfigName, PluginVersion );
		CloseHandle( FileHandle );
	}
	
	// Load sConVar list
	ServerCommandEx( CommandOutPut, sizeof( CommandOutPut ), "sm cvars %s", PluginFileName );	
	strcopy( CommandOutPut, sizeof( CommandOutPut ), CommandOutPut[  FindCharInString( CommandOutPut, '\n' ) + 1 ] );
	strcopy( CommandOutPut, sizeof( CommandOutPut ), CommandOutPut[  FindCharInString( CommandOutPut, '\n' ) + 1 ] );
	TrimString( CommandOutPut );
	
	decl String:sConVar[ 256 ];
	new Handle:ConVarsList = INVALID_HANDLE;
	new index = SplitString( CommandOutPut, " ", sConVar, sizeof( sConVar ) );
	ConVarsList = CreateArray( 256 );
	
	while( index != -1 )
	{
		PushArrayString( ConVarsList, sConVar );
		
		if( FindCharInString( CommandOutPut, '\n' ) + 1 == EOS )
			break;
		
		strcopy( CommandOutPut, sizeof( CommandOutPut ), CommandOutPut[ FindCharInString( CommandOutPut, '\n' ) + 1 ] );
		TrimString( CommandOutPut );
		index = SplitString( CommandOutPut, " ", sConVar, sizeof( sConVar ) );
	}
		
	// Filter ConVars
	FileHandle = OpenFile( ConfigName, "r" );	
	if( FileHandle != INVALID_HANDLE )
	{
		while( !IsEndOfFile( FileHandle ) && ReadFileLine( FileHandle, FileLine, sizeof( FileLine ) ) )
		{
			TrimString( FileLine );
			
			if( FileLine[ 0 ] == '/' && FileLine[ 1 ] == '/' )
				continue;
			
			if( strlen( FileLine ) == 0 )
				continue;
			
			index = SplitString( FileLine, " ", sConVar, sizeof( sConVar ) );
			
			if( index != -1 )
			{
				index = FindStringInArray( ConVarsList, sConVar );
				if( index != -1 )
				{
					RemoveFromArray( ConVarsList, index );
				}
			}
		}
		CloseHandle( FileHandle );
	}
	
	
	if( GetArraySize( ConVarsList ) < 1 )
		return;
	
	// Append new ConVars	
	new Handle:ConVarHandle = INVALID_HANDLE;
	new Handle:ConVarIterator = INVALID_HANDLE;
	new Float:ConVarBound;
	decl String:ConVarDescription[ 512 ];
	decl String:ConVarDefault[ 256 ];
	decl String:ConVarValue[ 256 ];
	decl String:Name[64];
	new flags, bool:isCommand;
	
	FileHandle = OpenFile( ConfigName, "a" );
	for( new i = 0; i < GetArraySize( ConVarsList ); i++ )
	{
		GetArrayString( ConVarsList, i, sConVar, sizeof( sConVar ) );
		
		ConVarHandle = FindConVar( sConVar );
		
		if( ConVarHandle == INVALID_HANDLE )
			continue;
		
		ConVarIterator = FindFirstConCommand( Name, sizeof( Name ), isCommand, flags, ConVarDescription, sizeof( ConVarDescription ) );
		if( ConVarIterator == INVALID_HANDLE )
			continue;

		do
		{
			if( isCommand || !StrEqual( Name, sConVar ) )
				continue;
			
			break;
		}while( FindNextConCommand( ConVarIterator, Name, sizeof( Name ), isCommand, flags, ConVarDescription, sizeof( ConVarDescription ) ) );
		CloseHandle( ConVarIterator );
		
		ReplaceString( ConVarDescription, sizeof( ConVarDescription ), "\n", "\n// " );
		WriteFileLine( FileHandle, "// %s", ConVarDescription );
		WriteFileLine( FileHandle, "// -" );
		
		GetConVarDefault( ConVarHandle, ConVarDefault, sizeof( ConVarDefault ) );
		WriteFileLine( FileHandle, "// Default: \"%s\"", ConVarDefault );
		
		if( GetConVarBounds( ConVarHandle, ConVarBound_Lower, ConVarBound ) )
			WriteFileLine( FileHandle, "// Minimum: \"%f\"", ConVarBound );
		
		if( GetConVarBounds( ConVarHandle, ConVarBound_Upper, ConVarBound ) )
			WriteFileLine( FileHandle, "// Maximum: \"%f\"", ConVarBound );
		
		GetConVarString( ConVarHandle, ConVarValue, sizeof( ConVarValue ) );
		WriteFileLine( FileHandle, "%s \"%s\"", sConVar, ConVarValue );
		WriteFileLine( FileHandle, "" );
		
	}
	
	CloseHandle( ConVarsList );
	CloseHandle( FileHandle );
}