#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdkhooks>
#include <colorlib>
#include <emitsoundany>
#include <ttt>
#include <ttt_sql>

// #undef REQUIRE_EXTENSIONS
// #define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#include <ghostdm>
#include <ttt_bodies>
#include <ttt_detective_bans>
#include <ttt_ioncannon>
#include <ttt_roles>
#tryinclude <sourcebanspp>
#define REQUIRE_PLUGIN

#pragma newdecls required

#include "core/globals.sp"
#include "core/config.sp"
#include "core/forwards.sp"
#include "core/natives.sp"
#include "core/sql.sp"

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    InitForwards();
    InitNatives();

    RegPluginLibrary("ttt");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    BuildPath(Path_SM, g_sRulesFile, sizeof(g_sRulesFile), "configs/ttt/rules/start.cfg");

    TTT_LoadTranslations();
    LoadTranslations("common.phrases");

    LoadBadNames();

    g_aLogs = new ArrayList(MAX_LOG_LENGTH);
    g_aForceTraitor = new ArrayList();
    g_aForceDetective = new ArrayList();

    CreateTimer(1.0, Timer_1, _, TIMER_REPEAT);
    CreateTimer(5.0, Timer_5, _, TIMER_REPEAT);

    // Admin commands
    RegConsoleCmd("sm_setteam", Command_SetTeam);
    RegConsoleCmd("sm_karmareset", Command_KarmaReset);
    RegConsoleCmd("sm_setkarma", Command_SetKarma);
    RegConsoleCmd("sm_status", Command_Status);
    RegConsoleCmd("sm_karma", Command_Karma);
    RegConsoleCmd("sm_logs", Command_Logs);
    RegConsoleCmd("sm_log", Command_Logs);
    RegConsoleCmd("sm_trules", Command_TRules);
    RegConsoleCmd("sm_drules", Command_DetectiveRules);
    RegConsoleCmd("sm_detective", Command_DetectiveRules);
    RegConsoleCmd("sm_rslays", Command_RSlays);
    RegConsoleCmd("sm_fl", Command_FL);
    RegConsoleCmd("sm_flashlight", Command_FL);
    RegConsoleCmd("sm_respawn", Command_Respawn);
    RegConsoleCmd("sm_miccheck", Command_MicCheck);

    AddCommandListener(Command_LAW, "+lookatweapon");
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Kill, "kill");
    AddCommandListener(Command_Kill, "explode");
    AddCommandListener(Command_Kill, "spectate");
    AddCommandListener(Command_Kill, "jointeam");
    AddCommandListener(Command_Kill, "explodevector");
    AddCommandListener(Command_Kill, "killvector");

    for (int i = 0; i < sizeof(g_sRadioCMDs); i++)
    {
        AddCommandListener(Command_RadioCMDs, g_sRadioCMDs[i]);
    }

    HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
    HookEvent("player_changename", Event_ChangeName_Pre, EventHookMode_Pre);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_connect_full", Event_PlayerConnectFull);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("cs_win_panel_round", Event_WinPanel);
    HookEvent("cs_win_panel_match", Event_WinPanel);
    HookEvent("cs_match_end_restart", Event_WinPanel);

    g_cGraceTime = FindConVar("mp_join_grace_time");
    g_cFreezeTime = FindConVar("mp_freezetime");
    g_cRoundTime = FindConVar("mp_roundtime");

    g_coRules = new Cookie("ttt2_rules_menu", "Show rules", CookieAccess_Private);
    g_coDRules = new Cookie("ttt2_detective_menu", "Show detectives menu", CookieAccess_Private);

    SetRandomSeed(GetTime());

    g_hWeAreSync = CreateHudSynchronizer();
    g_hRemainingSync = CreateHudSynchronizer();

    TTT_StartConfig("ttt");
    SetupConfig();
    TTT_EndConfig();

    if (TTT_GetSQLConnection() != null)
    {
        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(OnPluginStart) Handle is not null");
        }

        LateLoadClients(true);
    }

    SetRandomSeed(GetTime());
}

public void OnAllPluginsLoaded()
{
    if (LibraryExists("sourcebans++"))
    {
        g_bSourcebans = true;
    }
    if (LibraryExists("ghostdm"))
    {
        g_bGhostDM = true;
    }
    if (LibraryExists("ttt_bodies"))
    {
        g_bBodies = true;
    }
    if (LibraryExists("ttt_detective_bans"))
    {
        g_bDetectiveBans = true;
    }
    if (LibraryExists("ttt_ioncannon"))
    {
        g_bIonCannon = true;
    }
    g_bRoles = TTT_CheckRoleLibraryExists();
}

public void OnLibraryAdded(const char[] library)
{
    if (StrEqual(library, "sourcebans++", false))
    {
        g_bSourcebans = true;
    }
    else if (StrEqual(library, "ghostdm", false))
    {
        g_bGhostDM = true;
    }
    else if (StrEqual(library, "ttt_bodies", false))
    {
        g_bBodies = true;
    }
    else if (StrEqual(library, "ttt_detective_bans", false))
    {
        g_bDetectiveBans = true;
    }
    else if (LibraryExists("ttt_ioncannon"))
    {
        g_bIonCannon = true;
    }
    else if (TTT_CheckRoleLibraryName(library))
    {
        g_bRoles = true;
    }
}

public void OnLibraryRemoved(const char[] library)
{
    if (StrEqual(library, "sourcebans++", false))
    {
        g_bSourcebans = false;
    }
    else if (StrEqual(library, "ghostdm", false))
    {
        g_bGhostDM = false;
    }
    else if (StrEqual(library, "ttt_bodies", false))
    {
        g_bBodies = false;
    }
    else if (StrEqual(library, "ttt_detective_bans", false))
    {
        g_bDetectiveBans = false;
    }
    else if (LibraryExists("ttt_ioncannon"))
    {
        g_bIonCannon = false;
    }
    else if (TTT_CheckRoleLibraryName(library))
    {
        g_bRoles = false;
    }
}

public void OnConfigsExecuted()
{
    // Save configs in strings
    g_cpluginTag.GetString(g_sTag, sizeof(g_sTag));
    g_cdefaultPriD.GetString(g_sDefaultPrimary, sizeof(g_sDefaultPrimary));
    g_cdefaultSec.GetString(g_sDefaultSecondary, sizeof(g_sDefaultSecondary));
    g_cRoundStartedFontColor.GetString(g_sRoundStartedFontColor, sizeof(g_sRoundStartedFontColor));
    g_cRoundStartFontColor.GetString(g_sRoundStartFontColor, sizeof(g_sRoundStartFontColor));
    g_cFSPrimary.GetString(g_sFSPrimary, sizeof(g_sFSPrimary));
    g_cFSSecondary.GetString(g_sFSSecondary, sizeof(g_sFSSecondary));

    TTT_DisableRounds(g_cDisableRounds.BoolValue);

    // Prepare & Format log files
    char sDate[12];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");

    g_clogFile.GetString(g_sLogFile, sizeof(g_sLogFile));
    g_cerrFile.GetString(g_sErrorFile, sizeof(g_sErrorFile));
    g_cKarmaFile.GetString(g_sKarmaFile, sizeof(g_sKarmaFile));

    ReplaceString(g_sLogFile, sizeof(g_sLogFile), "<DATE>", sDate, true);
    ReplaceString(g_sErrorFile, sizeof(g_sErrorFile), "<DATE>", sDate, true);
    ReplaceString(g_sKarmaFile, sizeof(g_sKarmaFile), "<DATE>", sDate, true);

    BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), g_sLogFile);
    BuildPath(Path_SM, g_sErrorFile, sizeof(g_sErrorFile), g_sErrorFile);
    BuildPath(Path_SM, g_sKarmaFile, sizeof(g_sKarmaFile), g_sKarmaFile);

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Log File: \"%s\"", g_sLogFile);
        LogMessage("Error File: \"%s\"", g_sErrorFile);
        LogMessage("Karma File: \"%s\"", g_sKarmaFile);
    }

    if (g_cLogButtons.BoolValue)
    {
        HookEntityOutput("func_button", "OnPressed", OnButtonPressed);
    }

    if (g_cUnloadPlugins.BoolValue)
    {
        CheckCPS();
    }
}

public void TTT_OnSQLConnect(Database db)
{
    g_dDB = db;
    AlterIDColumn();
    AlterNameColumn();
    AlterKarmaColumn();
    AlterRSlaysColumn();
    CreateRoundTable();

    if (g_cSaveLogsInSQL.BoolValue)
    {
        CreateLogTable();
    }
}

void AlterIDColumn()
{
    if (g_dDB != null)
    {
        char sQuery[76];
        g_dDB.Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` MODIFY COLUMN `id` INT UNSIGNED NOT NULL AUTO_INCREMENT;");
        g_dDB.Query(SQL_AlterIDColumn, sQuery);
    }
    else
    {
        SetFailState("(AlterIDColumn) Database handle is invalid!");
        return;
    }
}

void AlterRSlaysColumn()
{
    if (g_dDB != null)
    {
        char sQuery[72];
        g_dDB.Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` ADD COLUMN `rslays` INT(11) NOT NULL DEFAULT 0;");
        g_dDB.Query(SQL_AlterRSlaysColumn, sQuery);
    }
    else
    {
        SetFailState("(AlterRSlaysColumn) Database handle is invalid!");
        return;
    }
}

void AlterKarmaColumn()
{
    if (g_dDB != null)
    {
        char sQuery[72];
        g_dDB.Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` ADD COLUMN `karma` INT(11) NOT NULL DEFAULT 0;");
        g_dDB.Query(SQL_AlterKarmaColumn, sQuery);
    }
    else
    {
        SetFailState("(AlterKarmaColumn) Database handle is invalid!");
        return;
    }
}

void AlterNameColumn()
{
    if (g_dDB != null)
    {
        char sQuery[72];
        g_dDB.Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` ADD COLUMN `name` VARCHAR(64) NOT NULL DEFAULT '';");
        g_dDB.Query(SQL_AlterNameColumn, sQuery);
    }
    else
    {
        SetFailState("(AlterNameColumn) Database handle is invalid!");
        return;
    }
}

void CreateRoundTable()
{
    if (g_dDB != null)
    {
        DBDriver iDriver = g_dDB.Driver;
        iDriver.GetIdentifier(g_sDriver, sizeof(g_sDriver));

        if (StrEqual(g_sDriver, "mysql", false))
        {
            char sQuery[512];
            g_dDB.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt_rounds` (`id` INT NOT NULL AUTO_INCREMENT, `start` INT NOT NULL, `end` INT DEFAULT 0, PRIMARY KEY (`id`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
            g_dDB.Query(SQL_CreateRoundTable, sQuery);
        }
        else
        {
            SetFailState("Unsupported sql driver! Required driver: mysql");
            return;
        }
    }
    else
    {
        SetFailState("Database handle is invalid!");
        return;
    }
}

void CreateLogTable()
{
    if (g_dDB != null)
    {
        DBDriver iDriver = g_dDB.Driver;
        iDriver.GetIdentifier(g_sDriver, sizeof(g_sDriver));

        if (StrEqual(g_sDriver, "mysql", false))
        {
            char sQuery[512];
            g_dDB.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt_logs` (`id` INT NOT NULL AUTO_INCREMENT, `roundid` INT NOT NULL, `time` INT NOT NULL, `map` VARCHAR(64) NOT NULL, `message` VARCHAR(%d) NOT NULL, PRIMARY KEY (`id`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", TTT_LOG_SIZE);
            g_dDB.Query(SQL_CreateLogTable, sQuery);
        }
        else
        {
            SetFailState("Unsupported sql driver! Required driver: mysql");
            return;
        }
    }
    else
    {
        SetFailState("Database handle is invalid!");
        return;
    }
}

public Action Command_Logs(int client, int args)
{
    if (g_iStatus >= Round_Active)
    {
        if (client == 0)
        {
            ShowLogs(client);
        }
        else if (TTT_IsClientValid(client) && TTT_CheckCommandAccess(client, "ttt_log_access", g_clogsAccess, true))
        {
            if (g_cLogsDeadOnly.BoolValue)
            {
                if (!IsPlayerAlive(client))
                {
                    ShowLogs(client);
                }
            }
            else
            {
                ShowLogs(client);

                if (g_cLogsNotifyAlive.IntValue > 0 && g_iStatus != Round_Ending && IsPlayerAlive(client))
                {
                    if (g_cLogsNotifyAlive.IntValue == 1)
                    {
                        LoopValidClients(j)
                        {
                            CPrintToChat(j, "%s %T", g_sTag, "watching logs alive", j, g_iPlayer[client].Name);
                        }
                    }
                    else if (g_cLogsNotifyAlive.IntValue == 2)
                    {
                        LoopValidClients(j)
                        {
                            if (TTT_CheckCommandAccess(j, "ttt_log_access", g_clogsAccess, true))
                            {
                                CPrintToChat(j, "%s %T", g_sTag, "watching logs alive", j, g_iPlayer[client].Name);
                            }
                        }
                    }
                }
            }
        }
        return Plugin_Continue;
    }

    CPrintToChat(client, "%s %T", g_sTag, "you cant see logs", client);
    return Plugin_Handled;
}

void ShowLogs(int client)
{
    int iSize = g_aLogs.Length;
    if (iSize == 0)
    {
        if (client == 0)
        {
            PrintToServer("No logs yet");
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sTag, "no logs yet", client);
        }

        return;
    }

    if (g_iPlayer[client].ReceivingLogs)
    {
        return;
    }

    g_iPlayer[client].ReceivingLogs = true;

    if (client == 0)
    {
        LogToFileEx(g_sLogFile, "--------------------------------------");
        LogToFileEx(g_sLogFile, "-----------START ROUND LOGS-----------");
    }
    else
    {
        if(g_cShowReceivingLogsMessage.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sTag, "Receiving logs", client);
        }
        PrintToConsole(client, "--------------------------------------");
        PrintToConsole(client, "---------------TTT LOGS---------------");
    }

    char iItem[TTT_LOG_SIZE];
    int index = 5;
    bool end = false;

    if (index >= iSize)
    {
        end = true;
        index = (iSize - 1);
    }

    for (int i = 0; i <= index; i++)
    {
        g_aLogs.GetString(i, iItem, sizeof(iItem));

        if (client == 0)
        {
            LogToFileEx(g_sLogFile, iItem);
        }
        else
        {
            PrintToConsole(client, iItem);
        }
    }

    if (end)
    {
        if (client == 0)
        {
            LogToFileEx(g_sLogFile, "--------------------------------------");
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sTag, "See your console", client);
            PrintToConsole(client, "--------------------------------------");
            PrintToConsole(client, "--------------------------------------");
        }

        g_iPlayer[client].ReceivingLogs = false;
        return;
    }

    DataPack pack = new DataPack();

    if (TTT_IsClientValid(client))
    {
        pack.WriteCell(GetClientUserId(client));
    }
    else
    {
        pack.WriteCell(0);
    }

    pack.WriteCell(index);
    RequestFrame(Frame_Create, pack);
}

void SaveLogsSQL()
{
    Transaction tTransaction = new Transaction();

    char sMap[64];
    GetCurrentMap(sMap, sizeof(sMap));

    char sQuery[1024];
    char sEntry[TTT_LOG_SIZE];

    for (int i = 0; i < g_aLogs.Length; i++)
    {
        g_aLogs.GetString(i, sEntry, sizeof(sEntry));

        g_dDB.Format(sQuery, sizeof(sQuery), "INSERT INTO ttt_logs (roundid, time, map, message) VALUES ('%d', UNIX_TIMESTAMP(), `%s`, `%s`);", g_iRoundID, sMap, sEntry);
        tTransaction.AddQuery(sQuery);
    }

    g_dDB.Execute(tTransaction, _, SQL_TransactionLogsError);
}

