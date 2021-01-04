#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_sql>
#include <ttt_bodies>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Stats"

ConVar g_cDebug = null;

Database g_dDB = null;

ConVar g_cPlayers = null;
ConVar g_cConsoleRoundLogs = null;

bool g_bValidRound = false;

enum struct PlayerData {
    int RoundsPlayed;
    int PlayedAsInnocent;
    int PlayedAsTraitor;
    int PlayedAsDetective;
    int RoundsWon;
    int ShotsFired;
    int DamageTaken;
    int DamageGiven;
    int BadDamageTaken;
    int BadDamageGiven;
    int SlayedRounds;
    int KilledInnocents;
    int KilledTraitors;
    int KilledDetectives;
    int BadKills;
    int IdentifiedBodies;
    int IdentifiedTraitors;
    int ScannedBodies;
    int ScannedTraitors;
    int BoughtItems;

    bool Ready;
    bool InRound;

    char Auth[32];

    void ResetRound()
    {
        this.ShotsFired = 0;
        this.DamageTaken = 0;
        this.DamageGiven = 0;
        this.BadDamageTaken = 0;
        this.BadDamageGiven = 0;
        this.KilledInnocents = 0;
        this.KilledTraitors = 0;
        this.KilledDetectives = 0;
        this.BadKills = 0;
        this.IdentifiedBodies = 0;
        this.IdentifiedTraitors = 0;
        this.ScannedBodies = 0;
        this.ScannedTraitors = 0;
        this.BoughtItems = 0;
    }
}

