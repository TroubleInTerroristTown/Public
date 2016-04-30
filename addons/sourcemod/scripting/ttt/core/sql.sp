void SQL_Start()
{
	if (!SQL_CheckConfig("ttt"))
	{
		char error[255];
		Handle kv = null;

		kv = CreateKeyValues("");
		KvSetString(kv, "database", "ttt");
		g_hDatabase = SQL_ConnectCustom(kv, error, sizeof(error), true);
		delete kv;

		if(g_hDatabase == null)
		{
			SetFailState("(OnPluginStart) Database failure: Couldn't find Database entry \"ttt\" and can't use SQlite as default.");
			return;
		}

		CheckAndCreateTables("sqlite");
		SQL_SetCharset(g_hDatabase, "utf8");
		LoadClients();
	}
	else SQL_TConnect(SQLConnect, "ttt");
}

public void SQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null || strlen(error) > 0)
	{
		SetFailState("(SQLConnect) Connection to database failed!: %s", error);
		return;
	}

	char sDriver[16];
	SQL_GetDriverIdent(owner, sDriver, sizeof(sDriver));

	if (!StrEqual(sDriver, "mysql", false) && !StrEqual(sDriver, "sqlite", false))
	{
		SetFailState("(SQLConnect) Only mysql/sqlite support!");
		return;
	}

	g_hDatabase = CloneHandle(hndl);

	CheckAndCreateTables(sDriver);

	SQL_SetCharset(g_hDatabase, "utf8mb4");
	SQL_TQuery(g_hDatabase, SQLCallback_OnSetNames, "SET NAMES 'utf8mb4';");
	SQL_TQuery(g_hDatabase, SQLCallback_ConvertToUTF8MB4, "ALTER TABLE ttt CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");

	LoadClients();
}

stock void CheckAndCreateTables(const char[] driver)
{
	char sQuery[256];
	if (StrEqual(driver, "mysql", false))
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` ( `id` INT NOT NULL AUTO_INCREMENT , `communityid` VARCHAR(64) NOT NULL , `karma` INT(11) NULL , PRIMARY KEY (`id`), UNIQUE (`communityid`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
	else if (StrEqual(driver, "sqlite", false))
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt` (`communityid` VARCHAR(64) NOT NULL DEFAULT '', `karma` INT NOT NULL DEFAULT 0, PRIMARY KEY (`communityid`)) DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");

	SQL_TQuery(g_hDatabase, Callback_CheckAndCreateTables, sQuery);
}

public int SQLCallback_OnSetNames(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(SQLCallback_OnSetNames) Query failed: %s", error);
		return;
	}
}

public int SQLCallback_ConvertToUTF8MB4(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(SQLCallback_ConvertToUTF8MB4) Query failed: %s", error);
		return;
	}
}

public void Callback_CheckAndCreateTables(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(SQLCallback_Create) Query failed: %s", error);
		return;
	}
}

public void Callback_Karma(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(Callback_Karma) Query failed: %s", error);
		return;
	}
}
public void Callback_InsertPlayer(Handle owner, Handle hndl, const char[] error, any userid)
{
	if(hndl == null || strlen(error) > 0)
	{
		LogToFileEx(g_iConfig[s_errFile], "(Callback_InsertPlayer) Query failed: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(userid);

		if(TTT_IsClientValid(client))
			g_bKarma[client] = true;
	}
}