public void Frame_Create(any pack)
{
    view_as<DataPack>(pack).Reset();

    int userid = view_as<DataPack>(pack).ReadCell();
    int index = view_as<DataPack>(pack).ReadCell();

    delete view_as<DataPack>(pack);

    int client;
    if (userid == 0)
    {
        client = userid;
    }
    else
    {
        client = GetClientOfUserId(userid);
    }

    if ((client == 0) || TTT_IsClientValid(client))
    {
        int sizearray = g_aLogs.Length;
        int old = (index + 1);
        index += 5;
        bool end = false;

        if (index >= sizearray)
        {
            end = true;
            index = (sizearray - 1);
        }

        char iItem[TTT_LOG_SIZE];

        for (int i = old; i <= index; i++)
        {
            g_aLogs.GetString(i, iItem, sizeof(iItem));

            if (client == 0)
            {
                LogToFileEx(g_sLogFile, iItem);
            }
            else
            {
                PrintToConsole(client, iItem);
            }
        }

        if (end)
        {
            if (client == 0)
            {
                LogToFileEx(g_sLogFile, "--------------------------------------");
            }
            else
            {
                CPrintToChat(client, "%s %T", g_sTag, "See your console", client);
                PrintToConsole(client, "--------------------------------------");
                PrintToConsole(client, "--------------------------------------");
            }

            g_iPlayer[client].ReceivingLogs = false;
            return;
        }

        DataPack pack2 = new DataPack();

        if (TTT_IsClientValid(client))
        {
            pack2.WriteCell(GetClientUserId(client));
        }
        else
        {
            pack2.WriteCell(0);
        }

        pack2.WriteCell(index);
        RequestFrame(Frame_Create, pack2);
    }
}

public Action Command_Kill(int client, const char[] command, int args)
{
    if (g_cBlockSwitchSelection.BoolValue && g_iStatus == Round_Selection && StrEqual(command, "jointeam", false))
    {
        return Plugin_Stop;
    }

    if (!g_bBlockKill && g_cblockSuicide.BoolValue && IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sTag, "Suicide Blocked", client);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public Action Command_RadioCMDs(int client, const char[] command, int args)
{
    if (g_cblockRadioMessage.BoolValue)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void OnMapStart()
{
    g_bSpawnAllowed = true;

    for (int i; i < g_iBadNameCount; i++)
    {
        g_sBadNames[i] = "";
    }
    g_iBadNameCount = 0;

    LoadBadNames();

    g_iBeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vtf");

    PrecacheSoundAny(SND_TCHAT, true);
    PrecacheSoundAny(SND_FLASHLIGHT, true);

    g_iAlive = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
    if (g_iAlive == -1)
    {
        SetFailState("CCSPlayerResource \"m_bAlive\" offset is invalid");
    }

    g_iHealth = FindSendPropInfo("CCSPlayerResource", "m_iHealth");
    if (g_iHealth == -1)
    {
        SetFailState("CCSPlayerResource \"m_iHealth\" offset is invalid");
    }

    g_iKills = FindSendPropInfo("CCSPlayerResource", "m_iKills");
    if (g_iKills == -1)
    {
        SetFailState("CCSPlayerResource \"m_iKills\" offset is invalid");
    }

    g_iDeaths = FindSendPropInfo("CCSPlayerResource", "m_iDeaths");
    if (g_iDeaths == -1)
    {
        SetFailState("CCSPlayerResource \"m_iDeaths\"  offset is invalid");
    }

    g_iAssists = FindSendPropInfo("CCSPlayerResource", "m_iAssists");
    if (g_iAssists == -1)
    {
        SetFailState("CCSPlayerResource \"m_iAssists\"  offset is invalid");
    }

    g_iMVPs = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
    if (g_iMVPs == -1)
    {
        SetFailState("CCSPlayerResource \"m_iMVPs\"  offset is invalid");
    }

    SDKHook(FindEntityByClassname(0, "cs_player_manager"), SDKHook_ThinkPost, ThinkPost);

    g_bCheckPlayers = true;

    if (g_dDB != null)
    {
        if (g_cClearRounds.IntValue > 0)
        {
            char sQuery[256];
            g_dDB.Format(sQuery, sizeof(sQuery), "DELETE FROM ttt_rounds WHERE start < %d", GetTime() - (g_cClearRounds.IntValue * 86400));
            g_dDB.Query(SQL_ClearRounds, sQuery);
        }

        if (g_cClearLogs.IntValue > 0)
        {
            char sQuery[256];
            g_dDB.Format(sQuery, sizeof(sQuery), "DELETE FROM ttt_logs WHERE time < %d", GetTime() - (g_cClearLogs.IntValue * 86400));
            g_dDB.Query(SQL_ClearLogs, sQuery);
        }
    }
}

public void ThinkPost(int entity)
{
    if (g_ckadRemover.BoolValue)
    {
        int iZero[MAXPLAYERS + 1] =  { 0, ... };

        SetEntDataArray(entity, g_iKills, iZero, MaxClients + 1);
        SetEntDataArray(entity, g_iDeaths, iZero, MaxClients + 1);
        SetEntDataArray(entity, g_iAssists, iZero, MaxClients + 1);
        SetEntDataArray(entity, g_iMVPs, iZero, MaxClients + 1);
    }

    int isAlive[MAXPLAYERS + 1];
    int iHealth[MAXPLAYERS + 1];

    GetEntDataArray(entity, g_iAlive, isAlive, MAXPLAYERS + 1);

    if (g_bBodies && g_cfakeLife.IntValue == 0)
    {
        TTT_GetFoundArray(isAlive, sizeof(isAlive));

        for (int i = 0; i < sizeof(isAlive); i++)
        {
            isAlive[i] = (!isAlive[i]);
        }

        LoopValidClients(i)
        {
            iHealth[i] = g_cfakeHealth.IntValue;
        }
    }
    else
    {
        bool alive = true;
        if (g_cfakeLife.IntValue == 1)
        {
            alive = false;
        }
        else if (g_cfakeLife.IntValue == 2)
        {
            alive = true;
        }

        LoopValidClients(i)
        {
            isAlive[i] = alive;
            iHealth[i] = g_cfakeHealth.IntValue;
        }
    }

    SetEntDataArray(entity, g_iHealth, iHealth, MAXPLAYERS + 1);
    SetEntDataArray(entity, g_iAlive, isAlive, MAXPLAYERS + 1);
}

public Action Command_Karma(int client, int args)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    CPrintToChat(client, "%s %T", g_sTag, "Your karma is", client, g_iPlayer[client].Karma);

    return Plugin_Handled;
}

public int OnButtonPressed(const char[] output, int entity, int client, float delay)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return 0;
    }

    if (IsValidEntity(entity) && g_bPressed[entity])
    {
        return 0;
    }

    char sClientID[32], sTeam[ROLE_LENGTH], sName[512], iItem[TTT_LOG_SIZE];
    if (g_cAddSteamIDtoLogs.BoolValue)
    {
        if (g_cSteamIDLogFormat.IntValue == 1)
        {
            GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 2)
        {
            GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 3)
        {
            GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 4)
        {
            Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
        }

        if (strlen(sClientID) > 2)
        {
            Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
        }
    }

    TTT_GetTeamNameByID(TTT_GetClientTeam(client), sTeam, sizeof(sTeam));
    GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

    Format(iItem, sizeof(iItem), "-> [%s%s (%s) pressed the button %s (%d)]", g_iPlayer[client].Name, sClientID, sTeam, sName, entity);
    PushStringToLogs(iItem);

    g_bPressed[entity] = true;
    CreateTimer(g_cLogButtonsSpam.FloatValue, Timer_EnableButton, EntIndexToEntRef(entity));
    
    return 0;
}

public Action Timer_EnableButton(Handle timer, any reference)
{
    int entity = EntRefToEntIndex(reference);

    if (IsValidEntity(entity))
    {
        g_bPressed[entity] = false;
    }
    
    return Plugin_Continue;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundID = -1;

    if (g_bDisabled)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
            }
        }
        g_iStatus = Round_Inactive;
        return Plugin_Continue;
    }

    g_iRoundTime = GetTime();

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 1 (Warmup: %d)", TTT_IsWarmUp());
    }

    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Warmup, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Warmup, g_iStatus);
        }
    }

    LoopValidClients(i)
    {
        g_iPlayer[i].Team = TTT_TEAM_UNASSIGNED;
        PrintToChat(i, "Set to Unassigned");
        g_iPlayer[i].Role = TTT_ROLE_DEFAULT;
        g_iPlayer[i].InnocentKills = 0;
        g_iPlayer[i].TraitorKills = 0;
        g_iPlayer[i].DetectiveKills = 0;
        g_iPlayer[i].ImmuneRDMManager = false;

        g_iPlayer[i].HurtedPlayer1 = -1;
        g_iPlayer[i].HurtedPlayer2 = -1;
        g_iPlayer[i].ResetHurt = false;
        g_iPlayer[i].Respawn = false;

        DispatchKeyValue(i, "targetname", "UNASSIGNED");
        CS_SetClientClanTag(i, " ");


        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("Event_RoundStartPre - 4 (Player: %s)", g_iPlayer[i].Name);
        }
    }

    if (g_hStartTimer != null)
    {
        delete g_hStartTimer;
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 5 (g_hStartTimer: %d)", g_hStartTimer);
    }

    if (g_hCountdownTimer != null)
    {
        delete g_hCountdownTimer;
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 6 (g_hCountdownTimer: %d)", g_hCountdownTimer);
    }

    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Warmup, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(Event_RoundStartPre) g_iStatus set to %d from %d", Round_Warmup, g_iStatus);
        }
    }
    g_iStatus = Round_Warmup;

    float fTime = g_cGraceTime.FloatValue + 3.0;
    g_hStartTimer = CreateTimer(fTime, Timer_Selection, _, TIMER_FLAG_NO_MAPCHANGE);

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 7 (g_hStartTimer: %d - Time: %f)", g_hStartTimer, fTime);
    }

    g_fRealRoundStart = GetGameTime() + fTime;
    g_hCountdownTimer = CreateTimer(1.0, Timer_SelectionCountdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 8 (g_hCountdownTimer: %d)", g_hCountdownTimer);
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 9 (g_iStatus: %d)", g_iStatus);
    }

    if (g_hRoundTimer != null)
    {
        delete g_hRoundTimer;
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 9 (g_hRoundTimer: %d)", g_hRoundTimer);
    }

    bool bStartTimer = true;
    float fEndTime = g_cFreezeTime.FloatValue + (g_cRoundTime.FloatValue * 60.0);

    Forward_OnRoundStartTimer_Pre(bStartTimer, fEndTime);
    if (bStartTimer)
    {
        g_hRoundTimer = CreateTimer(fEndTime, Timer_OnRoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("Event_RoundStartPre - 9 (g_hRoundTimer: %d - Time: %f)", g_hRoundTimer, fEndTime);
        }
    }

    g_bBlockKill = false;
    
    return Plugin_Continue;
}

public void TTT_OnBodyFound(int client, int victim, int victimTeam, int attackerTeam, int entityref, bool silentID)
{
    TeamTag(victim);
}

public Action Event_RoundEndPre(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(i)
    {
        g_iPlayer[i].InnocentKills = 0;
        g_iPlayer[i].TraitorKills = 0;
        g_iPlayer[i].DetectiveKills = 0;
        g_iPlayer[i].ImmuneRDMManager = false;

        ShowLogs(i);
        TeamTag(i);

        if (g_cTranfserArmor.BoolValue)
        {
            if (IsPlayerAlive(i))
            {
                g_iPlayer[i].Armor = GetEntProp(i, Prop_Send, "m_ArmorValue");
            }
        }
    }

    ShowLogs(0);

    g_iTeamSelectTime = 0;

    if (g_hRoundTimer != null)
    {
        delete g_hRoundTimer;
        g_hRoundTimer = null;
    }
    
    return Plugin_Continue;
}

public Action Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Event_WinPanel) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(Event_WinPanel) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
        }
    }
    else
    {
        g_iStatus = Round_Ending;
    }
    
    return Plugin_Continue;
}

public Action Timer_SelectionCountdown(Handle hTimer)
{
    int timeLeft = RoundToFloor(g_fRealRoundStart - GetGameTime());
    char centerText[512];

    if (g_fRealRoundStart <= 0.0 || timeLeft <= 0)
    {
        if (timeLeft == 0)
        {
            LoopValidClients(i)
            {
                Format(centerText, sizeof(centerText), "<pre>%T</pre>", "RoundStartedCenter", i, g_cRoundStartedFontSize.IntValue, g_sRoundStartedFontColor);
                PrintCenterText2(i, "Trouble in Terrorist Town", centerText); // TODO: Add 2nd option as synchud
            }
        }

        g_hCountdownTimer = null;
        return Plugin_Stop;
    }

    if (timeLeft <= 5)
    {
        g_bBlockKill = true;
    }

    LoopValidClients(i)
    {
        Format(centerText, sizeof(centerText), "<pre>%T</pre>", "RoundStartCenter", i, g_cRoundStartFontSize.IntValue, g_sRoundStartFontColor, timeLeft);
        PrintCenterText2(i, "Trouble in Terrorist Town", centerText); // TODO: Add 2nd option as synchud
    }

    return Plugin_Continue;
}

