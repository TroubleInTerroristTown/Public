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

public void SQL_OnClientPostAdminCheck(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);

    if (!client || !TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(SQL_OnClientPostAdminCheck) Query failed: %s", error);
        return;
    }
    else
    {
        if (!results.HasResults)
        {
            g_iKarma[client] = g_cstartKarma.IntValue;
            UpdatePlayer(client);
        }
        else
        {
            while (results.FetchRow())
            {
                char sCommunityID[64];

                if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
                {
                    LogToFileEx(g_sErrorFile, "(SQL_OnClientPostAdminCheck) Auth failed: #%d", client);
                    return;
                }

                int karma = results.FetchInt(0);

                if (g_cDebug.BoolValue)
                {
                    LogToFileEx(g_sLogFile, "Name: %L has %d karma", client, karma);
                }

                if (karma == 0)
                {
                    g_iKarma[client] = g_cstartKarma.IntValue;
                }
                else
                {
                    g_iKarma[client] = karma;
                }

                CS_SetClientContributionScore(client, karma);

                g_bKarma[client] = true;
            }
        }
    }
}
