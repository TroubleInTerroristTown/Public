void Db_InsertDeath(int victim, int attacker)
{
    int victimId = TTT_GetPlayerID(victim);

    if (victimId < 1)
    {
        LogError("Invalid TTT_PlayerID in 'Db_InsertDeath' from client %d", victim);
        return;
    }

    int victimTeam = TTT_GetClientTeam(victim);
    char sVictimTeam[10] = "none";
    RoleEnum(sVictimTeam, sizeof(sVictimTeam), victimTeam);

    int attackerId = TTT_GetPlayerID(attacker);
    
    if (attackerId < 1)
    {
        LogError("Invalid TTT_PlayerID in 'Db_InsertDeath' from client %d", attacker);
        return;
    }

    int attackerTeam = TTT_GetClientTeam(attacker);
    char sAttackerTeam[10] = "none";
    RoleEnum(sAttackerTeam, sizeof(sAttackerTeam), attackerTeam);

    char query[768];
    Format(
        query, sizeof(query), "INSERT INTO `deaths` (`death_time`, `victim_id`, `victim_role`, `attacker_id`, `attacker_role`, `last_gun_fire`, `round`) VALUES ('%d', '%d', '%s', '%d', '%s', '%d', '%d');",
        GetTime(), victimId, sVictimTeam, attackerId, sAttackerTeam, g_playerData[victim].lastGunFired, g_iCurrentRound);
    g_dbDatabase.Query(DbCallback_InsertDeath, query);
}

public void DbCallback_InsertDeath(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("DbCallback_InsertDeath: %s", error);
        return;
    }
}

void Db_InsertHandle(int client, int death)
{
    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sName, sizeof(sName));
    CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Staff Handle - Has taken Case", LANG_SERVER, sName);

    int accountID = TTT_GetPlayerID(client);

    char query[768];
    Format(query, sizeof(query), "INSERT INTO `handles` (`death_index`, `admin_id`) VALUES ('%d', '%d');", death, accountID);
    g_dbDatabase.Query(DbCallback_InsertHandle, query, GetClientUserId(client));
}