public Action Timer_Selection(Handle hTimer)
{
    g_iStatus = Round_Selection;
    g_hStartTimer = null;

    static int clients[MAXPLAYERS * 2];  // clients is double sized incase all
    static bool hasRole[MAXPLAYERS + 1]; // players are pushed twice.
    int iClientCount = 0;
    int iPlayers = 0;

    LoopValidClients(i)
    {
        if (GetClientRoundSlays(i))
        {
            if (DoClientRoundSlays(i))
            {
                continue;
            }
        }

        int iTeam = GetClientTeam(i);

        if ((iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT) || (!g_cDebug.BoolValue && IsFakeClient(i)))
        {
            continue;
        }

        if (!IsPlayerAlive(i))
        {
            if (g_cRespawnDeadPlayers.BoolValue)
            {
                CS_RespawnPlayer(i);
            }
            else
            {
                continue;
            }
        }

        clients[iPlayers] = i;
        hasRole[i] = false;
        ++iClientCount;
        ++iPlayers;

        if ((g_cDoublePushInno.BoolValue && g_iPlayer[i].LastTeam == TTT_TEAM_INNOCENT) || (g_cDoublePushDete.BoolValue && g_iPlayer[i].LastTeam == TTT_TEAM_DETECTIVE))
        {
            clients[iPlayers] = i;
            ++iClientCount;
        }
    }

    if (Forward_OnRoundStart_Pre() >= Plugin_Handled)
    {
        Forward_OnRoundStartFailed(-1);

        GiveWeaponsOnFailStart();

        if (g_cDebug.BoolValue)
        {
            PrintToServer("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
            }
        }
        g_iStatus = Round_Inactive;

        return Plugin_Handled;
    }

    // Should really be using RSlays to handle slaying players so can probably
    // deprecate this and helps with the static buffer for clients - c0rp3n
    //Check if there are any slain players
    /*
    for (int i = 0; i < aPlayers.Length; i++)
    {
        if(!IsPlayerAlive(aPlayers.Get(i)))
        {
            aPlayers.Erase(i);
        }
    }
    */

    if (iPlayers < g_crequiredPlayers.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
            }
        }

        g_iStatus = Round_Inactive;

        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sTag, "MIN PLAYERS REQUIRED FOR PLAY", i, g_crequiredPlayers.IntValue);

            if (g_cPlayerHUDMessage.BoolValue)
            {
                SetHudTextParams(0.4, 0.53, 5.1, 205, 173, 0, 255, 0, 0.0, 0.0, 0.0);
                ShowSyncHudText(i, g_hWeAreSync, "%T", "WE ARE", i, iPlayers);
                SetHudTextParams(0.33, 0.565, 5.1, 205, 173, 0, 255, 0, 0.0, 0.0, 0.0);
                ShowSyncHudText(i, g_hRemainingSync, "%T", "REMAINING PLAYERS", i, (g_crequiredPlayers.IntValue - iPlayers));
            }
        }

        g_bCheckPlayers = true;

        if (g_cDebug.BoolValue)
        {
            PrintToServer("(Timer_Selection) g_bCheckPlayers 1: %d", g_bCheckPlayers);
        }

        Forward_OnRoundStartFailed(iPlayers);

        GiveWeaponsOnFailStart();

        if (g_cDebug.BoolValue)
        {
            PrintToServer("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(Timer_Selection) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
            }
        }
        g_iStatus = Round_Inactive;

        return Plugin_Handled;
    }

    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Timer_Selection) g_iStatus set to %d from %d", Round_Selection, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(Timer_Selection) g_iStatus set to %d from %d", Round_Selection, g_iStatus);
        }
    }

    g_bCheckPlayers = false;

    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Timer_Selection), g_bCheckPlayers 2: %d", g_bCheckPlayers);
    }

    int iInnocents; // I Count
    int iTraitors; // T Count
    int iDetectives; // D Count
    int iMisc; // Misc Count

    Action result = Forward_OnRoleSelection(iTraitors, iDetectives, iInnocents, iMisc);
    if (result >= Plugin_Handled)
    {
        // A plugin has overidden the normal role selection procedure
        // Start the round after the query has completed
        StartRound(iInnocents, iTraitors, iDetectives, iMisc, null);

        return Plugin_Handled;
    }

    // Init normal role counts
    int iTCount = GetTCount(iPlayers);
    int iDCount = GetDCount(iPlayers);
    int iMCount = GetMCount(iPlayers);
    int iICount = iPlayers - iTCount - iDCount - iMCount;

    // Init actual role counts
    iInnocents = iICount;
    iTraitors = iTCount;
    iDetectives = 0;
    iMisc = 0;

    ArrayList aTraitors = new ArrayList(1, iTraitors);
    // Shuffle clients, double permute this? current method may not be random
    // enough, or readd in bias by double stacking detectives and innocents, in
    // the clients array.
    SortIntegers(clients, iClientCount, Sort_Random);

    // Assign roles
    // This step shall now be a triple pass essentially, assign Traitors and
    // then Detectives, then start again giving everyone without a role to be a
    // innocent.
    // It is only triple pass if too many people had detective bans or avoided
    // detective so generally there will only be two passes.
    // We also need to handle if everyone avoids detectives so that will be done
    // at the start of the second pass.
    if (g_bRoles)
    {
        int i = 0;
        static int roles[MAXPLAYERS];
        // Traitors
        TTT_GetTeamRoles(TTT_TEAM_TRAITOR, iTCount, iPlayers, roles);
        for (int j = 0; j < iTCount && i < iClientCount; ++j)
        {
            while (hasRole[clients[i]])
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            SetClientRole(clients[i], TTT_TEAM_TRAITOR, roles[j]);
            PrintToServer("%N - Team Traitor, Role: %d", clients[i], roles[j]);
            hasRole[clients[i]] = true;
            aTraitors.Set(j, i);
            ++i;
        }
        // Detectives
        if (iDCount > 0)
        {
            TTT_GetTeamRoles(TTT_TEAM_DETECTIVE, iDCount, iPlayers, roles);
            for (int j = 0; j < iDCount && i < iClientCount; ++j)
            {
                while (hasRole[clients[i]] ||
                      g_iPlayer[clients[i]].AvoidDetective ||
                      g_bDetectiveBans && TTT_IsDetectiveBanned(i))
                {
                    ++i;
                    if (i >= iClientCount)
                    {
                        break;
                    }
                }

                if (g_bDetectiveBans && TTT_IsDetectiveBanned(i))
                {
                    SetClientRole(clients[i], TTT_TEAM_INNOCENT, TTT_ROLE_DEFAULT);
                    ++iInnocents;
                }
                else
                {
                    SetClientRole(clients[i], TTT_TEAM_DETECTIVE, roles[j]);
                    ++iDetectives;
                }

                hasRole[clients[i]] = true;
                ++i;
            }
        }
        // Misc
        if (iMCount > 0)
        {
            TTT_GetTeamRoles(TTT_TEAM_MISC, iMCount, iPlayers, roles);
            for (int j = 0; j < iMCount && i < iClientCount; ++j)
            {
                while (hasRole[clients[i]])
                {
                    ++i;
                    if (i >= iClientCount)
                    {
                        break;
                    }
                }

                if (roles[j] != TTT_ROLE_DEFAULT)
                {
                    SetClientRole(clients[i], TTT_TEAM_MISC, roles[j]);
                    PrintToServer("Player: %N, Team: Misc, Role: %d", clients[i], roles[j]);
                    ++iMisc;
                }
                else
                {
                    SetClientRole(clients[i], TTT_TEAM_INNOCENT, TTT_ROLE_DEFAULT);
                    ++iInnocents;
                }

                hasRole[clients[i]] = true;
                ++i;
            }
        }
        // Seconds pass
        // Detectives
        i = 0;
        while (iDetectives < iDCount)
        {
            while (hasRole[clients[i]] ||
                  g_bDetectiveBans && TTT_IsDetectiveBanned(i))
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            // Default them to a standard detective, should stop trying to avoid
            // isnt going to get you more t rounds buddy.
            SetClientRole(clients[i], TTT_TEAM_DETECTIVE, TTT_ROLE_DEFAULT);
            hasRole[clients[i]] = true;
            ++iDetectives;
            ++i;
        }
        // Third pass
        // Innocents
        i = 0;
        TTT_GetTeamRoles(TTT_TEAM_INNOCENT, iICount, iPlayers, roles);
        for (int j = 0; j < iICount && i < iClientCount; ++j)
        {
            while (hasRole[clients[i]])
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            SetClientRole(clients[i], TTT_TEAM_INNOCENT, roles[j]);
            ++i;
        }
    }
    else // if roles is not loaded give all players the standard roles
    {
        int i = 0;
        // Traitors
        for (int j = 0; j < iTCount && i < iClientCount; ++j)
        {
            while (hasRole[clients[i]])
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            SetClientRole(i, TTT_TEAM_TRAITOR, TTT_ROLE_DEFAULT);
            hasRole[clients[i]] = true;
            aTraitors.Set(j, i);
            ++i;
        }
        // Detectives
        for (int j = 0; j < iDCount && i < iClientCount; ++j)
        {
            while (hasRole[clients[i]] ||
                  g_iPlayer[clients[i]].AvoidDetective ||
                  g_bDetectiveBans && TTT_IsDetectiveBanned(i))
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            SetClientRole(clients[i], TTT_TEAM_DETECTIVE, TTT_ROLE_DEFAULT);
            hasRole[clients[i]] = true;
            ++iDetectives;
            ++i;
        }
        // Seconds pass
        // Detectives
        i = 0;
        while (iDetectives < iDCount)
        {
            while (hasRole[clients[i]] ||
                  g_bDetectiveBans && TTT_IsDetectiveBanned(i))
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            // Default them to a standard detective, should stop trying to avoid
            // isnt going to get you more t rounds buddy.
            SetClientRole(clients[i], TTT_TEAM_DETECTIVE, TTT_ROLE_DEFAULT);
            hasRole[clients[i]] = true;
            ++iDetectives;
            ++i;
        }
        // Tripple Pass thanks detective bans
        i = 0;
        // Innocents
        for (int j = 0; j < iICount && i < iClientCount; ++j)
        {
            while (hasRole[clients[i]])
            {
                ++i;
                if (i >= iClientCount)
                {
                    break;
                }
            }

            SetClientRole(i, TTT_TEAM_INNOCENT, TTT_ROLE_DEFAULT);
            ++i;
        }
    }

    // Start the round once the round has been inserted
    StartRound(iInnocents, iTraitors, iDetectives, iMisc, aTraitors);

    return Plugin_Handled;
}

int GetTCount(int activePlayers)
{
    int iTCount = RoundToFloor(float(activePlayers) * (float(g_ctraitorRatio.IntValue) / 100.0));

    if (iTCount < 1)
    {
        iTCount = 1;
    }

    if (iTCount > g_cmaxTraitors.IntValue)
    {
        iTCount = g_cmaxTraitors.IntValue;
    }

    return iTCount;
}

int GetDCount(int activePlayers)
{
    if (activePlayers < g_crequiredPlayersD.IntValue)
    {
        return 0;
    }

    int iDCount = RoundToFloor(float(activePlayers) * (float(g_cdetectiveRatio.IntValue) / 100.0));

    if (iDCount > g_cmaxDetectives.IntValue)
    {
        iDCount = g_cmaxDetectives.IntValue;
    }

    return iDCount;
}

int GetMCount(int activePlayers)
{
    if (activePlayers < g_crequiredPlayersM.IntValue)
    {
        return 0;
    }

    int iMCount = RoundToFloor(float(activePlayers) * (float(g_cmiscRatio.IntValue) / 100.0));

    if (iMCount > g_cmaxMisc.IntValue)
    {
        iMCount = g_cmaxMisc.IntValue;
    }

    return iMCount;
}

void SetClientRole(int client, int team, int role)
{
    g_iPlayer[client].Team = team;
    g_iPlayer[client].LastTeam = team;
    g_iPlayer[client].Role = role;
}

void StartRound(int innocents, int traitors, int detectives, int misc, ArrayList aTraitors)
{
    // Init a new log list, why do we not just call ArrayList.Clear() here
    // instead of creating a new ArrayList?
    delete g_aLogs;
    g_aLogs = new ArrayList(MAX_LOG_LENGTH);

    static char sQuery[64]; // make this static so that it isnt reallocated
    // This also null terminates so dont need to care about the old data in
    // sQuery, so it was made static
    g_dDB.Format(sQuery, sizeof(sQuery), "INSERT INTO ttt_rounds (start) VALUES (UNIX_TIMESTAMP());");

    DataPack pack = new DataPack();
    pack.WriteCell(innocents);
    pack.WriteCell(traitors);
    pack.WriteCell(detectives);
    pack.WriteCell(misc);
    pack.WriteCell(aTraitors);

    g_dDB.Query(SQL_InsertRound, sQuery, pack, DBPrio_Normal);
}

void TeamInitialize(int client, bool skipWeapons = false, bool announce = true)
{
    if (g_iStatus != Round_Active)
    {
        return;
    }

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    CS_SetClientClanTag(client, " ");

    g_iPlayer[client].Alive = true;

    int iTeam = GetClientTeam(client);

    if (g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
    {
        if (g_cforceTeams.BoolValue)
        {
            if (iTeam == CS_TEAM_T || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
            {
                CS_SwitchTeam(client, CS_TEAM_CT);
            }
        }

        if (!skipWeapons)
        {
            int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

            if (iWeapon == -1)
            {
                RequestFrame(Frame_GivePrimary, GetClientUserId(client));
            }
            else
            {
                if (g_cPrimaryWeaponUpdate.IntValue == 1)
                {
                    SDKHooks_DropWeapon(client, iWeapon);
                    RequestFrame(Frame_GivePrimary, GetClientUserId(client));
                }
                else if (g_cPrimaryWeaponUpdate.IntValue == 2)
                {
                    TTT_SafeRemoveWeapon(client, iWeapon);
                    RequestFrame(Frame_GivePrimary, GetClientUserId(client));
                }
            }
        }

        DispatchKeyValue(client, "targetname", "DETECTIVE");

        if (g_cspawnHPD.IntValue > 0)
        {
            SetEntityHealth(client, g_cspawnHPD.IntValue);
        }

        GiveMelee(client);

        if (!skipWeapons)
        {
            int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

            if (iWeapon == -1)
            {
                RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
            }
            else
            {
                if (g_cSecondaryWeaponUpdate.IntValue == 1)
                {
                    SDKHooks_DropWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
                else if (g_cSecondaryWeaponUpdate.IntValue == 2)
                {
                    TTT_SafeRemoveWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
            }
        }
    }
    else if (g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
    {
        DispatchKeyValue(client, "targetname", "TRAITOR");

        if (g_cspawnHPT.IntValue > 0)
        {
            SetEntityHealth(client, g_cspawnHPT.IntValue);
        }

        if (g_cforceTeams.BoolValue)
        {
            if (iTeam == CS_TEAM_CT || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
            {
                CS_SwitchTeam(client, CS_TEAM_T);
            }
        }

        GiveMelee(client);

        if (!skipWeapons)
        {
            int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

            if (iWeapon == -1)
            {
                RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
            }
            else
            {
                if (g_cSecondaryWeaponUpdate.IntValue == 1)
                {
                    SDKHooks_DropWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
                else if (g_cSecondaryWeaponUpdate.IntValue == 2)
                {
                    TTT_SafeRemoveWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
            }
        }
    }
    else if (g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
    {
        DispatchKeyValue(client, "targetname", "INNOCENT");

        if (g_cspawnHPI.IntValue > 0)
        {
            SetEntityHealth(client, g_cspawnHPI.IntValue);
        }

        if (g_cforceTeams.BoolValue)
        {
            if ((iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT) || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
            {
                CS_SwitchTeam(client, CS_TEAM_T);
            }
        }

        GiveMelee(client);

        if (!skipWeapons)
        {
            int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

            if (iWeapon == -1)
            {
                RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
            }
            else
            {
                if (g_cSecondaryWeaponUpdate.IntValue == 1)
                {
                    SDKHooks_DropWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
                else if (g_cSecondaryWeaponUpdate.IntValue == 2)
                {
                    TTT_SafeRemoveWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
            }
        }
    }
    else if (g_iPlayer[client].Team == TTT_TEAM_MISC)
    {
        DispatchKeyValue(client, "targetname", "MISC");

        if (g_cspawnHPM.IntValue > 0)
        {
            SetEntityHealth(client, g_cspawnHPM.IntValue);
        }

        if (g_cforceTeams.BoolValue)
        {
            if ((iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT) || (g_cSwitchSpec.BoolValue && iTeam == CS_TEAM_SPECTATOR))
            {
                CS_SwitchTeam(client, CS_TEAM_T);
            }
        }

        GiveMelee(client);

        if (!skipWeapons)
        {
            int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

            if (iWeapon == -1)
            {
                RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
            }
            else
            {
                if (g_cSecondaryWeaponUpdate.IntValue == 1)
                {
                    SDKHooks_DropWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
                else if (g_cSecondaryWeaponUpdate.IntValue == 2)
                {
                    TTT_SafeRemoveWeapon(client, iWeapon);
                    RequestFrame(Frame_GiveSecondary, GetClientUserId(client));
                }
            }
        }
    }
    else
    {
        g_iPlayer[client].Alive = false;
    }

    if (announce)
    {
        char sRole[ROLE_LENGTH], sColor[12], sTranslation[64];
        TTT_GetTeamNameByID(g_iPlayer[client].Team, sRole, sizeof(sRole));
        TTT_GetTeamColorByID(g_iPlayer[client].Team, sColor, sizeof(sColor));

        FormatEx(sTranslation, sizeof(sTranslation), "Role: %s", sRole);
        FormatEx(sRole, sizeof(sRole), "%s%T", sColor, sTranslation, client);

        CPrintToChat(client, "%s %T", g_sTag, "Your Role", client, sRole);
    }

    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if (StrContains(sClass, "weapon_", false) != -1)
            {
                SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() - 0.1);
                SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() - 0.1);
            }
        }
    }

    CheckClantag(client);

    bool bUpdate = false;

    if (g_cupdateClientModel.BoolValue)
    {
        CS_UpdateClientModel(client);

        bUpdate = true;
    }

    if (bUpdate)
    {
        Forward_OnClientModelUpdate(client);
    }

    Forward_OnClientGetRole(client);
}

void TeamTag(int client)
{
    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (TTT_IsValidTeam(client, g_iPlayer[client].Team))
    {
        SetClanTag(client, g_iPlayer[client].Team);
    }
    else
    {
        CS_SetClientClanTag(client, " ");
    }
}

public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Stop;
    }

    if (g_iStatus == Round_Active && !g_iPlayer[client].Respawn)
    {
        SetClanTag(client, TTT_TEAM_UNASSIGNED);
        g_iPlayer[client].Alive = false;
        return Plugin_Stop;
    }

    g_iPlayer[client].Alive = true;

    return Plugin_Continue;
}

public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast)
{
    if (g_cAutoAssignTeam != null && g_cAutoAssignTeam.BoolValue)
    {
        CreateTimer(2.0, Timer_AutoAssignTeam, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Continue;
}

public Action Timer_AutoAssignTeam(Handle timer, any userId)
{
    int client = GetClientOfUserId(userId);

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Stop;
    }

    int iTeam = DetermineTeam();
    int iLifeState = GetEntProp(client, Prop_Send, "m_lifeState");
    SetEntProp(client, Prop_Send, "m_lifeState", 2);
    ChangeClientTeam(client, DetermineTeam());
    ClientCommand(client, "jointeam %i", iTeam);
    CS_UpdateClientModel(client);
    SetEntProp(client, Prop_Send, "m_lifeState", iLifeState);

    int iCurrent = GetClientTeam(client);

    if (!IsPlayerAlive(client) && (iCurrent == CS_TEAM_T || iCurrent == CS_TEAM_CT) && (g_bSpawnAllowed || AreTeamsEmpty()))
    {
        CS_RespawnPlayer(client);
    }

    return Plugin_Stop;
}

public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
    bool bWarmup = TTT_IsWarmUp();

    if (bWarmup || g_cGraceTime.BoolValue)
    {
        g_bSpawnAllowed = true;
    }

    if (bWarmup)
    {
        return;
    }

    CreateTimer(g_cGraceTime.FloatValue, Timer_GraceTimeOver, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_GraceTimeOver(Handle timer)
{
    g_bSpawnAllowed = false;
    
    return Plugin_Handled;
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
    g_bSpawnAllowed = false;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        if (g_iStatus == Round_Active && !g_iPlayer[client].Respawn)
        {
            if (g_cslayAfterStart.BoolValue)
            {
                g_iPlayer[client].Team = TTT_TEAM_UNASSIGNED;
                PrintToChat(client, "Set to Unassigned");

                RequestFrame(Frame_SlayPlayer, GetClientUserId(client));

                SetClanTag(client, TTT_TEAM_UNASSIGNED);
                DispatchKeyValue(client, "targetname", "UNASSIGNED");
            }
        }
        else
        {
            CS_SetClientClanTag(client, " ");

            if (g_cEnableDamage.BoolValue)
            {
                GivePlayerItem(client, "weapon_knife");

                char sWeapon[32];

                Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSSecondary);
                GivePlayerItem(client, sWeapon);

                Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSPrimary);
                GivePlayerItem(client, sWeapon);
            }
        }

        g_iPlayer[client].InnocentKills = 0;
        g_iPlayer[client].TraitorKills = 0;
        g_iPlayer[client].DetectiveKills = 0;

        StripAllWeapons(client);

        if (g_iStatus == Round_Inactive)
        {
            int iCount = 0;

            LoopValidClients(i)
            {
                if (IsPlayerAlive(i) && (GetClientTeam(i) > CS_TEAM_SPECTATOR))
                {
                    iCount++;
                }
            }

            if (iCount >= g_crequiredPlayers.IntValue)
            {
                ServerCommand("mp_restartgame 2");
            }
        }

        if (g_iStatus != Round_Inactive && g_cshowKarmaOnSpawn.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sTag, "Your karma is", client, g_iPlayer[client].Karma);
        }

        if (g_cenableNoBlock.BoolValue)
        {
            SetNoBlock(client);
        }

        if (g_cTranfserArmor.BoolValue && g_iPlayer[client].Armor > 0)
        {
            SetEntProp(client, Prop_Send, "m_ArmorValue", g_iPlayer[client].Armor);
            g_iPlayer[client].Armor = 0;
        }

        if (g_cFixThirdperson.BoolValue)
        {
            ClientCommand(client, "firstperson");
        }

        g_iPlayer[client].Respawn = false;
    }
    
    return Plugin_Continue;
}

public void Frame_SlayPlayer(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        ForcePlayerSuicide(client);
    }
}

public void OnClientPutInServer(int client)
{
    if (!TTT_IsClientValid(client))
    {
        return;
    }

    ClearClientData(client);

    HookClient(client);


    GetClientName(client, g_iPlayer[client].Name, sizeof(PlayerData::Name));
    EscapeName(g_iPlayer[client].Name, sizeof(PlayerData::Name));
    if (g_cDebugMessages.BoolValue)
    {
        LogToFileEx(g_sKarmaFile, "OnClientPutInServer - 1 (%s)", g_iPlayer[client].Name);
    }

    if (g_dDB != null)
    {
        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "OnClientPutInServer - 2 (%s), Valid Database", g_iPlayer[client].Name);
        }

        CreateTimer(1.0, Timer_OnClientPutInServer, GetClientUserId(client));
    }
}

void LateLoadClients(bool bHook = false)
{
    LoopValidClients(i)
    {
        GetClientName(i, g_iPlayer[i].Name, sizeof(PlayerData::Name));
        EscapeName(g_iPlayer[i].Name, sizeof(PlayerData::Name));
        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "LateLoadClients - 1 (%s)", g_iPlayer[i].Name);
        }

        if (g_dDB != null)
        {
            if (g_cDebugMessages.BoolValue)
            {
                LogToFileEx(g_sKarmaFile, "LateLoadClients - 2 (%s), Valid Database", g_iPlayer[i].Name);
            }
            LoadClientInfo(GetClientUserId(i));
        }

        OnClientCookiesCached(i);

        if (bHook)
        {
            HookClient(i);
        }
    }
}

