#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <colorlib>
#include <ttt>
#include <ttt_sql>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - RDM Manager"

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = "Random Death Match manager and handler for Trouble in Terrorist Town.",
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

Database g_dbDatabase = null;

int g_iCurrentRound = -1;

ConVar g_cTSlays = null;
ConVar g_cDSlays = null;
ConVar g_cISlays = null;
ConVar g_cBadActionsToAdminMessage = null;

enum CaseChoice
{
    CaseChoice_None,
    CaseChoice_Warn,
    CaseChoice_Slay
};

enum CaseVerdict
{
    CaseVerdict_None,
    CaseVerdict_Innocent,
    CaseVerdict_Guilty
};

enum Role
{
    Role_None,
    Role_Innocent,
    Role_Traitor,
    Role_Detective
}

enum struct PlayerData
{
    int currentCase;
    int currentDeath;
    int lastGunFired;
}

PlayerData g_playerData[MAXPLAYERS + 1];

#include "rdm/database.sp"
#include "rdm/menus.sp"

public void OnPluginStart()
{
    LoadTranslations("ttt_rdm.phrases");

    RegConsoleCmd("sm_rdm", Command_RDM, "Shows the RDM report window for all recent killers.");
    RegAdminCmd("sm_cases", Command_CaseCount, ADMFLAG_GENERIC, "Shows the current amount of cases to staff.");
    RegAdminCmd("sm_handle", Command_Handle, ADMFLAG_GENERIC, "Handles the next case or a user inputted case.");
    RegAdminCmd("sm_info", Command_Info, ADMFLAG_GENERIC, "Displays all of the information for a given case.");
    RegAdminCmd("sm_verdict", Command_Verdict, ADMFLAG_GENERIC, "Shows a member of staff the availible verdicts for there current case.");

    HookEvent("weapon_fire", Event_OnWeaponFire, EventHookMode_Post);

    TTT_StartConfig("rdm");
    CreateConVar("ttt2_rdm_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cTSlays = AutoExecConfig_CreateConVar("rdm_traitor_slays", "5", "The amount of slays if the victim was a Traitor.", _, true, 0.0);
    g_cDSlays = AutoExecConfig_CreateConVar("rdm_detective_slays", "5", "The amount of slays if the victim was a Detective.", _, true, 0.0);
    g_cISlays = AutoExecConfig_CreateConVar("rdm_innocent_slays", "3", "The amount of slays if the victim was a Innocent.", _, true, 0.0);
    g_cBadActionsToAdminMessage = AutoExecConfig_CreateConVar("rdm_bad_action_message_to_admins", "1", "Send bad actions message to admins.", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }

    if (TTT_GetSQLConnection() != null)
    {
        TTT_OnSQLConnect(TTT_GetSQLConnection());
    }

    PrintToServer("[RDM] Loaded successfully");
}

public void TTT_OnSQLConnect(Database db)
{
    g_dbDatabase = db;
    g_iCurrentRound = TTT_GetRoundID();

    Transaction tAction = new Transaction();

    // Create Tables
    tAction.AddQuery("CREATE TABLE IF NOT EXISTS `deaths` (`death_index` INT UNSIGNED NOT NULL AUTO_INCREMENT, `death_time` INT UNSIGNED NOT NULL, `victim_id` INT UNSIGNED NOT NULL, `victim_role` ENUM ('innocent', 'traitor', 'detective') NOT NULL, `attacker_id` INT UNSIGNED NOT NULL, `attacker_role` ENUM ('innocent', 'traitor', 'detective') NOT NULL, `last_gun_fire` INT UNSIGNED NOT NULL, `round` INT UNSIGNED NOT NULL, PRIMARY KEY (`death_index`), UNIQUE `death_id` (`death_time`, `victim_id`), INDEX (`victim_id`), INDEX (`attacker_id`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", 1);
    tAction.AddQuery("CREATE TABLE IF NOT EXISTS `reports` (`death_index` INT UNSIGNED NOT NULL, `punishment` ENUM ('warn', 'slay') NOT NULL, PRIMARY KEY (`death_index`), INDEX (`punishment`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", 2);
    tAction.AddQuery("CREATE TABLE IF NOT EXISTS `handles` (`death_index` INT UNSIGNED NOT NULL, `admin_id` INT UNSIGNED NOT NULL, `verdict` ENUM ('innocent', 'guilty'), PRIMARY KEY (`death_index`), INDEX (`admin_id`), INDEX (`verdict`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", 3);
    // Create Views
    tAction.AddQuery("CREATE OR REPLACE VIEW `open_cases` AS SELECT `reports`.`death_index` FROM `reports` LEFT JOIN `handles` ON `reports`.`death_index` = `handles`.`death_index` WHERE `handles`.`admin_id` IS NULL GROUP BY `reports`.`death_index`;", 4);
    tAction.AddQuery("CREATE OR REPLACE VIEW `ongoing_cases` AS SELECT `reports`.`death_index`, `handles`.`admin_id` FROM `reports` LEFT JOIN `handles` ON `reports`.`death_index` = `handles`.`death_index` WHERE `handles`.`admin_id` IS NOT NULL AND `handles`.`verdict` IS NULL GROUP BY `reports`.`death_index`;", 5);
    tAction.AddQuery("CREATE OR REPLACE VIEW `death_info` AS SELECT `deaths`.`death_index`, `deaths`.`death_time`, `deaths`.`victim_id`, `ttt`.`name` as `attacker_name`, `deaths`.`round` FROM `deaths` LEFT JOIN `ttt` ON `deaths`.`attacker_id` = `ttt`.`id` GROUP BY `deaths`.`death_index`;", 6);
    tAction.AddQuery("CREATE OR REPLACE VIEW `case_info` AS SELECT `deaths`.`death_index`, `deaths`.`death_time`, `deaths`.`victim_id`, `victim_ttt`.`name` as `victim_name`, `deaths`.`victim_role`, `victim_ttt`.`karma` as `victim_karma`, `deaths`.`attacker_id`, `attacker_ttt`.`name` as `attacker_name`, `deaths`.`attacker_role`, `attacker_ttt`.`karma` as `attacker_karma`, `deaths`.`last_gun_fire`, `deaths`.`round`, `reports`.`punishment`, `handles`.`verdict` FROM `deaths` INNER JOIN `reports` ON `deaths`.`death_index` = `reports`.`death_index` LEFT JOIN `ttt` `victim_ttt` ON `deaths`.`victim_id` = `victim_ttt`.`id` LEFT JOIN `ttt` `attacker_ttt` ON `deaths`.`attacker_id` = `attacker_ttt`.`id` LEFT JOIN `handles` ON `deaths`.`death_index` = `handles`.`death_index` GROUP BY `deaths`.`death_index`;", 7);

    g_dbDatabase.Execute(tAction, sqlCreateTableSuccess, sqlCreateTableErrors);
}

public void sqlCreateTableSuccess(Handle db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	for (int i = 0; i < numQueries; i++)
	{
		if (queryData[i] == 7)
		{
            LoopValidClients(j)
            {
                OnClientPutInServer(j);
            }
        }
    }
}

public void sqlCreateTableErrors(Handle db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if (db == null || strlen(error) > 0)
    {
        LogError("(sqlCreateTableErrors) Error executing query %d of %d queries: %s", failIndex, numQueries, error);
        return;
    }
}

public void OnClientPutInServer(int client)
{
    g_playerData[client].currentCase = -1;
    g_playerData[client].currentDeath = -1;
    g_playerData[client].lastGunFired = 0;

    if (g_dbDatabase != null)
    {
        if (CheckCommandAccess(client, "sm_handle", 0, false))
        {
            Db_SelectLastCase(client);
        }
    }
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detective)
{
    g_iCurrentRound = roundid;
}

public void TTT_OnClientDeath(int victim, int attacker)
{
    Db_InsertDeath(victim, attacker);

    if (!g_cBadActionsToAdminMessage.BoolValue)
    {
        return;
    }
    
    int victimKarma = TTT_GetClientKarma(victim);
    int attackerKarma = TTT_GetClientKarma(attacker);

    if (BadKill(TTT_GetClientRole(attacker), TTT_GetClientRole(victim)))
    {
        CPrintToChat(victim, "%T", "RDM: Report - Death Message", victim);

        char sAttackerName[MAX_NAME_LENGTH], sVictimName[MAX_NAME_LENGTH];
        TTT_GetClientName(attacker, sAttackerName, sizeof(sAttackerName));
        TTT_GetClientName(victim, sVictimName, sizeof(sVictimName));

        CPrintToChatAdmins(ADMFLAG_GENERIC, "%T", "RDM: Staff Bad Action Report", LANG_SERVER, sAttackerName, attackerKarma, sVictimName, victimKarma);
    }
}

public Action Command_CaseCount(int client, int args)
{
    Db_SelectCaseCount();

    return Plugin_Handled;
}

public Action Command_Handle(int client, int args)
{
    if (g_playerData[client].currentCase > -1)
    {
        CPrintToChat(client, "%T", "RDM: Staff Handle - Case awaiting verdict", client);
        return Plugin_Handled;
    }

    Db_SelectNextCase(client);

    return Plugin_Handled;
}

public Action Command_Info(int client, int args)
{
    Db_SelectInfo(client);

    return Plugin_Handled;
}

public Action Command_RDM(int client, int args)
{
    Db_SelectClientDeaths(client);

    return Plugin_Handled;
}

public Action Command_Verdict(int client, int args)
{
    if (g_playerData[client].currentCase < 0)
    {
        CPrintToChat(client, "%T", "RDM: Staff Verdict - No Case", client);
        return Plugin_Handled;
    }

    if (args < 1)
    {
        Menu_Verdict(client);
    }
    else
    {
        char response[64];
        GetCmdArg(1, response, 64);

        CaseVerdict verdict = CaseVerdict_None;
        if (strcmp(response, "innocent", false) == 0)
        {
            verdict = CaseVerdict_Innocent;
        }
        else if (strcmp(response, "guilty", false) == 0)
        {
            verdict = CaseVerdict_Guilty;
        }

        if (verdict == CaseVerdict_Innocent || verdict == CaseVerdict_Guilty)
        {
            Db_UpdateVerdict(client, g_playerData[client].currentCase, verdict);
        }
        else
        {
            CPrintToChat(client, "%T", "RDM: Staff Verdict - Invalid Input Verdict", client);
        }
    }

    return Plugin_Handled;
}

public void Event_OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    g_playerData[GetClientOfUserId(event.GetInt("userid"))].lastGunFired = GetTime();
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    Db_SelectCaseCount();
}

void RoleString(char[] buffer, int maxlength, Role role)
{
    switch (role)
    {
        case Role_Innocent:
        {
            strcopy(buffer, maxlength, "{role i}Innocent");
        }
        case Role_Traitor:
        {
            strcopy(buffer, maxlength, "{role t}Traitor");
        }
        case Role_Detective:
        {
            strcopy(buffer, maxlength, "{role d}Detective");
        }
    }
}

void RoleEnum(char[] buffer, int maxlength, int role)
{
    if (role == TTT_TEAM_INNOCENT)
    {
        strcopy(buffer, maxlength, "innocent");
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        strcopy(buffer, maxlength, "traitor");
    }
    else if (role == TTT_TEAM_DETECTIVE)
    {
        strcopy(buffer, maxlength, "detective");
    }
    else
    {
        strcopy(buffer, maxlength, "none");
    }
}

bool BadKill(int attackerRole, int victimRole)
{
    if (attackerRole == victimRole) return true;
    //else if (attackerRole == TTT_TEAM_TRAITOR || victimRole == TTT_TEAM_TRAITOR) return false;
    else if ((attackerRole | victimRole) & TTT_TEAM_TRAITOR) return false;
    else return true;
}