PlayerData Player[MAXPLAYERS + 1];
PlayerData PlayerRound[MAXPLAYERS + 1];

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
    TTT_LoadTranslations();
    LoadTranslations("common.phrases");

    TTT_StartConfig("stats");
    CreateConVar("ttt2_stats_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cPlayers = AutoExecConfig_CreateConVar("stats_required_players", "8", "Required amount of players to enable stats");
    g_cConsoleRoundLogs = AutoExecConfig_CreateConVar("stats_console_round_log", "1", "Print round logs to players console?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    if (TTT_GetSQLConnection() != null)
    {
        g_dDB = TTT_GetSQLConnection();
    }

    LoopValidClients(i)
    {
        OnClientPostAdminCheck(i);
    }

    HookEvent("weapon_fire", Event_WeaponFire);

    RegConsoleCmd("sm_stats", Command_Stats);
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_debug_mode");
    g_bValidRound = false;
}

public void OnPluginEnd()
{
    LoopValidClients(i)
    {
        UpdatePlayer(i);
    }
}

public void TTT_OnSQLConnect(Database db)
{
    g_dDB = db;

    CreateTable();
}

void CreateTable()
{
    char sQuery[2048];
    Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt_stats` (`id` INT NOT NULL AUTO_INCREMENT, `communityid` VARCHAR(64) NOT NULL, `rounds_played` INT DEFAULT 0, `rounds_won` INT DEFAULT 0, `played_as_innocent` INT DEFAULT 0, `played_as_traitor` INT DEFAULT 0, `played_as_detective` INT DEFAULT 0, `shots_fired` INT DEFAULT 0, `damage_taken` INT DEFAULT 0, `damage_given` INT DEFAULT 0, `bad_damage_taken` INT DEFAULT 0, `bad_damage_given` INT DEFAULT 0, `slayed_rounds` INT DEFAULT 0, `killed_innocents` INT DEFAULT 0, `killed_traitors` INT DEFAULT 0, `killed_detectives` INT DEFAULT 0, `bad_kills` INT DEFAULT 0, `identified_bodies` INT DEFAULT 0, `identified_traitors` INT DEFAULT 0, `scanned_bodies` INT DEFAULT 0, `scanned_traitors` INT DEFAULT 0, `bought_items` INT DEFAULT 0, PRIMARY KEY (`id`), UNIQUE (`communityid`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");

    TTT_Query("[Stats] (CreateTable) - Callback_CheckAndCreateTables", sQuery);
    TTT_Query("[Stats] (CreateTable) - SQLCallback_ConvertToUTF8MB4", "ALTER TABLE ttt_stats CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
}

public Action Command_Stats(int client, int args)
{
    if (!Stats_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    int target = -1;

    if (args == 0)
    {
        target = client;
    }
    else if (args == 1)
    {
        char sArg[MAX_NAME_LENGTH];
        GetCmdArg(1, sArg, sizeof(sArg));
        target = FindTarget(client, sArg, true, false);

        if (!Stats_IsClientValid(target))
        {
            ReplyToCommand(client, "Target is not valid!");
            return Plugin_Handled;
        }
    }
    else
    {
        ReplyToCommand(client, "sm_stats <#UserID/Name (optional)>");
        return Plugin_Handled;
    }

    ShowPlayerStats(client, target);

    return Plugin_Handled;
}

void ShowPlayerStats(int client, int target)
{
    Menu menu = new Menu(Menu_ShowPlayerStats);
    
    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(target, sName, sizeof(sName));
    menu.SetTitle("Player Statistics for %s", sName);

    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Rounds Played: %d", Player[target].RoundsPlayed);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Innocent: %d", Player[target].PlayedAsInnocent);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Traitor: %d", Player[target].PlayedAsTraitor);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Detective: %d", Player[target].PlayedAsDetective);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Rounds Won: %d", Player[target].RoundsWon);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Shots Fired: %d", Player[target].ShotsFired);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Damage Taken: %d", Player[target].DamageTaken);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Damage Given: %d", Player[target].DamageGiven);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad Damage Taken: %d", Player[target].BadDamageTaken);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad Damage Given: %d", Player[target].BadDamageGiven);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Rounds Slayed: %d", Player[target].SlayedRounds);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Innocent kills: %d", Player[target].KilledInnocents);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Traitor kills: %d", Player[target].KilledTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Detective kills: %d", Player[target].KilledDetectives);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad kills: %d", Player[target].BadKills);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Identified Bodies: %d", Player[target].IdentifiedBodies);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Identified Traitors: %d", Player[target].IdentifiedTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Scanned Bodies: %d", Player[target].ScannedBodies);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Scanned Traitors: %d", Player[target].ScannedTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Items bought: %d", Player[target].BoughtItems);
    menu.AddItem(sBuffer, sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ShowPlayerStats(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void OnClientPutInServer(int client)
{
    Player[client].Ready = false;
    Player[client].InRound = false;
}

public void OnClientPostAdminCheck(int client)
{
    if (!Stats_IsClientValid(client))
    {
        return;
    }

    if (!GetClientAuthId(client, AuthId_SteamID64, Player[client].Auth, sizeof(PlayerData::Auth)))
    {
        LogError("[Stats] (OnClientPostAdminCheck) GetClientAuthId: Can't get the communityid for: \"%L\"", client);
        return;
    }

    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT rounds_played, rounds_won, played_as_innocent, played_as_traitor, played_as_detective, shots_fired, damage_taken, damage_given, bad_damage_taken, bad_damage_given, slayed_rounds, killed_innocents, killed_traitors, killed_detectives, bad_kills, identified_bodies, identified_traitors, scanned_bodies, scanned_traitors, bought_items FROM ttt_stats WHERE communityid = \"%s\";", Player[client].Auth);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[Stats] (OnClientPostAdminCheck) - %s", sQuery);
    }

    g_dDB.Query(SQL_GetPlayerData, sQuery, GetClientUserId(client), DBPrio_High);
}

public void OnClientDisconnect(int client)
{
    UpdatePlayer(client);

    Player[client].Ready = false;
    Player[client].InRound = false;
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    g_bValidRound = false;

    int iPlayers = innocents + traitors + detective;

    if (iPlayers < g_cPlayers.IntValue)
    {
        return;
    }

    g_bValidRound = true;

    LoopValidClients(i)
    {
        if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR || TTT_GetClientRole(i) == TTT_TEAM_INNOCENT || TTT_GetClientRole(i) == TTT_TEAM_DETECTIVE)
        {
            PlayerRound[i].ResetRound();

            Player[i].InRound = true;
        }
    }
}

public int TTT_OnRoundSlay(int client, int remaining)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(client))
    {
        Player[client].SlayedRounds++;
    }
}

public void TTT_OnItemPurchasePost(int client, int price, int count, const char[] itemshort)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(client))
    {
        Player[client].BoughtItems++;
        PlayerRound[client].BoughtItems++;
    }
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bValidRound)
    {
        return;
    }
        
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (Stats_IsClientValid(client))
    {
        char sWeapon[32];
        if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1 || StrContains(sWeapon, "hegrenade", false) != -1 || StrContains(sWeapon, "flashbang", false) != -1 || StrContains(sWeapon, "smokegrenade", false) != -1 || StrContains(sWeapon, "inferno", false) != -1 || StrContains(sWeapon, "molotov", false) != -1 || StrContains(sWeapon, "incgrenade", false) != -1 || StrContains(sWeapon, "decoy", false) != -1)
        {
            return; 
        }
        
        Player[client].ShotsFired++;
        PlayerRound[client].ShotsFired++;
    }
}

public void TTT_OnTakeDamage(int victim, int attacker, float damage, int weapon, bool badAction)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(victim) && Stats_IsClientValid(attacker))
    {
        if (badAction)
        {
            Player[attacker].BadDamageGiven += RoundToCeil(damage);
            Player[victim].BadDamageTaken += RoundToCeil(damage);
            PlayerRound[attacker].BadDamageGiven += RoundToCeil(damage);
            PlayerRound[victim].BadDamageTaken += RoundToCeil(damage);
        }
        else
        {
            Player[attacker].DamageGiven += RoundToCeil(damage);
            Player[victim].DamageTaken += RoundToCeil(damage);
            PlayerRound[attacker].DamageGiven += RoundToCeil(damage);
            PlayerRound[victim].DamageTaken += RoundToCeil(damage);
        }
    }
}

public void TTT_OnClientDeath(int victim, int attacker, bool badAction)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(victim) && Stats_IsClientValid(attacker))
    {
        int iRole = TTT_GetClientRole(victim);

        if (iRole == TTT_TEAM_TRAITOR)
        {
            Player[attacker].KilledTraitors++;
            PlayerRound[attacker].KilledTraitors++;
        }
        else if (iRole == TTT_TEAM_DETECTIVE)
        {
            Player[attacker].KilledDetectives++;
            PlayerRound[attacker].KilledDetectives++;
        }
        else if (iRole == TTT_TEAM_INNOCENT)
        {
            Player[attacker].KilledInnocents++;
            PlayerRound[attacker].KilledInnocents++;
        }

        if (badAction)
        {
            Player[attacker].BadKills++;
            PlayerRound[attacker].BadKills++;
        }
    }
}

public void TTT_OnBodyFound(int attacker, int victim, int victimRole, int attackerRole, int entityref, bool silentID)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(attacker))
    {
        Ragdoll body;
        TTT_GetEntityRefRagdoll(entityref, body);

        if (body.VictimRole == TTT_TEAM_TRAITOR)
        {
            Player[attacker].IdentifiedTraitors++;
            PlayerRound[attacker].IdentifiedTraitors++;
        }
        else
        {
            Player[attacker].IdentifiedBodies++;
            PlayerRound[attacker].IdentifiedBodies++;
        }
    }
}

public Action TTT_OnBodyCheck(int attacker, int entityref)
{
    if (!g_bValidRound)
    {
        return;
    }

    if (Stats_IsClientValid(attacker))
    {
        Ragdoll body;
        TTT_GetEntityRefRagdoll(entityref, body);

        if (body.VictimRole == TTT_TEAM_TRAITOR)
        {
            Player[attacker].ScannedTraitors++;
            PlayerRound[attacker].ScannedTraitors++;
        }
        else
        {
            Player[attacker].ScannedBodies++;
            PlayerRound[attacker].ScannedBodies++;
        }
    }
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("TTT_OnRoundEnd");
    }

    if (!g_bValidRound)
    {
        return;
    }

    LoopValidClients(i)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToChat(i, "InRound: %d", Player[i].InRound);
        }

        if (Player[i].InRound)
        {
            int iRole = TTT_GetClientRole(i);

            Player[i].RoundsPlayed++;

            if  (iRole == winner || (iRole == TTT_TEAM_DETECTIVE && winner == TTT_TEAM_INNOCENT) || (iRole == TTT_TEAM_INNOCENT && winner == TTT_TEAM_DETECTIVE))
            {
                Player[i].RoundsWon++;
            }

            if (iRole == TTT_TEAM_INNOCENT)
            {
                Player[i].PlayedAsInnocent++;
            }
            if (iRole == TTT_TEAM_TRAITOR)
            {
                Player[i].PlayedAsTraitor++;
            }
            if (iRole == TTT_TEAM_DETECTIVE)
            {
                Player[i].PlayedAsDetective++;
            }

            if (g_cConsoleRoundLogs.BoolValue)
            {
                PrintConsoleRoundLogs(i);
            }
        }

        if (g_cDebug.BoolValue)
        {
            PrintToChat(i, "Played: %d, Won: %d", Player[i].RoundsPlayed, Player[i].RoundsWon);
        }

        Player[i].InRound = false;

        UpdatePlayer(i);
    }

    g_bValidRound = false;
}

void PrintConsoleRoundLogs(int client)
{
    PrintToConsole(client, "Your logs for this round:");
    PrintToConsole(client, " Shots Fired: %d", PlayerRound[client].ShotsFired);
    PrintToConsole(client, " Damage Taken: %d", PlayerRound[client].DamageTaken);
    PrintToConsole(client, " Damage Given: %d", PlayerRound[client].DamageGiven);
    PrintToConsole(client, " Bad Damage Taken: %d", PlayerRound[client].BadDamageTaken);
    PrintToConsole(client, " Bad Damage Given: %d", PlayerRound[client].BadDamageGiven);
    PrintToConsole(client, " Killed Innocents: %d", PlayerRound[client].KilledInnocents);
    PrintToConsole(client, " Killed Traitors: %d", PlayerRound[client].KilledTraitors);
    PrintToConsole(client, " Killed Detectives: %d", PlayerRound[client].KilledDetectives);
    PrintToConsole(client, " Bad Kills: %d", PlayerRound[client].BadKills);
    PrintToConsole(client, " Identified Bodies: %d", PlayerRound[client].IdentifiedBodies);
    PrintToConsole(client, " Identified Traitors: %d", PlayerRound[client].IdentifiedTraitors);
    PrintToConsole(client, " Scanned Bodies: %d", PlayerRound[client].ScannedBodies);
    PrintToConsole(client, " Scanned Traitors: %d", PlayerRound[client].ScannedTraitors);
    PrintToConsole(client, " Bought Items: %d", PlayerRound[client].BoughtItems);
}

public void SQL_GetPlayerData(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[Stats] (SQL_GetPlayerData) - Query failed: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (Stats_IsClientValid(client))
        {
            if (results.RowCount > 0 && results.FetchRow())
            {
                Player[client].RoundsPlayed = results.FetchInt(0);
                Player[client].RoundsWon = results.FetchInt(1);
                Player[client].PlayedAsInnocent = results.FetchInt(2);
                Player[client].PlayedAsTraitor = results.FetchInt(3);
                Player[client].PlayedAsDetective = results.FetchInt(4);
                Player[client].ShotsFired = results.FetchInt(5);
                Player[client].DamageTaken = results.FetchInt(6);
                Player[client].DamageGiven = results.FetchInt(7);
                Player[client].BadDamageTaken = results.FetchInt(8);
                Player[client].BadDamageGiven = results.FetchInt(9);
                Player[client].SlayedRounds = results.FetchInt(10);
                Player[client].KilledInnocents = results.FetchInt(11);
                Player[client].KilledTraitors = results.FetchInt(12);
                Player[client].KilledDetectives = results.FetchInt(13);
                Player[client].BadKills = results.FetchInt(14);
                Player[client].IdentifiedBodies = results.FetchInt(15);
                Player[client].IdentifiedTraitors = results.FetchInt(16);
                Player[client].ScannedBodies = results.FetchInt(17);
                Player[client].ScannedTraitors = results.FetchInt(18);
                Player[client].BoughtItems = results.FetchInt(19);

                Player[client].Ready = true;
            }
            else
            {
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "INSERT INTO ttt_stats (communityid) VALUES (\"%s\");", Player[client].Auth);

                if (g_cDebug.BoolValue)
                {
                    LogMessage("[Stats] (SQL_GetPlayerData) - Query: %s", sQuery);
                }

                g_dDB.Query(SQL_InsertPlayer, sQuery, GetClientUserId(client), DBPrio_High);
            }
        }
    }
}

public void SQL_InsertPlayer(Database db, DBResultSet results, const char[] error, int userid)
{
    if ((db == null || strlen(error) > 0) && StrContains(error, "Duplicate entry", false) == -1)
    {
        LogError("[Stats] (SQL_InsertPlayer) - Query failed: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (!Stats_IsClientValid(client))
        {
            return;
        }

        OnClientPostAdminCheck(client);
    }
}

void UpdatePlayer(int client)
{
    if (!Stats_IsClientValid(client))
    {
        return;
    }

    if (strlen(Player[client].Auth) < 2)
    {
        return;
    }

    char sQuery[1024];
    Format(sQuery, sizeof(sQuery), "UPDATE ttt_stats SET `rounds_played` = '%d', `rounds_won` = '%d', `played_as_innocent` = '%d', `played_as_traitor` = '%d', `played_as_detective` = '%d', `shots_fired` = '%d', `damage_taken` = '%d', `damage_given` = '%d', `bad_damage_taken` = '%d', `bad_damage_given` = '%d', `slayed_rounds` = '%d', `killed_innocents` = '%d', `killed_traitors` = '%d', `killed_detectives` = '%d', `bad_kills` = '%d', `identified_bodies` = '%d', `identified_traitors` = '%d', `scanned_bodies` = '%d', `scanned_traitors` = '%d', `bought_items` = '%d' WHERE communityid = \"%s\";",
    Player[client].RoundsPlayed, Player[client].RoundsWon, Player[client].PlayedAsInnocent, Player[client].PlayedAsTraitor, Player[client].PlayedAsDetective, Player[client].ShotsFired, Player[client].DamageTaken, Player[client].DamageGiven, Player[client].BadDamageTaken, Player[client].BadDamageGiven, Player[client].SlayedRounds, Player[client].KilledInnocents, Player[client].KilledTraitors, Player[client].KilledDetectives, Player[client].BadKills, Player[client].IdentifiedBodies, Player[client].IdentifiedTraitors, Player[client].ScannedBodies, Player[client].ScannedTraitors, Player[client].BoughtItems, Player[client].Auth);

    if (g_cDebug.BoolValue)
    {
        LogMessage(sQuery);
    }

    g_dDB.Query(SQL_UpdatePlayer, sQuery, GetClientUserId(client), DBPrio_High);
}

public void SQL_UpdatePlayer(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[Stats] (SQL_UpdatePlayer) - Query failed: %s", error);
        return;
    }
    /* else
    {
        int client = GetClientOfUserId(userid);

        if (!Stats_IsClientValid(client))
        {
            return;
        }

        OnClientPostAdminCheck(client);
    } */
}

bool Stats_IsClientValid(int client)
{
    if (TTT_IsClientValid(client) && !IsFakeClient(client))
    {
        return true;
    }
    
    return false;
}