void HookClient(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
    SDKHook(client, SDKHook_PostThink, OnPostThink);
}

public Action OnPostThink(int client)
{
    if (TTT_IsClientValid(client))
    {
        int iKarma;
        if (g_cpublicKarma.BoolValue)
        {
            if (g_bBodies && TTT_WasBodyFound(client))
            {
                iKarma = g_iPlayer[client].Karma * -1;
            }
            else
            {
                iKarma = g_iPlayer[client].Karma;
            }
        }
        else if (g_ckarmaRound.BoolValue)
        {
            if (g_bBodies && TTT_WasBodyFound(client))
            {
                iKarma = g_iPlayer[client].KarmaStart * -1;
            }
            else
            {
                iKarma = g_iPlayer[client].KarmaStart;
            }
        }
        CS_SetClientContributionScore(client, iKarma);
    }
    
    return Plugin_Continue;
}

void BanBadPlayerKarma(int client)
{
    char sReason[512];
    Format(sReason, sizeof(sReason), "%T", "Your Karma is too low", client);

    setKarma(client, g_cstartKarma.IntValue, true);

    if (g_bSourcebans)
    {
        #if defined _sourcebanspp_included //got to actually check if the include was included, to allow compiles without it.
        SBPP_BanPlayer(0, client, g_ckarmaBanLength.IntValue, sReason);
        #endif
    }
    else
    {
        ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_ckarmaBanLength.IntValue, sReason);
    }
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (g_cDisableDamageSelection.BoolValue && g_iStatus == Round_Selection)
    {
        return Plugin_Handled;
    }

    if (IsDamageForbidden())
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
    if (IsDamageForbidden())
    {
        return Plugin_Handled;
    }

    if (g_bIonCannon && TTT_IsFriendlyFired())
    {
        if (TTT_HasAutoIonCannon(iAttacker) && g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[iVictim].Team == TTT_TEAM_TRAITOR)
        {
            return Plugin_Handled;
        }
    }

    Action action = Plugin_Continue;

    if (g_iStatus == Round_Active)
    {
        float fDamage = damage;

        if (TTT_IsClientValid(iAttacker) && iAttacker != iVictim && g_ckarmaDMG.BoolValue)
        {
            if (g_ckarmaDMG_up.BoolValue || (g_iPlayer[iAttacker].Karma < g_cstartKarma.IntValue))
            {
                fDamage = (damage * (float(g_iPlayer[iAttacker].Karma) / float(g_cstartKarma.IntValue)));
            }
        }

        if (!TTT_IsClientValid(iAttacker) || !TTT_IsClientValid(iVictim))
        {
            return Plugin_Continue;
        }

        if (g_cSkipOwnSuicide.BoolValue && iAttacker == iVictim)
        {
            return Plugin_Continue;
        }

        char iItem[TTT_LOG_SIZE];
        int iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");

        if (!IsValidEntity(iWeapon))
        {
            return Plugin_Continue;
        }

        char sWeapon[32];
        GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));

        if (!TTT_IsClientValid(inflictor) && IsValidEntity(inflictor))
        {
            GetEntityClassname(inflictor, sWeapon, sizeof(sWeapon));
        }

        char sAttackerID[32], sClientID[32];

        if (g_cAddSteamIDtoLogs.BoolValue)
        {
            if (g_cSteamIDLogFormat.IntValue == 1)
            {
                GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
                GetClientAuthId(iVictim, AuthId_Steam2, sClientID, sizeof(sClientID));
            }
            else if (g_cSteamIDLogFormat.IntValue == 2)
            {
                GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
                GetClientAuthId(iVictim, AuthId_Steam3, sClientID, sizeof(sClientID));
            }
            else if (g_cSteamIDLogFormat.IntValue == 3)
            {
                GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
                GetClientAuthId(iVictim, AuthId_SteamID64, sClientID, sizeof(sClientID));
            }
            else if (g_cSteamIDLogFormat.IntValue == 4)
            {
                Format(sAttackerID, sizeof(sAttackerID), "%d", GetSteamAccountID(iAttacker));
                Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(iVictim));
            }

            if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
            {
                Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
            }
        }

        bool badAction = TTT_IsBadAction(g_iPlayer[iVictim].Team, g_iPlayer[iAttacker].Team);

        char sDamageType[18];
        if (damagetype & CS_DMG_HEADSHOT)
        {
            Format(sDamageType, sizeof(sDamageType), " (HEADSHOT)");
        }
        else if (damagetype & DMG_CLUB)
        {
            Format(sDamageType, sizeof(sDamageType), " (THROW DAMAGE)");
        }

        char sBad[16], sAttackerRole[ROLE_LENGTH], sVictimRole[ROLE_LENGTH];
        TTT_GetTeamNameByID(g_iPlayer[iAttacker].Team, sAttackerRole, sizeof(sAttackerRole));
        TTT_GetTeamNameByID(g_iPlayer[iVictim].Team, sVictimRole, sizeof(sVictimRole));

        if (badAction)
        {
            FormatEx(sBad, sizeof(sBad), " - BAD ACTION");
        }

        Format(iItem, sizeof(iItem), "-> [%s%s (%s) damaged %s%s (%s) for %.0f damage%s with %s]", g_iPlayer[iAttacker].Name, sAttackerID, sAttackerRole, g_iPlayer[iVictim].Name, sClientID, sVictimRole, fDamage, sDamageType, sWeapon, sBad);
        PushStringToLogs(iItem);

        if (g_cEnableDamageKarma.BoolValue)
        {
            if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[iVictim].Team == TTT_TEAM_INNOCENT)
            {
                subtractKarma(iAttacker, g_cDamageKarmaII.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[iVictim].Team == TTT_TEAM_TRAITOR)
            {
                addKarma(iAttacker, g_cDamageKarmaIT.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[iVictim].Team == TTT_TEAM_DETECTIVE)
            {
                subtractKarma(iAttacker, g_cDamageKarmaID.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[iVictim].Team == TTT_TEAM_INNOCENT)
            {
                addKarma(iAttacker, g_cDamageKarmaTI.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[iVictim].Team == TTT_TEAM_TRAITOR)
            {
                subtractKarma(iAttacker, g_cDamageKarmaTT.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[iVictim].Team == TTT_TEAM_DETECTIVE)
            {
                addKarma(iAttacker, g_cDamageKarmaTD.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[iVictim].Team == TTT_TEAM_INNOCENT)
            {
                subtractKarma(iAttacker, g_cDamageKarmaDI.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[iVictim].Team == TTT_TEAM_TRAITOR)
            {
                addKarma(iAttacker, g_cDamageKarmaDT.IntValue, false);
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[iVictim].Team == TTT_TEAM_DETECTIVE)
            {
                subtractKarma(iAttacker, g_cDamageKarmaDD.IntValue, false);
            }
        }

        if (fDamage != damage)
        {
            damage = fDamage;
            action = Plugin_Changed;
        }

        Forward_OnTakeDamage(iVictim, iAttacker, fDamage, iWeapon, badAction);
    }

    return action;
}

bool IsDamageForbidden()
{
    if (g_iStatus == Round_Ending && !g_croundendDamage.BoolValue)
    {
        return true;
    }

    if (g_iStatus < Round_Selection && !g_cEnableDamage.BoolValue)
    {
        return true;
    }

    return false;
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!TTT_IsClientValid(client))
    {
        event.BroadcastDisabled = true;
        return Plugin_Changed;
    }

    if (g_iPlayer[client].Team > TTT_TEAM_UNASSIGNED)
    {
        g_iPlayer[client].Alive = false;

        int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

        Action res = Forward_OnPlayerDeathPre(client, iAttacker);
        if (res == Plugin_Stop || res == Plugin_Changed)
        {
            event.BroadcastDisabled = true;
            return Plugin_Changed;
        }

        if (g_iStatus == Round_Active &&  (client != iAttacker && iAttacker != 0 && !g_iPlayer[iAttacker].ImmuneRDMManager))
        {
            if (
                (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_TRAITOR) ||
                (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE) ||
                (g_cShowInnoRDMMenu.BoolValue && g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
            )
            {
                if (g_iPlayer[client].RDMTimer != null)
                {
                    delete g_iPlayer[client].RDMTimer;
                }

                g_iPlayer[client].RDMTimer = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
                g_iPlayer[client].RDMAttacker = iAttacker;
            }

            if ((g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_INNOCENT) || (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE))
            {
                g_iPlayer[iAttacker].InnocentKills++;
            }
            else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
            {
                g_iPlayer[iAttacker].TraitorKills++;
            }
            else if ((g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_INNOCENT) || (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE))
            {
                g_iPlayer[iAttacker].DetectiveKills++;
            }

            if (g_iPlayer[iAttacker].InnocentKills >= g_cpunishInnoKills.IntValue)
            {
                TTT_AddRoundSlays(iAttacker, g_cRoundSlayInno.IntValue, true);
            }

            if (g_iPlayer[iAttacker].TraitorKills >= g_cpunishTraitorKills.IntValue)
            {
                TTT_AddRoundSlays(iAttacker, g_cRoundSlayTraitor.IntValue, true);
            }

            if (g_iPlayer[iAttacker].DetectiveKills >= g_cpunishDetectiveKills.IntValue)
            {
                TTT_AddRoundSlays(iAttacker, g_cRoundSlayDetective.IntValue, true);
            }
        }
    }

    event.BroadcastDisabled = true;
    return Plugin_Changed;
}

public void OnClientPostAdminCheck(int client)
{
    nameCheck(client);

    g_iPlayer[client].ImmuneRDMManager = false;
    g_iPlayer[client].Team = TTT_TEAM_UNASSIGNED;
    PrintToChat(client, "Set to Unassigned");
    g_iPlayer[client].Ready = true;

    DispatchKeyValue(client, "targetname", "UNASSIGNED");
    SetClanTag(client, TTT_TEAM_UNASSIGNED);

    if (g_cshowRulesMenu.BoolValue)
    {
        CreateTimer(3.0, Timer_ShowWelcomeMenu, GetClientUserId(client));
    }
    else if (g_cshowDetectiveMenu.BoolValue)
    {
        CreateTimer(3.0, Timer_ShowDetectiveMenu, GetClientUserId(client));
    }
}

public Action Timer_OnClientPutInServer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "Timer_OnClientPutInServer - 1 (%s)", g_iPlayer[client].Name);
        }
        LoadClientInfo(userid);
    }
    
    return Plugin_Continue;
}

public Action Command_TRules(int client, int args)
{
    if (!g_cshowRulesMenu.BoolValue)
    {
        return Plugin_Handled;
    }

    g_iPlayer[client].Rules = false;

    char sBuffer[12];
    IntToString(g_iPlayer[client].Rules, sBuffer, sizeof(sBuffer));
    g_coRules.Set(client, sBuffer);

    ShowRules(client, g_iPlayer[client].Site);
    return Plugin_Handled;
}

public Action Command_DetectiveRules(int client, int args)
{
    if (!g_cshowDetectiveMenu.BoolValue)
    {
        return Plugin_Handled;
    }

    g_iPlayer[client].DetectiveRules = false;

    char sBuffer[12];
    IntToString(g_iPlayer[client].DetectiveRules, sBuffer, sizeof(sBuffer));
    g_coDRules.Set(client, sBuffer);

    AskClientForMicrophone(client);
    return Plugin_Handled;
}

