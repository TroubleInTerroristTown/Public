public void SQL_AlterKarmaColumn(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        if (StrContains(error, "duplicate column name", false) != -1)
        {
            LateLoadClients(false);
        }
        else
        {
            LogError("(SQL_AlterKarmaColumn) Query failed: %s", error);
        }
        
        return;
    }
    else
    {
        LateLoadClients(false);
    }
}

public void Callback_UpdatePlayer(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(Callback_UpdatePlayer) Query failed: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (TTT_IsClientValid(client))
        {
            g_bKarma[client] = true;
        }
    }
}

public void SQL_OnClientPutInServer(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 1 (%N)", client);
        LogToFileEx(g_sErrorFile, "(SQL_OnClientPutInServer) Query failed: %s", error);
        return;
    }
    else
    {
        if (results.RowCount > 0 && results.FetchRow())
        {
            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 2 (%N), RowCount: %d", client, results.RowCount);

            char sCommunityID[64];

            if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
            {
                LogToFileEx(g_sErrorFile, "(SQL_OnClientPutInServer) Auth failed: #%d", client);
                return;
            }

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 3 (%N)", client);

            int karma = results.FetchInt(0);

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 4 (%N) Karma: %d", client, karma);

            if (g_cDebugMessages.BoolValue)
            {
                LogToFileEx(g_sLogFile, "Name: \"%L\" has %d karma", client, karma);
            }

            if (karma == 0)
            {
                g_iKarma[client] = g_cstartKarma.IntValue;
            }
            else
            {
                g_iKarma[client] = karma;
            }

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 5 (%N), Karma (g): %d", client, g_iKarma[client]);

            CS_SetClientContributionScore(client, karma);

            g_bKarma[client] = true;

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 5 (%N), Karma (gB): %d", client, g_bKarma[client]);
        }
        else
        {
            g_iKarma[client] = g_cstartKarma.IntValue;
            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 1.1 (%N), Karma: %d", client, g_iKarma[client]);
            UpdatePlayer(client);
        }
    }
}