public void DbCallback_InsertHandle(Database db, DBResultSet results, const char[] error, any userid)
{
    if (results == null)
    {
        LogError("DbCallback_InsertHandle: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    Db_SelectCaseBaseInfo(client);
}

void Db_InsertReport(int client, int death, CaseChoice punishment)
{
    char sPunishment[5] = "none";
    if (punishment == CaseChoice_Slay)
    {
        sPunishment = "slay";
    }
    else if (punishment == CaseChoice_Warn)
    {
        sPunishment = "warn";
    }

    char query[768];
    Format(query, sizeof(query), "INSERT INTO `reports` (`death_index`, `punishment`) VALUES ('%d', '%s');", death, sPunishment);
    g_dbDatabase.Query(DbCallback_InsertReport, query, GetClientUserId(client));
}

public void DbCallback_InsertReport(Database db, DBResultSet results, const char[] error, any userid)
{
    if (results == null)
    {
        LogError("DbCallback_InsertReport: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    CPrintToChat(client, "%T", "RDM: Report - Acknowledge submission", client);

    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sName, sizeof(sName));
    CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Report - Notify Staff", LANG_SERVER, sName);

    Db_SelectCaseCount();
}

void Db_SelectCaseCount()
{
    char query[768];
    Format(query, sizeof(query), "SELECT COUNT(*) AS `case_count` FROM `open_cases`;");
    g_dbDatabase.Query(DbCallback_SelectCaseCount, query);
}

public void DbCallback_SelectCaseCount(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("DbCallback_SelectCaseCount: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int caseCount = results.FetchInt(0);
        if (caseCount < 1)
        {
            CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Case Count - None", LANG_SERVER);
        }
        else if (caseCount < 2)
        {
            CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Case Count - One", LANG_SERVER);
        }
        else
        {
            CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Case Count - Many", LANG_SERVER, caseCount);
        }
    }
}

void Db_SelectNextCase(int client)
{
    char query[128];
    Format(query, sizeof(query), "SELECT `death_index` FROM `open_cases` ORDER BY `death_index` ASC LIMIT 1;");
    g_dbDatabase.Query(DbCallback_SelectNextCase, query, GetClientUserId(client));
}

public void DbCallback_SelectNextCase(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_SelectNextCase: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    if (results.FetchRow())
    {
        int death = results.FetchInt(0);
        Db_InsertHandle(client, death);
        g_playerData[client].currentCase = death;
    }
    else
    {
        CPrintToChat(client, "%T", "RDM: Staff Handle - No Cases", client);
    }
}

void Db_SelectLastCase(int client)
{
    char query[128];
    Format(query, sizeof(query), "SELECT `death_index` FROM `ongoing_cases` WHERE `admin_id` = '%d' LIMIT 1;");
    g_dbDatabase.Query(DbCallback_SelectLastCase, query, GetClientUserId(client));
}

public void DbCallback_SelectLastCase(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_SelectLastCase: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    if (results.FetchRow())
    {
        int death = results.FetchInt(0);
        g_playerData[client].currentCase = death;
        CPrintToChat(client, "Loaded historic case %d. Use /info to get the case info.");
    }
}

public void Db_SelectClientDeaths(int client)
{
    int accountID = TTT_GetPlayerID(client);

    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `attacker_name`, `round` FROM `death_info` WHERE `victim_id` = '%d' ORDER BY `death_time`  DESC LIMIT 10;", accountID);
    g_dbDatabase.Query(DbCallback_SelectClientDeaths, query, GetClientUserId(client));
}

void DbCallback_SelectClientDeaths(Database db, DBResultSet results, const char[] error, any userid)
{
    if (results == null)
    {
        LogError("DbCallback_SelectClientDeaths: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    Menu rdmMenu = new Menu(MenuHandler_RDM);

    char title[192];
    Format(title, sizeof(title), "%T", "RDM: Report - Menu Title", client);
    rdmMenu.SetTitle(title);

    while(results.FetchRow())
    {
        int death;
        int roundNumber;
        char name[64];
        char info[8];
        char message[192];

        death = results.FetchInt(0);
        results.FetchString(1, name, sizeof(name));
        roundNumber = results.FetchInt(2);

        IntToString(death, info , 8);
        Format(message, sizeof(message), "%T", "RDM: Report - Menu Death", client, name, g_iCurrentRound - roundNumber);
        rdmMenu.AddItem(info, message);
    }

    rdmMenu.Display(client, 240);
}

void Db_SelectCaseBaseInfo(int client)
{
    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `victim_name`, `attacker_name` FROM `case_info` WHERE `death_index` = '%d';", g_playerData[client].currentCase);
    g_dbDatabase.Query(DbCallback_SelectCaseBaseInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectCaseBaseInfo(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_SelectCaseBaseInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);
        int death = results.FetchInt(0);
        char victimName[64]; results.FetchString(1, victimName, sizeof(victimName));
        char attackerName[64]; results.FetchString(2, attackerName, sizeof(attackerName));

        CPrintToChat(client, "%T", "RDM: Staff Handle - Case Info", client, death, victimName, attackerName);
    }
}

void Db_SelectInfo(int client)
{
    char query[768];
    Format(query, sizeof(query), "SELECT `death_index`, `death_time`, `victim_name`, `victim_role`+0, `victim_karma`, `attacker_name`, `attacker_role`+0, `attacker_karma`, `last_gun_fire`, `round` FROM `case_info` WHERE `death_index` = '%d';", g_playerData[client].currentCase);
    g_dbDatabase.Query(DbCallback_SelectInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectInfo(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_SelectInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);

        int death = results.FetchInt(0);
        int time = results.FetchInt(1);
        char victimName[64]; results.FetchString(2, victimName, sizeof(victimName));
        Role victimTeam = view_as<Role>(results.FetchInt(3));
        int victimKarma = results.FetchInt(4);
        char attackerName[64]; results.FetchString(5, attackerName, sizeof(attackerName));
        Role attackerTeam = view_as<Role>(results.FetchInt(6));
        int attackerKarma = results.FetchInt(7);
        int lastshot = results.FetchInt(8);
        int round = results.FetchInt(9);

        char sVictimTeam[16];
        RoleString(sVictimTeam, sizeof(sVictimTeam), victimTeam);

        char sAttackerTeam[16];
        RoleString(sAttackerTeam, sizeof(sAttackerTeam), attackerTeam);

        CPrintToChat(client, "%T", "RDM: Staff Info - Death & Round", client, death, g_iCurrentRound - round);
        CPrintToChat(client, "%T", "RDM: Staff Info - Last Shot", client, time - lastshot);
        CPrintToChat(client, "%T", "RDM: Staff Info - Accuser", client, victimName, victimKarma, sVictimTeam);
        CPrintToChat(client, "%T", "RDM: Staff Info - Accused", client, attackerName, attackerKarma, sAttackerTeam);
    }
}

void Db_SelectVerdictInfo(int client, int death)
{
    char query[256];
    Format(query, sizeof(query), "SELECT `death_index`, `victim_id`, `victim_name`, `attacker_id`, `attacker_name`, `punishment`+0, `verdict`+0 FROM `case_info` WHERE `death_index` = '%d';", death);
    g_dbDatabase.Query(DbCallback_SelectVerdictInfo, query, GetClientUserId(client));
}

public void DbCallback_SelectVerdictInfo(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_SelectVerdictInfo: %s", error);
        return;
    }

    if (results.FetchRow())
    {
        int client = GetClientOfUserId(userid);

        int death = results.FetchInt(0);
        int victimID = results.FetchInt(1);
        char victimName[64]; results.FetchString(2, victimName, sizeof(victimName));
        int attackerID = results.FetchInt(3);
        char attackerName[64]; results.FetchString(4, attackerName, sizeof(attackerName));
        CaseChoice punishment = view_as<CaseChoice>(results.FetchInt(5));
        CaseVerdict verdict = view_as<CaseVerdict>(results.FetchInt(6));

        int victim = TTT_GetClientOfPlayerID(victimID);
        int attacker = TTT_GetClientOfPlayerID(attackerID);

        char sName[MAX_NAME_LENGTH];
        TTT_GetClientName(client, sName, sizeof(sName));

        if (verdict == CaseVerdict_Innocent)
        {
            if (victim > 0 && IsClientInGame(victim))
            {
                CPrintToChat(victim, "%T", "RDM: Verdict - Innocent Accuser", victim, sName, attackerName);
            }
            if (attacker > 0 && IsClientInGame(attacker))
            {
                CPrintToChat(attacker, "%T", "RDM: Verdict - Innocent Accused", attacker, sName, victimName);
            }

            CPrintToChat(client, "%T", "RDM: Verdict - Innocent Staff", client, death);
        }
        else if (verdict == CaseVerdict_Guilty)
        {

            if (victim > 0 && IsClientInGame(victim))
            {
                CPrintToChat(victim, "%T", "RDM: Verdict - Guilty Accuser", victim, sName, attackerName);
            }
            if (attacker > 0 && IsClientInGame(attacker))
            {
                if (punishment == CaseChoice_Slay)
                {
                    CPrintToChat(attacker, "%T", "RDM: Verdict - Guilty Accused Slay", attacker, sName, victimName);
                    if (g_cTSlays.IntValue > 0 && TTT_GetClientTeam(attacker) == TTT_TEAM_TRAITOR)
                    {
                        TTT_AddRoundSlays(attacker, g_cTSlays.IntValue, false);
                    }
                    else if (g_cDSlays.IntValue > 0 && TTT_GetClientTeam(attacker) == TTT_TEAM_DETECTIVE)
                    {
                        TTT_AddRoundSlays(attacker, g_cDSlays.IntValue, false);
                    }
                    else if (g_cISlays.IntValue > 0 && TTT_GetClientTeam(attacker) == TTT_TEAM_INNOCENT)
                    {
                        TTT_AddRoundSlays(attacker, g_cISlays.IntValue, false);
                    }
                    else
                    {
                        TTT_AddRoundSlays(attacker, 1, false);
                    }
                }
                else if (punishment == CaseChoice_Warn)
                {
                    CPrintToChat(attacker, "%T", "RDM: Verdict - Guilty Accused Warn", attacker, sName, victimName);
                }
            }
            CPrintToChat(client, "%T", "RDM: Verdict - Guilty Staff", client, death);
        }
    }
}

void Db_UpdateVerdict(int client, int death, CaseVerdict verdict)
{
    char sVerdict[9] = "none";
    if (verdict == CaseVerdict_Innocent)
    {
        sVerdict = "innocent";
    }
    else if (verdict == CaseVerdict_Guilty)
    {
        sVerdict = "guilty";
    }

    char query[768];
    Format(query, sizeof(query), "UPDATE `handles` SET `handles`.`verdict` = '%s' WHERE `death_index` = '%d';", sVerdict, death);
    g_dbDatabase.Query(DbCallback_UpdateVerdict, query, GetClientUserId(client));
}

public void DbCallback_UpdateVerdict(Database db, DBResultSet results, const char[] error, any userid) {
    if (results == null)
    {
        LogError("DbCallback_UpdateVerdict: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    Db_SelectVerdictInfo(client, g_playerData[client].currentCase);

    g_playerData[client].currentCase = -1;
}