public Action Command_RSlays(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "sm_rslays", g_cRoundSlayAccess, true))
    {
        return Plugin_Handled;
    }

    if (args < 2 || args > 3)
    {
        ReplyToCommand(client, "[SM] Usage: sm_rslays <#userid|name> <rounds> <0 (Default) - Slay on next team selection, 1 - Instant slays>");
        ReplyToCommand(client, "3rd parameter is just useful for inactive round, it has no effect in running round.");
        return Plugin_Handled;
    }

    bool bForce = false;

    char arg1[32];
    char arg2[12];
    char arg3[12];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    if (args == 3)
    {
        GetCmdArg(3, arg3, sizeof(arg3));
        bForce = view_as<bool>(StringToInt(arg3));
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_MULTI, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (target == -1 || !TTT_IsClientValid(target))
        {
            CReplyToCommand(client, "Invalid target");
            return Plugin_Handled;
        }

        int rounds = StringToInt(arg2);

        if (rounds < 0)
        {
            CReplyToCommand(client, "Rounds must be zero (reset) or higher.");
            return Plugin_Handled;
        }

        TTT_SetRoundSlays(target, rounds, bForce);

        LoopValidClients(j)
        {
            CPrintToChat(j, "%s %T", g_sTag, "AdminSetRoundSlays", j, g_iPlayer[target].Name, g_iPlayer[client].Name, rounds);
        }

        LogAction(client, target, "\"%L\" slayed \"%L\" for \"%i\" rounds", client, target, rounds);
    }

    return Plugin_Continue;
}

public Action Command_Respawn(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "sm_respawn", g_cRespawnAccess, true))
    {
        return Plugin_Handled;
    }

    if (args != 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_respawn <#userid|name>");

        return Plugin_Handled;
    }

    char arg1[32];
    char arg2[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (target == -1 || !TTT_IsClientValid(target))
        {
            CReplyToCommand(client, "Invalid target");
            return Plugin_Handled;
        }

        if (TTT_IsPlayerAlive(target))
        {
            CReplyToCommand(client, "%T", "Respawn: Must Dead", client, g_iPlayer[target].Name);
            return Plugin_Handled;
        }

        TTT_RespawnPlayer(target);

        LoopValidClients(j)
        {
            CPrintToChat(j, "%s %T", g_sTag, "Respawn: Player", j, g_iPlayer[client].Name, g_iPlayer[target].Name);
        }

        LogAction(client, target, "\"%L\" respawned \"%L\"", client, target);
    }

    return Plugin_Continue;
}

public Action Command_MicCheck(int client, int args)
{
    if (!g_cshowDetectiveMenu.BoolValue)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_mic_check", g_cMicCheckFlag, true))
    {
        return Plugin_Handled;
    }

    Menu menu = new Menu(Menu_MicCheck);
    menu.SetTitle("%T", "Menu - Mic Check Title", client);

    int iCount = 0;
    char sName[MAX_NAME_LENGTH + 4], sUserID[12];
    LoopValidClients(i)
    {
        if (g_iPlayer[i].AvoidDetective)
        {
            Format(sName, sizeof(sName), "[ ] %s", g_iPlayer[i].Name);
        }
        else
        {
            Format(sName, sizeof(sName), "[x] %s", g_iPlayer[i].Name);
        }

        IntToString(GetClientUserId(i), sUserID, sizeof(sUserID));

        menu.AddItem(sUserID, sName);
        iCount++;
    }

    if (iCount == 0)
    {
        delete menu;
        return Plugin_Handled;
    }

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_MicCheck(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public void Frame_ShowWelcomeMenu(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        ShowRules(client, g_iPlayer[client].Site);
    }
}

public Action Timer_ShowWelcomeMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        ShowRules(client, g_iPlayer[client].Site);
    }
    
    return Plugin_Handled;
}

void ShowRules(int client, int iItem)
{
    if (g_cRulesMenu.BoolValue && g_iPlayer[client].Rules)
    {
        return;
    }

    bool bShow = true;
    Action res = Forward_OnRulesMenu(client, bShow);
    if (res == Plugin_Changed && !bShow)
    {
        return;
    }

    char sText[512], sYes[64];
    Format(sText, sizeof(sText), "%T", "Welcome Menu", client, g_iPlayer[client].Name, TTT_PLUGIN_AUTHOR);
    Format(sYes, sizeof(sYes), "%T", "WM Yes", client);

    Menu menu = new Menu(Menu_ShowWelcomeMenu);
    menu.SetTitle(sText);

    File hFile = OpenFile(g_sRulesFile, "rt");

    if (hFile == null)
    {
        SetFailState("[TTT] Can't open File: %s", g_sRulesFile);
    }

    KeyValues kvRules = new KeyValues("Rules");

    if (!kvRules.ImportFromFile(g_sRulesFile))
    {
        SetFailState("Can't read %s correctly! (ImportFromFile)", g_sRulesFile);
        delete kvRules;
        delete hFile;
        return;
    }

    if (!kvRules.GotoFirstSubKey())
    {
        SetFailState("Can't read %s correctly! (GotoFirstSubKey)", g_sRulesFile);
        delete kvRules;
        delete hFile;
        return;
    }

    do
    {
        char sNumber[4];
        char sTitle[64];

        kvRules.GetSectionName(sNumber, sizeof(sNumber));
        kvRules.GetString("title", sTitle, sizeof(sTitle));
        menu.AddItem(sNumber, sTitle);
    }
    while (kvRules.GotoNextKey());

    delete kvRules;
    delete hFile;

    menu.AddItem("yes", sYes);
    menu.ExitButton = false;
    menu.ExitBackButton = false;
    menu.DisplayAt(client, iItem, g_ctimeToReadRules.IntValue);
}

