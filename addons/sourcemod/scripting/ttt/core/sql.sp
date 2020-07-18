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

public void SQL_AlterRSlaysColumn(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        if (StrContains(error, "duplicate column name", false) != -1)
        {
            LateLoadClients(false);
        }
        else
        {
            LogError("(SQL_AlterRSlaysColumn) Query failed: %s", error);
        }
        
        return;
    }
    else
    {
        LateLoadClients(false);
    }
}

public void SQL_AlterNameColumn(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        if (StrContains(error, "duplicate column name", false) != -1)
        {
            LateLoadClients(false);
        }
        else
        {
            LogError("(SQL_AlterRSlaysColumn) Query failed: %s", error);
        }
        
        return;
    }
    else
    {
        LateLoadClients(false);
    }
}

public void SQL_CreateRoundTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CreateRoundTable) Query failed: %s", error);
        return;
    }
}

public void SQL_CreateLogTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CreateLogTable) Query failed: %s", error);
        return;
    }
    else
    {
        if (g_cDeleteLogsAfterDays.IntValue > 0)
        {
            int iSeconds = g_cDeleteLogsAfterDays.IntValue * 24 * 60 * 60;
            char sQuery[256];
            g_dDB.Format(sQuery, sizeof(sQuery), "DELETE FROM ttt_logs WHERE time <= (UNIX_TIMESTAMP() - %d);", iSeconds);
        }
    }
}

public void SQL_InsertRound(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if (db == null || strlen(error) > 0)
    {
        pack.Reset();
        pack.ReadCell();
        pack.ReadCell();
        pack.ReadCell();
        ArrayList aTraitors = view_as<ArrayList>(pack.ReadCell());
        delete aTraitors;
        delete pack;

        SetFailState("(SQL_InsertRound) Query failed: %s", error);
        return;
    }
    else
    {
        g_iRoundID = results.InsertId;
        g_iTeamSelectTime = GetTime();
        g_bBlockKill = false;

        if (g_cDebug.BoolValue)
        {
            PrintToServer("(SQL_InsertRound) g_iStatus set to %d from %d", Round_Active, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(SQL_InsertRound) g_iStatus set to %d from %d", Round_Active, g_iStatus);
            }
        }
        g_iStatus = Round_Active;

        pack.Reset();
        int iInnocents = pack.ReadCell();
        int iTraitors = pack.ReadCell();
        int iDetectives = pack.ReadCell();
        ArrayList aTraitors = view_as<ArrayList>(pack.ReadCell());
        delete pack;

        LoopValidClients(i)
        {
            if ((!g_cpublicKarma.BoolValue) && g_ckarmaRound.BoolValue)
            {
                g_iPlayer[i].KarmaStart = g_iPlayer[i].Karma;
                if(g_ckarmaRoundMessage.BoolValue)
                {
                    CPrintToChat(i, "%s %T", g_sTag, "All karma has been updated", i);
                }
            }

            if(g_cShowTeamsSelectedMessage.BoolValue)
            {
                CPrintToChat(i, "%s %T", g_sTag, "TEAMS HAS BEEN SELECTED", i);
            }

            if (g_iPlayer[i].Role != TTT_TEAM_TRAITOR)
            {
                CPrintToChat(i, "%s %T", g_sTag, "TRAITORS HAS BEEN SELECTED", i, iTraitors);
            }
            else
            {
                if (g_cShowTraitors.BoolValue)
                {
                    int iCount = 0;
                    bool bSend = false;

                    for (int j = 0; j < aTraitors.Length; j++)
                    {
                        int iTraitor = aTraitors.Get(j);

                        if (i == iTraitor)
                        {
                            continue;
                        }

                        if (!bSend)
                        {
                            CPrintToChat(i, "%s %T", g_sTag, "Your Traitor Partners", i);
                            bSend = true;
                        }

                        CPrintToChat(i, "%s %T", g_sTag, "Traitor List", i, g_iPlayer[iTraitor].Name);
                        iCount++;
                    }
                
                    if (iCount == 0)
                    {
                        CPrintToChat(i, "%s %T", g_sTag, "No Traitor Partners", i);
                    }
                }
            }

            if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
            {
                continue;
            }

            if (!IsPlayerAlive(i))
            {
                continue;
            }

            if (!g_cDebug.BoolValue && IsFakeClient(i))
            {
                continue;
            }

            TeamInitialize(i);

            if (g_cShowRoundIDMessage.BoolValue)
            {
                CPrintToChat(i, "%s %T", g_sTag, "Round ID Started", i, TTT_GetRoundID());
            }
        }

        delete aTraitors;

        char sMessage[128];
        Format(sMessage, sizeof(sMessage), "TTT Round #%d has been started!", TTT_GetRoundID());
        PushStringToLogs(sMessage);

        Call_StartForward(g_fwOnRoundStart);
        Call_PushCell(g_iRoundID);
        Call_PushCell(iInnocents);
        Call_PushCell(iTraitors);
        Call_PushCell(iDetectives);
        Call_Finish();
    }
}

public void SQL_UpdateRoundEndTime(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(SQL_UpdateRoundEndTime) Query failed: %s", error);
        return;
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
            g_iPlayer[client].KarmaReady = true;

            if (g_iPlayer[client].ID < 1)
            {
                g_iPlayer[client].ID = results.InsertId;
            }
        }
    }
}

public void Callback_UpdateRoundSlays(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(Callback_UpdateRoundSlays) Query failed: %s", error);
        return;
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

            g_iPlayer[client].ID = results.FetchInt(0);
            int karma = results.FetchInt(1);
            int rslays = results.FetchInt(2);

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 4 (%N) Karma: %d RSlays: %d", client, karma, rslays);

            if (g_cDebugMessages.BoolValue)
            {
                LogToFileEx(g_sLogFile, "Name: \"%L\" has %d karma and %d round slays", client, karma, rslays);
            }

            if (karma == 0)
            {
                g_iPlayer[client].Karma = g_cstartKarma.IntValue;
            }
            else
            {
                g_iPlayer[client].Karma = karma;
                g_iPlayer[client].RoundSlays = rslays;
            }

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 5 (%N), Karma (g): %d, RSlays (g): %d", client, g_iPlayer[client].Karma, g_iPlayer[client].RoundSlays);

            CS_SetClientContributionScore(client, karma);

            g_iPlayer[client].KarmaReady = true;

            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 5 (%N), Karma (gB): %d", client, g_iPlayer[client].KarmaReady);
        }
        else
        {
            g_iPlayer[client].Karma = g_cstartKarma.IntValue;
            LogToFileEx(g_sKarmaFile, "SQL_OnClientPutInServer - 1.1 (%N), Karma: %d", client, g_iPlayer[client].Karma);
            UpdatePlayer(client);
        }
    }
}

public void SQL_TransactionLogsError(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if (db == null || strlen(error) > 0)
    {
        LogError("(SQL_TransactionLogsError) Error executing query %d of %d queries: %s", failIndex, numQueries, error);
        return;
    }
}

public void SQL_ClearRounds(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(SQL_ClearRounds) Query failed: %s", error);
        return;
    }
}

public void SQL_ClearLogs(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogToFileEx(g_sErrorFile, "(SQL_ClearLogs) Query failed: %s", error);
        return;
    }
}
