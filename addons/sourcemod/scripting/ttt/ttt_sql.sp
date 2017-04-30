#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <ttt_sql>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - SQL Manager"

Database g_dDatabase = null;

char g_sEntry[32];

int g_cRetries = -1;
int g_iRetries = -1;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

Handle g_hOnConnect = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_Query", Native_Query);
	CreateNative("TTT_GetSQLConnection", Native_GetSQLConnection);
	
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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/sql.cfg");

	Config_Setup("TTT-SQL", g_sConfigFile);
	
	g_cRetries = Config_LoadInt("sql_max_retries", 3, "The amount of retries after first failed connection");
	Config_LoadString("sql_database_entry_name", "ttt", "The name of the entry in your databases.cfg", g_sEntry, sizeof(g_sEntry));
	Config_Done();
	
	g_iRetries = 0;
	
	SQL_Start();
}

void SQL_Start()
{
	if (g_dDatabase != null)
	{
		LogError("%s is already connected! (Handle: %d)", g_sEntry, g_dDatabase);
		return;
	}
	
	if (g_iRetries > g_cRetries)
	{
		LogError("Can't connect to a database after %d retries!", g_iRetries-1);
		return;
	}
	
	if (g_iRetries >= 1 && g_iRetries <= g_cRetries)
	{
		LogMessage("We try again to connect to a database (Retry #%d)!", g_iRetries);
	}
	
	if (g_iRetries == g_cRetries)
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
			CheckAndCreateTables("sqlite");
			return;
		}
	}
	
	if (!SQL_CheckConfig(g_sEntry) && g_iRetries < g_cRetries)
	{
		char sError[255];
		g_dDatabase = SQL_Connect(g_sEntry, true, sError, sizeof(sError));
		
		if (strlen(sError) > 1)
		{
			LogError("(SQL_Start) Error: %s", sError);
		}

		if (g_dDatabase == null)
		{
			LogError("(SQL_Start) Database failure: Couldn't connect to \"%s\"!", g_sEntry);
			CreateTimer(5.0, Timer_Retry);
			return;
		}
		else
		{
			LogMessage("(SQL_Start) We have a connection!");
			CheckAndCreateTables("sqlite");
			return;
		}
	}
	else
	{
		Database.Connect(OnConnect, g_sEntry);
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
	char sDriver[16];
	iDriver.GetIdentifier(sDriver, sizeof(sDriver));

	if (!StrEqual(sDriver, "mysql", false) && !StrEqual(sDriver, "sqlite", false))
	{
		SetFailState("(OnConnect) TTT has only MySQL and SQLite support!");
		return;
	}
	
	g_dDatabase = db;
	
	CheckAndCreateTables(sDriver);
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

void CheckAndCreateTables(const char[] driver)
{
	char sQuery[256];
	if (StrEqual(driver, "mysql", false))
	{
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` ( `id` INT NOT NULL AUTO_INCREMENT , `communityid` VARCHAR(64) NOT NULL , `karma` INT(11) NULL , PRIMARY KEY (`id`), UNIQUE (`communityid`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
	}
	else if (StrEqual(driver, "sqlite", false))
	{
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` (`communityid` VARCHAR(64) NOT NULL DEFAULT '', `karma` INT NOT NULL DEFAULT 0, PRIMARY KEY (`communityid`));");
	}
	
	TTT_Query("Callback_CheckAndCreateTables", sQuery);
	
	Call_OnSQLConnect();
	
	SetCharsetAndCollate(driver);
}

void SetCharsetAndCollate(const char[] driver)
{
	if (StrEqual(driver, "mysql", false))
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

public int Native_GetSQLConnection(Handle plugin, int numParams)
{
	return view_as<int>(g_dDatabase);
}