public int Menu_ShowWelcomeMenu(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        if (!StrEqual(sParam, "yes", false))
        {
            File hFile = OpenFile(g_sRulesFile, "rt");

            if (hFile == null)
            {
                SetFailState("[TTT] Can't open File: %s", g_sRulesFile);
                return 0;
            }

            KeyValues kvRules = new KeyValues("Rules");

            if (!kvRules.ImportFromFile(g_sRulesFile))
            {
                SetFailState("Can't read %s correctly! (ImportFromFile)", g_sRulesFile);
                delete hFile;
                delete kvRules;
                return 0;
            }


            if (kvRules.JumpToKey(sParam, false))
            {
                char sValue[MAX_MESSAGE_LENGTH];

                kvRules.GetString("text", sValue, sizeof(sValue));
                if (strlen(sValue) > 0)
                {
                    CPrintToChat(client, sValue);
                    RequestFrame(Frame_ShowWelcomeMenu, GetClientUserId(client));

                    g_iPlayer[client].KnowRules = false;
                    g_iPlayer[client].ReadRules = true;

                    delete hFile;
                    delete kvRules;
                    return 0;
                }

                kvRules.GetString("fakecommand", sValue, sizeof(sValue));
                if (strlen(sValue) > 0)
                {
                    FakeClientCommand(client, sValue);

                    g_iPlayer[client].KnowRules = false;
                    g_iPlayer[client].ReadRules = true;


                    delete hFile;
                    delete kvRules;
                    return 0;
                }

                kvRules.GetString("command", sValue, sizeof(sValue));
                if (strlen(sValue) > 0)
                {
                    ClientCommand(client, sValue);

                    g_iPlayer[client].KnowRules = false;
                    g_iPlayer[client].ReadRules = true;

                    delete hFile;
                    delete kvRules;
                    return 0;
                }

                kvRules.GetString("url", sValue, sizeof(sValue));
                if (strlen(sValue) > 0)
                {
                    LogError("CS:GO has removed the MOTD and Popup function! You should remove all \"url\" parts from your rules.cfg");
                    PrintToChat(client, "TTT can't open this. CS:GO has removed the MOTD and Popup function! Please contact the technical support from this server.");

                    if (g_cShowURL.BoolValue)
                    {
                        PrintToChat(client, "URL: %s", sValue);
                    }

                    if (g_cRulesURLReopenMenu.BoolValue)
                    {
                        g_iPlayer[client].KnowRules = false;
                        g_iPlayer[client].ReadRules = true;
                    }
                    else
                    {
                        TTT_ClientOpenRules(client);
                    }

                    delete hFile;
                    delete kvRules;
                    return 0;
                }

                kvRules.GetString("file", sValue, sizeof(sValue));
                if (strlen(sValue) > 0)
                {
                    g_iPlayer[client].Site = menu.Selection;

                    char sFile[PLATFORM_MAX_PATH + 1];
                    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/rules/%s", sValue);

                    File hRFile = OpenFile(sFile, "rt");

                    if (hRFile == null)
                    {
                        SetFailState("[TTT] Can't open File: %s", sFile);

                        delete hFile;
                        delete kvRules;

                        return 0;
                    }

                    char sLine[64], sTitle[64];

                    Menu rMenu = new Menu(Menu_RulesPage);

                    kvRules.GetString("title", sTitle, sizeof(sTitle));
                    rMenu.SetTitle(sTitle);

                    while (!hRFile.EndOfFile() && hRFile.ReadLine(sLine, sizeof(sLine)))
                    {
                        if (strlen(sLine) > 1)
                        {
                            rMenu.AddItem("", sLine, ITEMDRAW_DISABLED);
                        }
                    }

                    rMenu.ExitButton = false;
                    rMenu.ExitBackButton = true;
                    rMenu.Display(client, g_ctimeToReadRules.IntValue);

                    delete hRFile;
                    delete hFile;
                    delete kvRules;

                    return 0;
                }

                delete hFile;
                delete kvRules;

                return 0;
            }

            delete hFile;
        }
        else
        {
            if (g_cRulesMenu.BoolValue)
            {
                g_iPlayer[client].Rules = true;

                char sBuffer[12];
                IntToString(g_iPlayer[client].Rules, sBuffer, sizeof(sBuffer));
                g_coRules.Set(client, sBuffer);

                return 0;
            }

            g_iPlayer[client].KnowRules = true;
            g_iPlayer[client].ReadRules = false;
        }

        if (g_cshowDetectiveMenu.BoolValue)
        {
            AskClientForMicrophone(client);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (TTT_IsClientValid(client) && g_crulesClosePunishment.IntValue == 0)
        {
            if (!TTT_CheckCommandAccess(client, "ttt_kick_immunity", g_ckickImmunity, true))
            {
                char sMessage[128];
                Format(sMessage, sizeof(sMessage), "%T", "WM Kick Message", client);
                KickClient(client, sMessage);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public int Menu_RulesPage(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Cancel || action == MenuAction_Select || param == MenuCancel_ExitBack)
    {
        ShowRules(client, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Timer_ShowDetectiveMenu(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        AskClientForMicrophone(client);
    }
    
    return Plugin_Continue;
}

void AskClientForMicrophone(int client)
{
    if (g_cDRulesMenu.BoolValue && g_iPlayer[client].DetectiveRules)
    {
        return;
    }

    bool bShow = true;
    Action res = Forward_OnDetectiveMenu(client, bShow);
    if (res == Plugin_Changed && !bShow)
    {
        return;
    }

    char sText[512], sYes[64], sNo[64];
    Format(sText, sizeof(sText), "%T", "AM Question", client);
    Format(sYes, sizeof(sYes), "%T", "AM Yes", client);
    Format(sNo, sizeof(sNo), "%T", "AM No", client);

    Menu menu = new Menu(Menu_AskClientForMicrophone);
    menu.SetTitle(sText);
    menu.AddItem("no", sNo);
    menu.AddItem("yes", sYes);
    menu.ExitButton = false;
    menu.ExitBackButton = false;
    menu.Display(client, g_ctimeToReadDetectiveRules.IntValue);
}


public int Menu_AskClientForMicrophone(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        if (!StrEqual(sParam, "yes", false))
        {
            g_iPlayer[client].AvoidDetective = true;
        }
        else
        {
            g_iPlayer[client].AvoidDetective = false;

            if (g_cDRulesMenu.BoolValue)
            {
                g_iPlayer[client].DetectiveRules = true;

                char sBuffer[12];
                IntToString(g_iPlayer[client].DetectiveRules, sBuffer, sizeof(sBuffer));
                g_coDRules.Set(client, sBuffer);

                return 0;
            }
        }
    }
    else if (action == MenuAction_Cancel)
    {
        g_iPlayer[client].AvoidDetective = true;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public void OnClientCookiesCached(int client)
{
    char sBuffer[12];
    g_coRules.Get(client, sBuffer, sizeof(sBuffer));
    g_iPlayer[client].Rules = view_as<bool>(StringToInt(sBuffer));

    g_coDRules.Get(client, sBuffer, sizeof(sBuffer));
    g_iPlayer[client].DetectiveRules = view_as<bool>(StringToInt(sBuffer));
}

public void OnClientDisconnect(int client)
{
    UpdatePlayerRSlays(client);
    UpdatePlayer(client);

    if (IsClientInGame(client))
    {
        g_iPlayer[client].KarmaReady = false;
        g_iPlayer[client].Alive = false;
        g_iPlayer[client].Respawn = false;
        g_iPlayer[client].Ready = false;

        if (g_cTranfserArmor.BoolValue)
        {
            g_iPlayer[client].Armor = 0;
        }

        delete g_iPlayer[client].RDMTimer;

        g_iPlayer[client].ReceivingLogs = false;
        g_iPlayer[client].ImmuneRDMManager = false;
    }

    if (!AreTeamsEmpty()) {
        return;
    }

    g_bSpawnAllowed = true;
}

public Action Event_ChangeName_Pre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_cNameChangePunish.IntValue > 0 && g_iStatus == Round_Active)
    {
        char sOld[MAX_NAME_LENGTH], sNew[MAX_NAME_LENGTH];
        event.GetString("oldname", sOld, sizeof(sOld));
        event.GetString("newname", sNew, sizeof(sNew));

        if (g_cNameChangePunish.IntValue == 1)
        {
            LoopValidClients(i)
            {
                CPrintToChat(i, "%s %T", g_sTag, "Name Change Message", i, sOld, sNew);
            }
        }
        else if (g_cNameChangePunish.IntValue == 2 && !StrEqual(g_iPlayer[client].Name, sNew))
        {
            DataPack pack = new DataPack();
            RequestFrame(Frame_RechangeName, pack);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteString(sOld);

            return Plugin_Handled;
        }
        else if (g_cNameChangePunish.IntValue == 3)
        {
            char sReason[512];
            Format(sReason, sizeof(sReason), "%T", "Name Change Kick Reason", client);
            KickClient(client, sReason);

            return Plugin_Handled;
        }
        else if (g_cNameChangePunish.IntValue == 4)
        {
            char sReason[512];
            Format(sReason, sizeof(sReason), "%T", "Name Change Reason", client);

            if (g_bSourcebans)
            {
                #if defined _sourcebanspp_included
                SBPP_BanPlayer(0, client, g_cNameChangeLength.IntValue, sReason);
                #endif
            }
            else
            {
                ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_cNameChangeLength.IntValue, sReason);
            }

            return Plugin_Handled;
        }
    }

    event.GetString("newname", g_iPlayer[client].Name, sizeof(PlayerData::Name));
    EscapeName(g_iPlayer[client].Name, sizeof(PlayerData::Name));
    nameCheck(client);

    return Plugin_Continue;
}

public void Frame_RechangeName(any pack)
{
    view_as<DataPack>(pack).Reset();

    int userid = view_as<DataPack>(pack).ReadCell();

    char sName[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sName, sizeof(sName));

    delete view_as<DataPack>(pack);

    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        strcopy(g_iPlayer[client].Name, sizeof(PlayerData::Name), sName);
        EscapeName(g_iPlayer[client].Name, sizeof(PlayerData::Name));
        SetClientName(client, sName);
    }
}

public Action Timer_1(Handle timer)
{
    int g_iInnoAlive = 0;
    int g_iTraitorAlive = 0;
    int g_iDetectiveAlive = 0;

    float vec[3];
    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            if (g_iPlayer[i].Team == TTT_TEAM_UNASSIGNED && g_iStatus != Round_Active && g_cdenyFire.BoolValue)
            {
                for(int j = 0; j < GetEntPropArraySize(i, Prop_Send, "m_hMyWeapons"); j++)
                {
                    int weapon = GetEntPropEnt(i, Prop_Send, "m_hMyWeapons", j);

                    if (IsValidEntity(weapon))
                    {
                        char sClass[32];
                        GetEntityClassname(weapon, sClass, sizeof(sClass));

                        if (StrContains(sClass, "weapon_", false) != -1)
                        {
                            SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
                            SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.0);
                        }
                    }
                }
            }
            if (g_iPlayer[i].Team == TTT_TEAM_TRAITOR)
            {
                g_iTraitorAlive++;
                int[] clients = new int[MaxClients];
                int index = 0;

                LoopValidClients(j)
                {
                    if (IsPlayerAlive(j) && j != i && (g_iPlayer[j].Team == TTT_TEAM_TRAITOR))
                    {
                        clients[index] = j;
                        index++;
                    }
                }

                GetClientAbsOrigin(i, vec);
                vec[2] += 10;

                TE_SetupBeamRingPoint(vec, 50.0, 60.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, { 0, 0, 255, 255 }, 10, 0);
                TE_Send(clients, index);
            }
            else if (g_iPlayer[i].Team == TTT_TEAM_INNOCENT)
            {
                g_iInnoAlive++;
            }
            else if (g_iPlayer[i].Team == TTT_TEAM_DETECTIVE)
            {
                g_iDetectiveAlive++;
            }
        }
    }

    if (g_iStatus == Round_Active)
    {
        if (g_iInnoAlive == 0 && ((g_cendwithD.BoolValue) || (g_iDetectiveAlive == 0)))
        {
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Timer_1) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

                if (g_cDebugMessages.BoolValue)
                {
                    LogMessage("(Timer_1) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
                }
            }

            if (!g_cDebug.BoolValue)
            {
                g_iStatus = Round_Ending;
                CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
            }
        }
        else if (g_iTraitorAlive == 0)
        {
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Timer_1) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

                if (g_cDebugMessages.BoolValue)
                {
                    LogMessage("(Timer_1) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
                }
            }

            if (!g_cDebug.BoolValue)
            {
                g_iStatus = Round_Ending;
                CS_TerminateRound(7.0, CSRoundEnd_CTWin);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!TTT_IsClientValid(iAttacker) || iAttacker == client && !g_cDebug.BoolValue)
    {
        return Plugin_Continue;
    }

    Action res = Forward_OnClientDeath_Pre(client, iAttacker);
    if (res == Plugin_Stop || res == Plugin_Changed)
    {
        return Plugin_Continue;
    }

    // TODO
    if (g_cshowDeathMessage.BoolValue)
    {
        if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR)
        {
            CPrintToChat(client, "%s %T", g_sTag, "Your killer is a Traitor", client);
        }
        else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE)
        {
            CPrintToChat(client, "%s %T", g_sTag, "Your killer is a Detective", client);
        }
        else if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT)
        {
            CPrintToChat(client, "%s %T", g_sTag, "Your killer is an Innocent", client);
        }
    }

    // TODO
    if (g_cshowKillMessage.BoolValue)
    {
        if (g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
        {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed a Traitor", iAttacker);
        }
        else if (g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
        {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed a Detective", iAttacker);
        }
        else if (g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
        {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "You killed an Innocent", iAttacker);
        }
    }

    char iItem[TTT_LOG_SIZE];
    char sWeapon[32];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));

    char sAttackerID[32], sClientID[32];

    bool badAction = TTT_IsBadAction(g_iPlayer[client].Team, g_iPlayer[iAttacker].Team);

    if (g_cAddSteamIDtoLogs.BoolValue)
    {
        if (g_cSteamIDLogFormat.IntValue == 1)
        {
            GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 2)
        {
            GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 3)
        {
            GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
        }
        else if (g_cSteamIDLogFormat.IntValue == 4)
        {
            Format(sAttackerID, sizeof(sAttackerID), "%d", GetSteamAccountID(iAttacker));
            Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
        }

        if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
        {
            Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
            Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
        }
    }

    char sBad[16], sAttackerRole[ROLE_LENGTH], sVictimRole[ROLE_LENGTH];
    TTT_GetTeamNameByID(g_iPlayer[iAttacker].Team, sAttackerRole, sizeof(sAttackerRole));
    TTT_GetTeamNameByID(g_iPlayer[client].Team, sVictimRole, sizeof(sVictimRole));

    if (badAction)
    {
        FormatEx(sBad, sizeof(sBad), " - BAD ACTION");
    }

    Format(iItem, sizeof(iItem), "-> [%s%s (%s) killed %s%s (%s) with %s]%s", g_iPlayer[iAttacker].Name, sAttackerID, sAttackerRole, g_iPlayer[client].Name, sClientID, sVictimRole, sWeapon, sBad);
    PushStringToLogs(iItem);

    if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
    {
        if (g_iPlayer[client].HurtedPlayer1 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
        } else if (g_iPlayer[client].HurtedPlayer2 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
        } else {
            subtractKarma(iAttacker, g_ckarmaII.IntValue, true);
        }
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
    {
        addKarma(iAttacker, g_ckarmaIT.IntValue, true);
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
    {
        if (g_iPlayer[client].HurtedPlayer1 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
        } else if (g_iPlayer[client].HurtedPlayer2 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
        } else {
            subtractKarma(iAttacker, g_ckarmaID.IntValue, true);
        }
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
    {
        addKarma(iAttacker, g_ckarmaTI.IntValue, true);
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
    {
        if (g_iPlayer[client].HurtedPlayer1 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt traitor", iAttacker);
        } else if (g_iPlayer[client].HurtedPlayer2 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt traitor", iAttacker);
        } else {
            subtractKarma(iAttacker, g_ckarmaTT.IntValue, true);
        }
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
    {
        addKarma(iAttacker, g_ckarmaTD.IntValue, true);
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
    {
        if (g_iPlayer[client].HurtedPlayer1 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
        } else if (g_iPlayer[client].HurtedPlayer2 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt innocent", iAttacker);
        } else {
            subtractKarma(iAttacker, g_ckarmaDI.IntValue, true);
        }
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
    {
        addKarma(iAttacker, g_ckarmaDT.IntValue, true);
    }
    else if (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
    {
        if (g_iPlayer[client].HurtedPlayer1 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
        } else if (g_iPlayer[client].HurtedPlayer2 == iAttacker && !g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue) {
            CPrintToChat(iAttacker, "%s %T", g_sTag, "No karma hurt detective", iAttacker);
        } else {
            subtractKarma(iAttacker, g_ckarmaDD.IntValue, true);
        }
    }

    if (g_iPlayer[client].Team == TTT_TEAM_UNASSIGNED)
    {
        SetClanTag(client, TTT_TEAM_UNASSIGNED);
    }

    CheckTeams();

    Forward_OnClientDeath(client, iAttacker, badAction);
    
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!TTT_IsClientValid(iAttacker) || iAttacker == client)
    {
        return Plugin_Continue;
    }

    if (g_cKarmaDecreaseWhenKillPlayerWhoHurt.BoolValue)
    {
        return Plugin_Continue;
    }

    if ((g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_INNOCENT) ||
       (g_iPlayer[iAttacker].Team == TTT_TEAM_INNOCENT && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE) ||
       (g_iPlayer[iAttacker].Team == TTT_TEAM_TRAITOR && g_iPlayer[client].Team == TTT_TEAM_TRAITOR)    ||
       (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_INNOCENT) ||
       (g_iPlayer[iAttacker].Team == TTT_TEAM_DETECTIVE && g_iPlayer[client].Team == TTT_TEAM_DETECTIVE))
    {
        if (g_iPlayer[iAttacker].HurtedPlayer1 == -1 && iAttacker != g_iPlayer[client].HurtedPlayer1) {
            g_iPlayer[iAttacker].HurtedPlayer1 = client;
        } else if (g_iPlayer[iAttacker].HurtedPlayer2 == -1 && iAttacker != g_iPlayer[client].HurtedPlayer2 && iAttacker != g_iPlayer[client].HurtedPlayer1) {
            g_iPlayer[iAttacker].HurtedPlayer2 = client;
        } else if (iAttacker != g_iPlayer[client].HurtedPlayer1 && !g_iPlayer[iAttacker].ResetHurt && g_iPlayer[iAttacker].HurtedPlayer1 > 0 && g_iPlayer[iAttacker].HurtedPlayer2 > 0) {
            g_iPlayer[iAttacker].ResetHurt = true;
            g_iPlayer[iAttacker].HurtedPlayer1 = client;
        } else if (iAttacker != g_iPlayer[client].HurtedPlayer2  && iAttacker != g_iPlayer[client].HurtedPlayer1 && g_iPlayer[iAttacker].ResetHurt && g_iPlayer[iAttacker].HurtedPlayer1 > 0 && g_iPlayer[iAttacker].HurtedPlayer2 > 0) {
            g_iPlayer[iAttacker].ResetHurt = false;
            g_iPlayer[iAttacker].HurtedPlayer2 = client;
        }
    }
    
    return Plugin_Continue;
}

public void OnMapEnd()
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(OnMapEnd) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(OnMapEnd) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
        }
    }
    g_iStatus = Round_Inactive;

    if (g_hRoundTimer != null)
    {
        delete g_hRoundTimer;
        g_hRoundTimer = null;
    }

    g_hStartTimer = null;
    g_hCountdownTimer = null;

    LoopValidClients(i)
    {
        if (g_cTranfserArmor.BoolValue)
            g_iPlayer[i].Armor = 0;
        g_iPlayer[i].KarmaReady = false;
    }
}

public Action Timer_OnRoundEnd(Handle timer)
{
    g_hRoundTimer = null;
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Timer_OnRoundEnd) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(Timer_OnRoundEnd) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
        }
    }

    if (!g_cDebug.BoolValue)
    {
        g_iStatus = Round_Ending;
        CS_TerminateRound(7.0, CSRoundEnd_CTWin);
    }
    
    return Plugin_Handled;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    if (g_cDebug.BoolValue || g_iStatus != Round_Ending)
    {
        return Plugin_Handled;
    }

    bool bInnoAlive = false;
    bool bDeteAlive = false;

    int iTeam = TTT_TEAM_UNASSIGNED;

    LoopValidClients(client)
    {
        if ((!g_cpublicKarma.BoolValue) && g_ckarmaRound.BoolValue)
        {
            g_iPlayer[client].KarmaStart = g_iPlayer[client].Karma;
            if(g_ckarmaRoundMessage.BoolValue)
            {
                CPrintToChat(client, "%s %T", g_sTag, "All karma has been updated", client);
            }
        }

        if (IsPlayerAlive(client))
        {
            if (g_iPlayer[client].Team == TTT_TEAM_INNOCENT)
            {
                bInnoAlive = true;
            }
            else if (g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
            {
                bDeteAlive = true;
            }
        }
    }

    if (bInnoAlive)
    {
        iTeam = TTT_TEAM_INNOCENT;
    }
    else if (!bInnoAlive && bDeteAlive)
    {
        if (g_cendwithD.BoolValue)
        {
            iTeam = TTT_TEAM_DETECTIVE;
        }
        else
        {
            iTeam = TTT_TEAM_INNOCENT;
        }
    }
    else
    {
        iTeam = TTT_TEAM_TRAITOR;
    }

    Forward_OnRoundEnd(iTeam, TTT_ROLE_DEFAULT);

    if (g_crandomWinner.BoolValue)
    {
        reason = view_as<CSRoundEndReason>(GetRandomInt(view_as<int>(CSRoundEnd_CTWin), view_as<int>(CSRoundEnd_TerroristWin)));
    }

    if (g_croundDelay.FloatValue > 0.0)
    {
        delay = g_croundDelay.FloatValue;
    }

    if (g_cnextRoundAlert.BoolValue)
    {
        LoopValidClients(client)
        {
            CPrintToChat(client, "%s %T", g_sTag, "next round in", client, delay);
        }
    }

    if (TTT_GetSQLConnection() != null)
    {
        char sQuery[256];
        g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE ttt_rounds SET end = UNIX_TIMESTAMP() WHERE id = %d;", g_iRoundID);
        g_dDB.Query(SQL_UpdateRoundEndTime, sQuery);

        if (g_cSaveLogsInSQL.BoolValue)
        {
            SaveLogsSQL();
        }
    }

    g_iRoundID = -1;
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(CS_OnTerminateRound) g_iStatus set to %d from %d", Round_Ended, g_iStatus);

        if (g_cDebugMessages.BoolValue)
        {
            LogMessage("(CS_OnTerminateRound) g_iStatus set to %d from %d", Round_Ended, g_iStatus);
        }
    }
    g_iStatus = Round_Ended;

    return Plugin_Changed;
}

public Action Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    CheckClantag(client);

    if (g_chideTeams.BoolValue && (!event.GetBool("silent")))
    {
        event.BroadcastDisabled = true;
        dontBroadcast = true;
    }

    return Plugin_Changed;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (client < 1 || !TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_bGhostDM && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) && GhostDM_IsClientInDeathmatch(client))
    {
        return Plugin_Continue;
    }

    if (g_cdenyFire.BoolValue && g_iPlayer[client].Team == TTT_TEAM_UNASSIGNED && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)))
    {
        buttons &= ~IN_ATTACK;
        buttons &= ~IN_ATTACK2;
        return Plugin_Changed;
    }

    int button = -1;
    for (int i = 0; i < 25; i++)
    {
        button = (1 << i);

        if ((buttons & button) || (buttons & IN_USE|IN_SPEED) == IN_USE|IN_SPEED)
        {
            if (!(g_iPlayer[client].LastButtons & button))
            {
                if ((buttons & IN_USE|IN_SPEED) == IN_USE|IN_SPEED)
                {
                    Forward_OnButtonPress(client, buttons);
                }
                else
                {
                    Forward_OnButtonPress(client, button);
                }
            }
        }
        else if ((g_iPlayer[client].LastButtons & button))
        {
            Forward_OnButtonRelease(client, button);
        }
    }

    g_iPlayer[client].LastButtons = buttons;

    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    char sText[MAX_MESSAGE_LENGTH];
    GetCmdArgString(sText, sizeof(sText));

    StripQuotes(sText);

    if (sText[0] == '@')
    {
        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("%s - %s - %s", g_iPlayer[client].Name, command, sArgs);
    }

    if (!StrEqual(command, "say_team", false))
    {
        return Plugin_Continue;
    }

    char sText[MAX_MESSAGE_LENGTH];
    strcopy(sText, sizeof(sText), sArgs);

    StripQuotes(sText);

    if (strlen(sText) < 2)
    {
        return Plugin_Stop;
    }

    if (sText[0] == '@')
    {
        return Plugin_Continue;
    }

    if (g_iPlayer[client].Team == TTT_TEAM_TRAITOR)
    {
        LoopValidClients(i)
        {
            if ((IsPlayerAlive(i) && g_iPlayer[i].Team == TTT_TEAM_TRAITOR) || (g_ctChatToDead.BoolValue && !IsPlayerAlive(i)))
            {
                EmitSoundToClient(i, SND_TCHAT);
                CPrintToChat(i, "%T", "T channel", i, g_iPlayer[client].Name, sText);
            }
        }

        return Plugin_Stop;
    }
    else if (g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
    {
        LoopValidClients(i)
        {
            if ((IsPlayerAlive(i) && g_iPlayer[i].Team == TTT_TEAM_DETECTIVE) || (g_cdChatToDead.BoolValue && !IsPlayerAlive(i)))
            {
                EmitSoundToClient(i, SND_TCHAT);
                CPrintToChat(i, "%T", "D channel", i, g_iPlayer[client].Name, sText);
            }
        }

        return Plugin_Stop;
    }
    return Plugin_Stop;
}

