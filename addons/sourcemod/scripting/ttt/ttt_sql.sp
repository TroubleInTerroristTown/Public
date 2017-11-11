#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_sql>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - SQL Manager"

Database g_dDatabase = null;

ConVar g_cEntry = null;
ConVar g_cRetries = null;

char g_sType[18];
int g_iRetries = -1;

Handle g_hOnConnect = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_Query", Native_Query);
	CreateNative("TTT_GetSQLConnection", Native_GetSQLConnection);
	CreateNative("TTT_GetConnectionType", Native_GetConnectionType);

	g_hOnConnect = CreateGlobalForward("TTT_OnSQLConnect", ET_Ignore, Param_Cell);

	RegPluginLibrary("ttt_sql");

	return APLRes_Success;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	StartConfig("sql");
	CreateConVar("ttt2_sql_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cRetries = AutoExecConfig_CreateConVar("sql_max_retries", "3", "The amount of retries after first failed connection");
	g_cEntry = AutoExecConfig_CreateConVar("sql_database_entry_name", "ttt", "The name of the entry in your databases.cfg");
	EndConfig();

	g_iRetries = 0;
}

public void OnConfigsExecuted()
{
	SQL_Start();
}

void SQL_Start()
{
	char sEntry[32];
	g_cEntry.GetString(sEntry, sizeof(sEntry));
	
	if (g_dDatabase != null)
	{
		LogMessage("%s is already connected! (Handle: %d)", sEntry, g_dDatabase);
		Call_OnSQLConnect();
		return;
	}

	if (g_iRetries > g_cRetries.IntValue)
	{
		LogError("Can't connect to a database after %d retries!", g_iRetries-1);
		return;
	}

	if (g_iRetries >= 1 && g_iRetries <= g_cRetries.IntValue)
	{
		LogMessage("We try again to connect to a database (Retry #%d)!", g_iRetries);
	}

	if (g_iRetries == g_cRetries.IntValue)
	{
		LogMessage("Last chance with sqlite. Let me try it!");

		KeyValues kvDatabase = CreateKeyValues("Databases");

		kvDatabase.SetString("driver", "sqlite");
		kvDatabase.SetString("host", "localhost");
		kvDatabase.SetString("database", "ttt");
		kvDatabase.SetString("user", "root");

		char sError[255];
		g_dDatabase = SQL_ConnectCustom(kvDatabase, sError, sizeof(sError), true);

		if (strlen(sError) > 1)
		{
			LogError("(SQL_Start) Error: %s", sError);
		}

		if (g_dDatabase == null)
		{
			LogError("(SQL_Start) We can't connect to a database... :(");
			return;
		}
		else
		{
			LogMessage("(SQL_Start) We have a connection!");
			DBDriver iDriver = g_dDatabase.Driver;
			iDriver.GetIdentifier(g_sType, sizeof(g_sType));
			CheckAndCreateTables();
			return;
		}
	}

	if (!SQL_CheckConfig(sEntry) && g_iRetries < g_cRetries.IntValue)
	{
		char sError[255];
		g_dDatabase = SQL_Connect(sEntry, true, sError, sizeof(sError));

		if (strlen(sError) > 1)
		{
			LogError("(SQL_Start) Error: %s", sError);
		}

		if (g_dDatabase == null)
		{
			LogError("(SQL_Start) Database failure: Couldn't connect to \"%s\"!", sEntry);
			CreateTimer(5.0, Timer_Retry);
			return;
		}
		else
		{
			LogMessage("(SQL_Start) We have a connection!");
			DBDriver iDriver = g_dDatabase.Driver;
			iDriver.GetIdentifier(g_sType, sizeof(g_sType));
			CheckAndCreateTables();
			return;
		}
	}
	else
	{
		Database.Connect(OnConnect, sEntry);
	}
}

public void OnConnect(Database db, const char[] error, any data)
{
	if (db == null || strlen(error) > 0)
	{
		LogError("(OnConnect) Connection to database failed: %s", error);
		CreateTimer(5.0, Timer_Retry);
		return;
	}

	DBDriver iDriver = db.Driver;
	iDriver.GetIdentifier(g_sType, sizeof(g_sType));

	if (!StrEqual(g_sType, "mysql", false) && !StrEqual(g_sType, "sqlite", false))
	{
		SetFailState("(OnConnect) TTT has only MySQL and SQLite support!");
		return;
	}

	g_dDatabase = db;

	CheckAndCreateTables();
}

public Action Timer_Retry(Handle timer)
{
	g_iRetries++;
	SQL_Start();
}

void Call_OnSQLConnect()
{
	Call_StartForward(g_hOnConnect);
	Call_PushCell(g_dDatabase);
	Call_Finish();
}

void CheckAndCreateTables()
{
	char sQuery[256];
	if (StrEqual(g_sType, "mysql", false))
	{
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` ( `id` INT NOT NULL AUTO_INCREMENT , `communityid` VARCHAR(64) NOT NULL , `karma` INT(11) NULL , PRIMARY KEY (`id`), UNIQUE (`communityid`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
	}
	else if (StrEqual(g_sType, "sqlite", false))
	{
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` (`communityid` VARCHAR(64) NOT NULL DEFAULT '', `karma` INT NOT NULL DEFAULT 0, PRIMARY KEY (`communityid`));");
	}

	TTT_Query("Callback_CheckAndCreateTables", sQuery);

	Call_OnSQLConnect();

	SetCharsetAndCollate();
}

void SetCharsetAndCollate()
{
	if (StrEqual(g_sType, "mysql", false))
	{
		g_dDatabase.SetCharset("utf8mb4");
		TTT_Query("SQLCallback_OnSetNames", "SET NAMES 'utf8mb4';");
		TTT_Query("SQLCallback_ConvertToUTF8MB4", "ALTER TABLE ttt CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
	}
}

public int Native_Query(Handle plugin, int numParams)
{
	char debugname[32];
	char query[1024];
	GetNativeString(1, debugname, sizeof(debugname));
	GetNativeString(2, query, sizeof(query));

	g_dDatabase.Query(SQL_QueryCB, query, StringToInt(debugname));

	return 0;
}

public void SQL_QueryCB(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || strlen(error) > 0)
	{
		char sBuffer[128];
		IntToString(data, sBuffer, sizeof(sBuffer));
		LogError("[TTT] (%s) Query failed: %s", sBuffer, error);
		return;
	}
}

public int Native_GetConnectionType(Handle plugin, int numParams)
{
	if (StrEqual(g_sType, "mysql", false))
	{
		return dMySQL;
	}
	else if (StrEqual(g_sType, "sqlite", false))
	{
		return dSQLite;
	}
	
	return -1;
}

public int Native_GetSQLConnection(Handle plugin, int numParams)
{
	return view_as<int>(g_dDatabase);
}