int addKarma(int client, int karma, bool message = false)
{
    Action result = Forward_OnPreKarmaUpdate(client, Karma_Add, karma);
    if (result == Plugin_Stop || result == Plugin_Handled)
    {
        return -1;
    }

    if (g_iStatus != Round_Active)
    {
        return -1;
    }

    g_iPlayer[client].Karma += karma;

    if (TTT_CheckCommandAccess(client, "ttt_karma_vip", g_ckarmaFlag))
    {
        if (g_iPlayer[client].Karma > g_cmaxKarmaVip.IntValue)
        {
            g_iPlayer[client].Karma = g_cmaxKarmaVip.IntValue;
        }
    }
    else
    {
        if (g_iPlayer[client].Karma > g_cmaxKarma.IntValue)
        {
            g_iPlayer[client].Karma = g_cmaxKarma.IntValue;
        }
    }

    if (g_cshowEarnKarmaMessage.BoolValue && message)
    {
        if (g_cmessageTypKarma.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "<pre>%T</pre>", "karma earned", client, karma, g_iPlayer[client].Karma);
            PrintCenterText2(client, "Trouble in Terrorist Town", sBuffer); // TODO: Add 2nd option as synchud
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sTag, "karma earned", client, karma, g_iPlayer[client].Karma);
        }
    }

    UpdatePlayer(client);

    Forward_OnKarmaUpdate(client, Karma_Add, karma);

    return g_iPlayer[client].Karma;
}

int setKarma(int client, int karma, bool force = false)
{
    Action result = Forward_OnPreKarmaUpdate(client, Karma_Set, karma);
    if (result == Plugin_Stop || result == Plugin_Handled)
    {
        return -1;
    }

    if (!force && g_iStatus != Round_Active)
    {
        return -1;
    }

    g_iPlayer[client].Karma = karma;

    if (TTT_CheckCommandAccess(client, "ttt_karma_vip", g_ckarmaFlag))
    {
        if (g_iPlayer[client].Karma > g_cmaxKarmaVip.IntValue)
        {
            g_iPlayer[client].Karma = g_cmaxKarmaVip.IntValue;
        }
    }
    else
    {
        if (g_iPlayer[client].Karma > g_cmaxKarma.IntValue)
        {
            g_iPlayer[client].Karma = g_cmaxKarma.IntValue;
        }
    }

    UpdatePlayer(client);

    Forward_OnKarmaUpdate(client, Karma_Set, karma);

    return g_iPlayer[client].Karma;
}

int subtractKarma(int client, int karma, bool message = false)
{
    Action result = Forward_OnPreKarmaUpdate(client, Karma_Subtract, karma);
    if (result == Plugin_Stop || result == Plugin_Handled)
    {
        return -1;
    }

    if (g_iStatus != Round_Active)
    {
        return -1;
    }

    g_iPlayer[client].Karma -= karma;

    if (g_cshowLoseKarmaMessage.BoolValue && message)
    {
        if (g_cmessageTypKarma.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "<pre>%T</pre>", "lost karma", client, karma, g_iPlayer[client].Karma);
            PrintCenterText2(client, "Trouble in Terrorist Town", sBuffer); // TODO: Add 2nd option as synchud
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sTag, "lost karma", client, karma, g_iPlayer[client].Karma);
        }
    }

    UpdatePlayer(client);

    Forward_OnKarmaUpdate(client, Karma_Subtract, karma);

    return g_iPlayer[client].Karma;
}

void PushStringToLogs(char[] message)
{
    if (g_iTeamSelectTime > 0)
    {
        int iTime = GetTime() - g_iTeamSelectTime;
        int iMin = ((iTime / 60) % 60);
        int iSec = (iTime % 60);

        Format(message, TTT_LOG_SIZE, "[%02i:%02i] %s", iMin, iSec, message);
    }
    g_aLogs.PushString(message);
}

public Action Command_LAW(int client, const char[] command, int argc)
{
    if (g_cFlashlightOption.IntValue != 0)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    SetFlashlight(client);

    if (g_cblockLookAtWeapon.BoolValue)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Command_FL(int client, int args)
{
    if (g_cFlashlightOption.IntValue != 1)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    SetFlashlight(client);

    return Plugin_Continue;
}

void SetFlashlight(int client)
{
    if (g_callowFlash.BoolValue && IsPlayerAlive(client))
    {
        EmitSoundToAllAny(SND_FLASHLIGHT, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_caflashVolume.FloatValue);
        SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
    }
}

void manageRDM(int client)
{
    if (!TTT_IsClientValid(client))
    {
        return;
    }

    if (g_cignoreRDMMenu.BoolValue)
    {
        return;
    }

    int iAttacker = g_iPlayer[client].RDMAttacker;
    if (!TTT_IsClientValid(iAttacker))
    {
        CPrintToChat(client, "%s %T", g_sTag, "The player who RDM'd you is no longer available", client);
        return;
    }

    char display[256], sForgive[64], sPunish[64];
    Format(display, sizeof(display), "%T", "You were RDM'd", client, g_iPlayer[iAttacker].Name);
    Format(sForgive, sizeof(sForgive), "%T", "Forgive", client);
    Format(sPunish, sizeof(sPunish), "%T", "Punish", client);

    Menu menu = new Menu(Menu_RDM);
    menu.SetTitle(display);
    menu.AddItem("Forgive", sForgive);
    menu.AddItem("Punish", sPunish);
    menu.Display(client, 10);
}

public int Menu_RDM(Menu menu, MenuAction action, int client, int option)
{
    if (!TTT_IsClientValid(client))
    {
        return 0;
    }

    int iAttacker = g_iPlayer[client].RDMAttacker;
    if (!TTT_IsClientValid(iAttacker))
    {
        return 0;
    }

    if (action == MenuAction_Select)
    {
        char info[100];
        menu.GetItem(option, info, sizeof(info));
        if (StrEqual(info, "Forgive", false))
        {
            CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, g_iPlayer[iAttacker].Name);
            CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, g_iPlayer[client].Name);

            TTT_SetRoundSlays(iAttacker, 0, true);

            g_iPlayer[client].RDMAttacker = -1;
        }
        if (StrEqual(info, "Punish", false))
        {
            LoopValidClients(i)
            {
                CPrintToChat(i, "%s %T", g_sTag, "Choose Punish", i, g_iPlayer[client].Name, g_iPlayer[iAttacker].Name);
            }

            TTT_AddRoundSlays(iAttacker, g_cRoundSlayPlayerRDM.IntValue, true);

            g_iPlayer[client].RDMAttacker = -1;
        }
    }
    else if (action == MenuAction_Cancel)
    {
        CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, g_iPlayer[iAttacker].Name);
        CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, g_iPlayer[client].Name);

        TTT_SetRoundSlays(iAttacker, 0, true);

        g_iPlayer[client].RDMAttacker = -1;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        CPrintToChat(client, "%s %T", g_sTag, "Choose Forgive Victim", client, g_iPlayer[iAttacker].Name);
        CPrintToChat(iAttacker, "%s %T", g_sTag, "Choose Forgive Attacker", iAttacker, g_iPlayer[client].Name);

        TTT_SetRoundSlays(iAttacker, 0, true);

        g_iPlayer[client].RDMAttacker = -1;

        delete menu;
    }
    
    return 0;
}

public Action Timer_RDMTimer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    g_iPlayer[client].RDMTimer = null;
    manageRDM(client);
    
    return Plugin_Stop;
}

public Action Command_SetTeam(int client, int args)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_set_role", g_cSetTeam, true))
    {
        return Plugin_Handled;
    }

    if (args < 2 || args > 3)
    {
        ReplyToCommand(client, "[SM] Usage: sm_role <#userid|name> <role>");
        ReplyToCommand(client, "[SM] Teams: 1 - Innocent | 2 - Traitor | 3 - Detective");
        return Plugin_Handled;
    }
    char arg1[32];
    char arg2[32];

    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    int target = FindTarget(client, arg1);

    if (target == -1)
    {
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(target))
    {
        ReplyToCommand(client, "[SM] This command can only be used to alive players!");
        return Plugin_Handled;
    }

    int iTeam = StringToInt(arg2);
    int iOld = TTT_GetClientTeam(target);

    if (iTeam < 1 || iTeam > 3)
    {
        ReplyToCommand(client, "[SM] Teams: 1 - Innocent | 2 - Traitor | 3 - Detective");
        return Plugin_Handled;
    }
    else if (iTeam == 1)
    {
        if (iOld == TTT_TEAM_INNOCENT)
        {
            return Plugin_Handled;
        }

        g_iPlayer[target].Team = TTT_TEAM_INNOCENT;

        TeamInitialize(target);
        CS_SetClientClanTag(target, " ");
        CPrintToChat(client, "%s %T", g_sTag, "Player is Now Innocent", client, g_iPlayer[target].Name);
        LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Innocent");

        return Plugin_Handled;
    }
    else if (iTeam == 2)
    {
        if (iOld == TTT_TEAM_TRAITOR)
        {
            return Plugin_Handled;
        }

        g_iPlayer[target].Team = TTT_TEAM_TRAITOR;

        TeamInitialize(target);
        CS_SetClientClanTag(target, " ");
        CPrintToChat(client, "%s %T", g_sTag, "Player is Now Traitor", client, g_iPlayer[target].Name);
        LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Traitor");

        return Plugin_Handled;
    }
    else if (iTeam == 3)
    {
        if (iOld == TTT_TEAM_DETECTIVE)
        {
            return Plugin_Handled;
        }

        g_iPlayer[target].Team = TTT_TEAM_DETECTIVE;

        TeamInitialize(target);
        CPrintToChat(client, "%s %T", g_sTag, "Player is Now Detective", client, g_iPlayer[target].Name);
        LogAction(client, target, "\"%L\" set the role of \"%L\" to \"%s\"", client, target, "Detective");

        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action Command_SetKarma(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_set_karma", g_cSetKarma, true))
    {
        return Plugin_Handled;
    }

    if (args < 2 || args > 3)
    {
        ReplyToCommand(client, "[SM] Usage: sm_setkarma <#userid|name> <karma>");

        return Plugin_Handled;
    }

    char arg1[32];
    char arg2[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (target == -1)
        {
            ReplyToCommand(client, "[SM] Invalid target.");
            return Plugin_Handled;
        }

        if (!g_iPlayer[target].KarmaReady)
        {
            ReplyToCommand(client, "[SM] Player data not loaded yet.");
            return Plugin_Handled;
        }

        int karma = StringToInt(arg2);

        setKarma(target, karma, true);

        CPrintToChat(client, "%s %T", g_sTag, "AdminSet", client, g_iPlayer[target].Name, karma, "Karma");
        LogAction(client, target, "\"%L\" set the karma of \"%L\" to \"%i\"", client, target, karma);
    }

    return Plugin_Continue;
}

public Action Command_Status(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    char sRole[ROLE_LENGTH], sColor[12], sTranslation[64];
    TTT_GetTeamNameByID(g_iPlayer[client].Team, sRole, sizeof(sRole));
    TTT_GetTeamColorByID(g_iPlayer[client].Team, sColor, sizeof(sColor));

    FormatEx(sTranslation, sizeof(sTranslation), "Role: %s", sRole);
    FormatEx(sRole, sizeof(sRole), "%s%T", sColor, sTranslation, client);

    CPrintToChat(client, "%s %T", g_sTag, "Your Role", client, sRole);

    return Plugin_Handled;
}

public Action Timer_5(Handle timer)
{
    LoopValidClients(i)
    {
        if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
        {
            continue;
        }

        if (IsFakeClient(i))
        {
            continue;
        }

        if (!g_cBanKarmaDead.BoolValue && !IsPlayerAlive(i))
        {
            continue;
        }

        int iKarma = g_iPlayer[i].Karma;

        if (iKarma < 0)
        {
            iKarma *= -1;
        }

        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "(Timer_5) - 1 Client: \"%L\", g_iPlayer: KarmaReady: %d, g_cKarmaBan: %d, iKarma: %d (g_iPlayer: .Karma%d)", i, g_iPlayer[i].KarmaReady, g_ckarmaBan.IntValue, iKarma, g_iPlayer[i].Karma);
        }

        if (g_iPlayer[i].KarmaReady && g_ckarmaBan.IntValue > 0 && iKarma > 0 && iKarma <= g_ckarmaBan.IntValue)
        {
            BanBadPlayerKarma(i);
        }
        else if (g_iPlayer[i].KarmaReady && iKarma < 1) // When Karma should be ready and iKarma is 0, we should re-check it.
        {
            LoadClientInfo(GetClientUserId(i));
        }
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("(Timer_5) g_iStatus: %d - g_hStartTimer: %d - g_hCountdownTimer: %d - g_hRoundTimer: %d", g_iStatus, g_hStartTimer, g_hCountdownTimer, g_hRoundTimer);
    }

    if (g_iStatus == Round_Active)
    {
        CheckTeams();
    }
    else if (g_bCheckPlayers ||
            (g_cCheckDuringWarmup.BoolValue && (TTT_IsWarmUp() || g_iStatus <= Round_Warmup)) ||
            (g_cCheckPlayers.BoolValue && (!TTT_IsWarmUp() && g_iStatus <= Round_Warmup && g_hStartTimer == null && g_hCountdownTimer == null && g_hRoundTimer == null)))
    {
        CheckPlayers();
    }
    
    return Plugin_Continue;
}

void CheckPlayers()
{
    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("CheckPlayers - 1 ()");
    }

    if (g_bDisabled)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(CheckPlayers) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(CheckPlayers) g_iStatus set to %d from %d", Round_Inactive, g_iStatus);
            }
        }
        g_iStatus = Round_Inactive;
        return;
    }

    int iCount = 0;
    LoopValidClients(i)
    {
        if (!g_cDebug.BoolValue && (IsFakeClient(i) || IsClientSourceTV(i)))
        {
            continue;
        }

        if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T)
        {
            continue;
        }

        iCount++;
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("CheckPlayers - 2 (iCount: %d - Required: %d)", iCount, g_crequiredPlayers.IntValue);
    }

    if (iCount >= g_crequiredPlayers.IntValue)
    {
        g_bCheckPlayers = false;

        if (g_cDebug.BoolValue)
        {
            PrintToServer("CheckPlayers - 3 (CS_TerminateRound), g_bCheckPlayers: %d", g_bCheckPlayers);
        }

        g_iStatus = Round_Ending;
        CS_TerminateRound(3.0, CSRoundEnd_Draw);
    }
    else
    {
        if (g_cPlayerHUDMessage.BoolValue)
        {
            LoopValidClients(i)
            {
                SetHudTextParams(0.42, 0.53, 5.1, 205, 173, 0, 255, 0, 0.0, 0.0, 0.0);
                ShowSyncHudText(i, g_hWeAreSync, "%T", "WE ARE", i, iCount);
                SetHudTextParams(0.35, 0.565, 5.1, 205, 173, 0, 255, 0, 0.0, 0.0, 0.0);
                ShowSyncHudText(i, g_hRemainingSync, "%T", "REMAINING PLAYERS", i, (g_crequiredPlayers.IntValue - iCount));
            }
        }
    }
}

public void OnEntityCreated(int entity, const char[] name)
{
    if (StrEqual(name, "func_button"))
    {
        char targetName[128];
        GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));

        if (StrEqual(targetName, "Destroy_Trigger", false))
        {
            SDKHook(entity, SDKHook_Use, OnUse);
        }
    }
    else
    {
        for (int i = 0; i < sizeof(g_sRemoveEntityList); i++)
        {
            if (!StrEqual(name, g_sRemoveEntityList[i]))
            {
                continue;
            }

            if (g_cremoveBomb.BoolValue && StrEqual("func_bombtarget", g_sRemoveEntityList[i], false))
            {
                AcceptEntityInput(entity, "kill");
            }
            else if (g_cremoveBuyzone.BoolValue && StrEqual("func_buyzone", g_sRemoveEntityList[i], false))
            {
                AcceptEntityInput(entity, "kill");
            }
            else if (g_cremoveHostages.BoolValue && (StrEqual("hostage_entity", g_sRemoveEntityList[i], false) || StrEqual("func_hostage_rescue", g_sRemoveEntityList[i], false) || StrEqual("info_hostage_spawn", g_sRemoveEntityList[i], false)))
            {
                AcceptEntityInput(entity, "kill");
            }
        }
    }
}

public Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
    if (!TTT_IsClientValid(activator))
    {
        return Plugin_Continue;
    }

    if (g_iStatus != Round_Active)
    {
        return Plugin_Handled;
    }

    if (g_iPlayer[activator].Team != TTT_TEAM_TRAITOR)
    {
        TTT_AddRoundSlays(activator, g_cRoundSlayDestroyTrigger.IntValue, true);

        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sTag, "Triggered Falling Building", i, g_iPlayer[activator].Name);
        }
    }

    return Plugin_Continue;
}

void nameCheck(int client)
{
    if (IsClientSourceTV(client))
    {
        return;
    }

    for (int i; i < g_iBadNameCount; i++)
    {
        if (StrContains(g_sBadNames[i], g_iPlayer[client].Name, false) != -1)
        {
            KickClient(client, "%T", "Kick Bad Name", client, g_sBadNames[i]);
        }
    }
}

public Action Command_KarmaReset(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_karma_reset", g_cKarmaReset, true))
    {
        return Plugin_Handled;
    }

    LoopValidClients(i)
    {
        if (!IsFakeClient(i))
        {
            CPrintToChat(client, "%s %T", g_sTag, "AdminSet", client, g_iPlayer[i].Name, g_cstartKarma.IntValue, "Karma");
            setKarma(i, g_cstartKarma.IntValue, true);
            LogAction(client, i, "\"%L\" reset the karma of \"%L\" to \"%i\"", client, i, g_cstartKarma.IntValue);
        }
    }

    return Plugin_Handled;
}

void CheckTeams()
{
    int iT = 0;
    int iD = 0;
    int iI = 0;

    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            if (g_iPlayer[i].Team == TTT_TEAM_DETECTIVE)
            {
                SetClanTag(i, TTT_TEAM_DETECTIVE);
                iD++;
            }
            else if (g_iPlayer[i].Team == TTT_TEAM_TRAITOR)
            {
                iT++;
            }
            else if (g_iPlayer[i].Team == TTT_TEAM_INNOCENT)
            {
                iI++;
            }
        }
        else
        {
            if (g_iPlayer[i].Team == TTT_TEAM_UNASSIGNED)
            {
                SetClanTag(i, TTT_TEAM_UNASSIGNED);
            }
        }
    }

    if (g_cignoreDeaths.BoolValue)
    {
        return;
    }

    if (iD == 0 && iI == 0)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(CheckTeams) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(CheckTeams) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
            }
        }

        if (!g_cDebug.BoolValue)
        {
            g_iStatus = Round_Ending;
            CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
        }
    }
    else if (iT == 0)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(CheckTeams) g_iStatus set to %d from %d", Round_Ending, g_iStatus);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("(CheckTeams) g_iStatus set to %d from %d", Round_Ending, g_iStatus);
            }
        }

        if (!g_cDebug.BoolValue)
        {
            g_iStatus = Round_Ending;
            CS_TerminateRound(7.0, CSRoundEnd_CTWin);
        }
    }
}

void SetNoBlock(int client)
{
    SetEntProp(client, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
}

void LoadBadNames()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/badnames.ini");

    File hFile = OpenFile(sFile, "rt");

    if (hFile == null)
    {
        SetFailState("[TTT] Can't open File: %s", sFile);
    }

    char sLine[MAX_NAME_LENGTH];

    while (!hFile.EndOfFile() && hFile.ReadLine(sLine, sizeof(sLine)))
    {
        if (strlen(sLine) > 1)
        {
            strcopy(g_sBadNames[g_iBadNameCount], sizeof(g_sBadNames[]), sLine);
            g_iBadNameCount++;
        }
    }

    delete hFile;
}

void LoadClientInfo(any userid)
{
    int client = GetClientOfUserId(userid);

    if (!IsFakeClient(client))
    {
        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "(LoadClientInfo) - 1 Client: \"%L\"", client);
        }

        char sCommunityID[64];

        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            if (g_cDebugMessages.BoolValue)
            {
                LogToFileEx(g_sKarmaFile, "(LoadClientInfo) - 1.1 Client: \"%L\"", client);
            }
            LogToFileEx(g_sErrorFile, "(LoadClientInfo) Auth failed: #%d", client);
            return;
        }

        char sQuery[2048];
        g_dDB.Format(sQuery, sizeof(sQuery), "SELECT `id`, `karma`, `rslays` FROM `ttt` WHERE `communityid`= \"%s\";", sCommunityID);
        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sKarmaFile, "(LoadClientInfo) - 2 Client: \"%L\", Query: \"%s\"", client, sQuery);
        }

        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sLogFile, sQuery);
        }

        if (g_dDB != null)
        {
            if (g_cDebugMessages.BoolValue)
            {
                LogToFileEx(g_sKarmaFile, "(LoadClientInfo) - 3 Client: \"%L\", Valid Database", client);
            }
            g_dDB.Query(SQL_OnClientPutInServer, sQuery, userid);
        }
    }
}

void UpdatePlayer(int client)
{
    if (g_iPlayer[client].KarmaReady)
    {
        char sCommunityID[64];

        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            LogToFileEx(g_sErrorFile, "(UpdatePlayer) Auth failed: #%d", client);
            return;
        }

        char sQuery[2048];
        g_dDB.Format(sQuery, sizeof(sQuery), "INSERT INTO ttt (communityid, name, karma, rslays) VALUES (\"%s\", \"%s\", %d, %d) ON DUPLICATE KEY UPDATE name=\"%s\", karma = '%d', rslays = '%d';", sCommunityID, g_iPlayer[client].Name, g_iPlayer[client].Karma, g_iPlayer[client].RoundSlays, g_iPlayer[client].Name, g_iPlayer[client].Karma, g_iPlayer[client].RoundSlays);

        if (g_cDebugMessages.BoolValue)
        {
            LogToFileEx(g_sLogFile, sQuery);
        }

        if (g_dDB != null)
        {
            g_dDB.Query(Callback_UpdatePlayer, sQuery, GetClientUserId(client));
        }
    }
}

void UpdatePlayerRSlays(int client)
{
    if (IsClientSourceTV(client) || IsFakeClient(client))
    {
        return;
    }

    if (g_iPlayer[client].RoundSlays >= 0)
    {
        char sCommunityID[64];

        if (strlen(g_sErrorFile) > 3 && !GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            LogToFileEx(g_sErrorFile, "(UpdatePlayerRSlays) Auth failed: #%d", client);
        }

        char sQuery[2048];
        g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE ttt SET rslays=%d WHERE communityid = \"%s\"", g_iPlayer[client].RoundSlays, sCommunityID);

        if (g_dDB != null)
        {
            g_dDB.Query(Callback_UpdateRoundSlays, sQuery, GetClientUserId(client));
        }
    }
}

void UpdatePlayerRSlaysByID(int id, int rounds)
{
    char sQuery[2048];
    g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE `ttt` SET `rslays`=`rslays`+'%d' WHERE `id` = '%d';", rounds, id);

    if (g_dDB != null)
    {
        g_dDB.Query(Callback_UpdateRoundSlays, sQuery);
    }
}

void StripAllWeapons(int client)
{
    if (!g_cstripWeapons.BoolValue)
    {
        return;
    }

    int iEnt;
    for (int i = CS_SLOT_PRIMARY; i <= CS_SLOT_C4; i++)
    {
        while ((iEnt = GetPlayerWeaponSlot(client, i)) != -1)
        {
            TTT_SafeRemoveWeapon(client, iEnt);
        }
    }
}

void CheckClantag(int client)
{
    char sTag[32];
    CS_GetClientClanTag(client, sTag, sizeof(sTag));

    if (!ValidClantag(sTag))
    {
        if (g_iStatus != Round_Active)
        {
            CS_SetClientClanTag(client, " ");
        }
        else
        {
            bool found = TTT_WasBodyFound(client);
            if (!found)
            {
                if (g_iPlayer[client].Team == TTT_TEAM_UNASSIGNED)
                {
                    SetClanTag(client, TTT_TEAM_UNASSIGNED);
                }
                else if (g_iPlayer[client].Team == TTT_TEAM_DETECTIVE)
                {
                    SetClanTag(client, TTT_TEAM_DETECTIVE);
                }
                else
                {
                    CS_SetClientClanTag(client, " ");
                }
            }
            else if (found)
            {
                TeamTag(client);
            }
        }
    }
}

bool ValidClantag(const char[] sTag)
{
    if (StrContains(sTag, "DETECTIVE", false) != -1 || StrContains(sTag, "TRAITOR", false) != -1 || StrContains(sTag, "INNOCENT", false) != -1 || StrContains(sTag, "UNASSIGNED", false) != -1)
    {
        return true;
    }

    if (StrEqual(sTag, " ", false))
    {
        return true;
    }

    return false;
}

void GiveWeaponsOnFailStart()
{
    if (g_cGiveWeaponsOnFailStart.BoolValue && g_cEnableDamage.BoolValue)
    {
        LoopValidClients(i)
        {
            if (GetClientTeam(i) != CS_TEAM_CT && GetClientTeam(i) != CS_TEAM_T || IsFakeClient(i))
            {
                continue;
            }

            if (IsPlayerAlive(i))
            {
                GivePlayerItem(i, "weapon_knife");

                char sWeapon[32];

                Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSSecondary);
                GivePlayerItem(i, sWeapon);

                Format(sWeapon, sizeof(sWeapon), "weapon_%s", g_sFSPrimary);
                GivePlayerItem(i, sWeapon);
            }
        }
    }
}

void SetClanTag(int client, int team)
{
    char sTeamName[ROLE_LENGTH], sTeamTagName[ROLE_LENGTH], sTranslation[64];

    TTT_GetTeamNameByID(team, sTeamName, sizeof(sTeamName));

    Format(sTranslation, sizeof(sTranslation), "ClanTag: %s", sTeamName);
    Format(sTeamTagName, sizeof(sTeamTagName), "%t", sTranslation);

    if (g_cClanTagUpperLower.IntValue == 0)
    {
        StringToUpper(sTeamTagName, sTeamTagName, sizeof(sTeamTagName));
    }
    else if (g_cClanTagUpperLower.IntValue == 1)
    {
        StringToLower(sTeamTagName, sTeamTagName, sizeof(sTeamTagName));
    }

    CS_SetClientClanTag(client, sTeamTagName);
}

void GiveMelee(int client)
{
    TTT_RemoveMeleeWeapons(client);

    char sWeapon[32];
    g_cStartMelee.GetString(sWeapon, sizeof(sWeapon));

    int iWeapon = -1;

    if (strlen(sWeapon) > 1)
    {
        Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);

        iWeapon = GivePlayerItem(client, sWeapon);
        EquipPlayerWeapon(client, iWeapon);
    }

    if (g_cAdditionalMeleeTeam.IntValue & g_iPlayer[client].Team)
    {
        g_cAdditionalMeleeWeapon.GetString(sWeapon, sizeof(sWeapon));

        if (strlen(sWeapon) > 1)
        {
            Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
            iWeapon = GivePlayerItem(client, sWeapon);
            EquipPlayerWeapon(client, iWeapon);
        }
    }
}

public void Frame_GivePrimary(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        GivePlayerItem(client, g_sDefaultPrimary);
    }
}

public void Frame_GiveSecondary(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        GivePlayerItem(client, g_sDefaultSecondary);
    }
}

void CheckCPS()
{
    char sPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sPath, sizeof(sPath), "plugins/CustomPlayerSkins.smx");

    if (!FileExists(sPath))
    {
        return;
    }

    Handle hPlugin = FindPluginByFile("CustomPlayerSkins.smx");

    if (hPlugin == null)
    {
        return;
    }

    PluginStatus pStatus = GetPluginStatus(hPlugin);

    if (pStatus == Plugin_Running)
    {
        ServerCommand("sm plugins unload CustomPlayerSkins");
        LogMessage("CustomPlayerSkins unloaded, no longer required.");

        if (g_cRemovePlugins.BoolValue)
        {
            DeleteFile(sPath);
        }
    }

    delete hPlugin;
}

public void ClearClientData(int client)
{
    g_iPlayer[client].Team = TTT_TEAM_UNASSIGNED;
    PrintToChat(client, "Set to Unassigned");
    g_iPlayer[client].Role = TTT_ROLE_DEFAULT;
    g_iPlayer[client].LastTeam = TTT_TEAM_UNASSIGNED;
    g_iPlayer[client].Karma = -1;
    g_iPlayer[client].KarmaStart = -1;
    g_iPlayer[client].Armor = 0;
    g_iPlayer[client].Site = -1;
    g_iPlayer[client].HurtedPlayer1 = -1;
    g_iPlayer[client].HurtedPlayer2 = -1;
    g_iPlayer[client].InnocentKills = -1;
    g_iPlayer[client].DetectiveKills = -1;
    g_iPlayer[client].TraitorKills = -1;
    g_iPlayer[client].RDMAttacker = -1;
    g_iPlayer[client].RoundSlays = 0;
    g_iPlayer[client].LastButtons = -1;
    g_iPlayer[client].ID = -1;

    g_iPlayer[client].KarmaReady = false;
    g_iPlayer[client].Alive = false;
    g_iPlayer[client].Respawn = false;
    g_iPlayer[client].ReceivingLogs = false;
    g_iPlayer[client].Rules = false;
    g_iPlayer[client].DetectiveRules = false;
    g_iPlayer[client].ReadRules = false;
    g_iPlayer[client].KnowRules = false;
    g_iPlayer[client].AvoidDetective = false;
    g_iPlayer[client].ImmuneRDMManager = false;
    g_iPlayer[client].ResetHurt = false;

    delete g_iPlayer[client].RDMTimer;
}

// Stock taken from smlib
// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/strings.inc#L103
stock void StringToLower(const char[] input, char[] output, int size)
{
    size--;

    int x = 0;
    while (input[x] != '\0' && x < size) {

        output[x] = CharToLower(input[x]);

        x++;
    }

    output[x] = '\0';
}

// Stock taken from smlib
// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/strings.inc#L127
stock void StringToUpper(const char[] input, char[] output, int size)
{
    size--;

    int x = 0;
    while (input[x] != '\0' && x < size) {

        output[x] = CharToUpper(input[x]);

        x++;
    }

    output[x] = '\0';
}

public int GetClientOfPlayerID(int id)
{
    for (int i = 1; i < MaxClients; ++i)
    {
        if (g_iPlayer[i].ID == id)
            return i;
    }

    return -1;
}

bool AreTeamsEmpty()
{
    return GetTeamClientCount(CS_TEAM_T) + GetTeamClientCount(CS_TEAM_CT) < 1;
}

int DetermineTeam()
{
    int tCount = GetTeamClientCount(CS_TEAM_T);
    int ctCount = GetTeamClientCount(CS_TEAM_CT);

    return tCount == ctCount ? GetRandomInt(CS_TEAM_T, CS_TEAM_CT) : tCount < ctCount ? CS_TEAM_T : CS_TEAM_CT;
}

void EscapeName(char[] name, int size)
{
    if (g_cNameFix.IntValue == 0)
    {
        CEscapeTags(name, size);
    }
    else if (g_cNameFix.IntValue == 1)
    {
        CRemoveTags(name, size);
    }
}

int GetClientRoundSlays(int client)
{
    return g_iPlayer[client].RoundSlays;
}

bool DoClientRoundSlays(int client)
{
    if (g_iPlayer[client].RoundSlays > 0)
    {
        if (IsPlayerAlive(client))
        {
            ForcePlayerSuicide(client);
        }

        g_iPlayer[client].RoundSlays--;

        Forward_OnRoundSlay(client);

        if (g_iPlayer[client].RoundSlays > 0)
        {
            CPrintToChat(client, "%s %T", g_sTag, "RS - Slayed", client, g_iPlayer[client].RoundSlays);
            LogAction(0, client, "\"%L\" was slayed! Remaining Rounds: %d", client, g_iPlayer[client].RoundSlays);
        }

        UpdatePlayerRSlays(client);

        if (g_cOpenRulesOnPunish.BoolValue)
        {
            TTT_ClientOpenRules(client);
        }
    }
    else if (g_iPlayer[client].RoundSlays < 0)
    {
        g_iPlayer[client].RoundSlays = 0;
        UpdatePlayerRSlays(client);

        return false;
    }
    else
    {
        UpdatePlayerRSlays(client);

        return false;
    }

    return true;
}
