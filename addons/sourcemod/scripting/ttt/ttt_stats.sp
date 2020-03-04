#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_shop>
#include <ttt_sql>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Stats"

ConVar g_cDebug = null;

Database g_dDB = null;

ConVar g_cPlayers = null;

char g_sDriver[16];

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
    int IdenfifiedBodies;
    int IdentifiedTraitors;
    int ScannedBodies;
    int ScannedTraitors;
    int BoughtItems;

    bool Ready;
    bool InRound;

    char Auth[32];
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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

    DBDriver iDriver = g_dDB.Driver;
    iDriver.GetIdentifier(g_sDriver, sizeof(g_sDriver));

    CreateTable();
}

void CreateTable()
{
    char sQuery[2048];

    if (StrEqual(g_sDriver, "mysql", false))
    {
        Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt_stats` (`id` INT NOT NULL AUTO_INCREMENT, `communityid` VARCHAR(64) NOT NULL, `rounds_played` INT DEFAULT 0, `rounds_won` INT DEFAULT 0, `played_as_innocent` INT DEFAULT 0, `played_as_traitor` INT DEFAULT 0, `played_as_detective` INT DEFAULT 0, `shots_fired` INT DEFAULT 0, `damage_taken` INT DEFAULT 0, `damage_given` INT DEFAULT 0, `bad_damage_taken` INT DEFAULT 0, `bad_damage_given` INT DEFAULT 0, `slayed_rounds` INT DEFAULT 0, `killed_innocents` INT DEFAULT 0, `killed_traitors` INT DEFAULT 0, `killed_detectives` INT DEFAULT 0, `bad_kills` INT DEFAULT 0, `identified_bodies` INT DEFAULT 0, `identified_traitors` INT DEFAULT 0, `scanned_bodies` INT DEFAULT 0, `scanned_traitors` INT DEFAULT 0, `bought_items` INT DEFAULT 0, PRIMARY KEY (`id`), UNIQUE (`communityid`)) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");
    }
    else
    {
        SetFailState("[Stats] (CreateTable) - Unsupported sql driver: %s", g_sDriver);
        return;
    }

    TTT_Query("[Stats] (CreateTable) - Callback_CheckAndCreateTables", sQuery);

    SetCharsetAndCollate();
}

void SetCharsetAndCollate()
{
    if (StrEqual(g_sDriver, "mysql", false))
    {
        g_dDB.SetCharset("utf8mb4");
        TTT_Query("[Stats] (SetCharsetAndCollate) - SQLCallback_OnSetNames", "SET NAMES 'utf8mb4';");
        TTT_Query("[Stats] (SetCharsetAndCollate) - SQLCallback_ConvertToUTF8MB4", "ALTER TABLE ttt_stats CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
    }
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
    menu.SetTitle("Player Statistics for %N", target);

    char sBuffer[64];
    Format(sBuffer, sizeof(sBuffer), "Rounds Played: %d", g_iPlayer[target].RoundsPlayed);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Innocent: %d", g_iPlayer[target].PlayedAsInnocent);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Traitor: %d", g_iPlayer[target].PlayedAsTraitor);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), " - as Detective: %d", g_iPlayer[target].PlayedAsDetective);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Rounds Won: %d", g_iPlayer[target].RoundsWon);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Shots Fired: %d", g_iPlayer[target].ShotsFired);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Damage Taken: %d", g_iPlayer[target].DamageTaken);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Damage Given: %d", g_iPlayer[target].DamageGiven);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad Damage Taken: %d", g_iPlayer[target].BadDamageTaken);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad Damage Given: %d", g_iPlayer[target].BadDamageGiven);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Rounds Slayed: %d", g_iPlayer[target].SlayedRounds);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Innocent kills: %d", g_iPlayer[target].KilledInnocents);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Traitor kills: %d", g_iPlayer[target].KilledTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Detective kills: %d", g_iPlayer[target].KilledDetectives);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Bad kills: %d", g_iPlayer[target].BadKills);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Identified Bodies: %d", g_iPlayer[target].IdenfifiedBodies);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Identified Traitors: %d", g_iPlayer[target].IdentifiedTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Scanned Bodies: %d", g_iPlayer[target].ScannedBodies);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Scanned Traitors: %d", g_iPlayer[target].ScannedTraitors);
    menu.AddItem(sBuffer, sBuffer);
    Format(sBuffer, sizeof(sBuffer), "Items bought: %d", g_iPlayer[target].BoughtItems);
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
    g_iPlayer[client].Ready = false;
    g_iPlayer[client].InRound = false;
}

public void OnClientPostAdminCheck(int client)
{
    if (!Stats_IsClientValid(client))
    {
        return;
    }

    if (!GetClientAuthId(client, AuthId_SteamID64, g_iPlayer[client].Auth, sizeof(PlayerData::Auth)))
    {
        LogError("[Stats] (OnClientPostAdminCheck) GetClientAuthId: Can't get the communityid for: \"%L\"", client);
        return;
    }

    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT rounds_played, rounds_won, played_as_innocent, played_as_traitor, played_as_detective, shots_fired, damage_taken, damage_given, bad_damage_taken, bad_damage_given, slayed_rounds, killed_innocents, killed_traitors, killed_detectives, bad_kills, identified_bodies, identified_traitors, scanned_bodies, scanned_traitors, bought_items FROM ttt_stats WHERE communityid = \"%s\";", g_iPlayer[client].Auth);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[Stats] (OnClientPostAdminCheck) - %s", sQuery);
    }

    g_dDB.Query(SQL_GetPlayerData, sQuery, GetClientUserId(client), DBPrio_High);
}

public void OnClientDisconnect(int client)
{
    UpdatePlayer(client);

    g_iPlayer[client].Ready = false;
    g_iPlayer[client].InRound = false;
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    LoopValidClients(i)
    {
    	if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR || TTT_GetClientRole(i) == TTT_TEAM_INNOCENT || TTT_GetClientRole(i) == TTT_TEAM_DETECTIVE)
    	{
        	g_iPlayer[i].InRound = true;
        }
    }
}

public int TTT_OnRoundSlay(int client, int remaining)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(client))
    {
        g_iPlayer[client].SlayedRounds++;
    }
}

public void TTT_OnItemPurchasePost(int client, int price, int count, const char[] itemshort)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(client))
    {
        g_iPlayer[client].BoughtItems++;
    }
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (!Stats_IsValidRound())
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
        
        g_iPlayer[client].ShotsFired++;
    }
}

public void TTT_OnTakeDamage(int victim, int attacker, float damage, int weapon, bool badAction)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(victim) && Stats_IsClientValid(attacker))
    {
        if (badAction)
        {
            g_iPlayer[attacker].BadDamageGiven += RoundToCeil(damage);
            g_iPlayer[victim].BadDamageTaken += RoundToCeil(damage);
        }
        else
        {
            g_iPlayer[attacker].DamageGiven += RoundToCeil(damage);
            g_iPlayer[victim].DamageTaken += RoundToCeil(damage);
        }
    }
}

public void TTT_OnClientDeath(int victim, int attacker, bool badAction)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(victim) && Stats_IsClientValid(attacker))
    {
        int iRole = TTT_GetClientRole(victim);

        if (iRole == TTT_TEAM_TRAITOR)
        {
            g_iPlayer[attacker].KilledTraitors++;
        }
        else if (iRole == TTT_TEAM_DETECTIVE)
        {
            g_iPlayer[attacker].KilledDetectives++;
        }
        else if (iRole == TTT_TEAM_INNOCENT)
        {
            g_iPlayer[attacker].KilledInnocents++;
        }

        if (badAction)
        {
            g_iPlayer[attacker].BadKills++;
        }
    }
}

public void TTT_OnBodyFound(int attacker, int victim, int entityref, bool silentID)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(attacker))
    {
        Ragdoll body;
        TTT_GetEntityRefRagdoll(entityref, body);

        if (body.VictimRole == TTT_TEAM_TRAITOR)
        {
            g_iPlayer[attacker].IdentifiedTraitors++;
        }
        else
        {
            g_iPlayer[attacker].IdenfifiedBodies++;
        }
    }
}

public Action TTT_OnBodyCheck(int attacker, int entityref)
{
    if (!Stats_IsValidRound())
    {
        return;
    }

    if (Stats_IsClientValid(attacker))
    {
        Ragdoll body;
        TTT_GetEntityRefRagdoll(entityref, body);

        if (body.VictimRole == TTT_TEAM_TRAITOR)
        {
            g_iPlayer[attacker].ScannedTraitors++;
        }
        else
        {
            g_iPlayer[attacker].ScannedBodies++;
        }
    }
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("TTT_OnRoundEnd");
    }

    if (!Stats_IsValidRound())
    {
        return;
    }

    LoopValidClients(i)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToChat(i, "InRound: %d", g_iPlayer[i].InRound);
        }

        if (g_iPlayer[i].InRound)
        {
            int iRole = TTT_GetClientRole(i);

            g_iPlayer[i].RoundsPlayed++;

            if  (iRole == winner || (iRole == TTT_TEAM_DETECTIVE && winner == TTT_TEAM_INNOCENT) || (iRole == TTT_TEAM_INNOCENT && winner == TTT_TEAM_DETECTIVE))
            {
                g_iPlayer[i].RoundsWon++;
            }

            if (iRole == TTT_TEAM_INNOCENT)
            {
                g_iPlayer[i].PlayedAsInnocent++;
            }
            if (iRole == TTT_TEAM_TRAITOR)
            {
                g_iPlayer[i].PlayedAsTraitor++;
            }
            if (iRole == TTT_TEAM_DETECTIVE)
            {
                g_iPlayer[i].PlayedAsDetective++;
            }
        }

        if (g_cDebug.BoolValue)
        {
            PrintToChat(i, "Played: %d, Won: %d", g_iPlayer[i].RoundsPlayed, g_iPlayer[i].RoundsWon);
        }

        g_iPlayer[i].InRound = false;

        UpdatePlayer(i);
    }
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
        LogMessage("SQL_GetPlayerData");
        int client = GetClientOfUserId(userid);

        if (Stats_IsClientValid(client))
        {
            if (results.RowCount > 0 && results.FetchRow())
            {
                g_iPlayer[client].RoundsPlayed = results.FetchInt(0);
                g_iPlayer[client].RoundsWon = results.FetchInt(1);
                g_iPlayer[client].PlayedAsInnocent = results.FetchInt(2);
                g_iPlayer[client].PlayedAsTraitor = results.FetchInt(3);
                g_iPlayer[client].PlayedAsDetective = results.FetchInt(4);
                g_iPlayer[client].ShotsFired = results.FetchInt(5);
                g_iPlayer[client].DamageTaken = results.FetchInt(6);
                g_iPlayer[client].DamageGiven = results.FetchInt(7);
                g_iPlayer[client].BadDamageTaken = results.FetchInt(8);
                g_iPlayer[client].BadDamageGiven = results.FetchInt(9);
                g_iPlayer[client].SlayedRounds = results.FetchInt(10);
                g_iPlayer[client].KilledInnocents = results.FetchInt(11);
                g_iPlayer[client].KilledTraitors = results.FetchInt(12);
                g_iPlayer[client].KilledDetectives = results.FetchInt(13);
                g_iPlayer[client].BadKills = results.FetchInt(14);
                g_iPlayer[client].IdenfifiedBodies = results.FetchInt(15);
                g_iPlayer[client].IdentifiedTraitors = results.FetchInt(16);
                g_iPlayer[client].ScannedBodies = results.FetchInt(17);
                g_iPlayer[client].ScannedTraitors = results.FetchInt(18);
                g_iPlayer[client].BoughtItems = results.FetchInt(19);

                g_iPlayer[client].Ready = true;
            }
            else
            {
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "INSERT INTO ttt_stats (communityid) VALUES (\"%s\");", g_iPlayer[client].Auth);

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

    if (strlen(g_iPlayer[client].Auth) < 2)
    {
        return;
    }

    char sQuery[1024];
    Format(sQuery, sizeof(sQuery), "UPDATE ttt_stats SET `rounds_played` = '%d', `rounds_won` = '%d', `played_as_innocent` = '%d', `played_as_traitor` = '%d', `played_as_detective` = '%d', `shots_fired` = '%d', `damage_taken` = '%d', `damage_given` = '%d', `bad_damage_taken` = '%d', `bad_damage_given` = '%d', `slayed_rounds` = '%d', `killed_innocents` = '%d', `killed_traitors` = '%d', `killed_detectives` = '%d', `bad_kills` = '%d', `identified_bodies` = '%d', `identified_traitors` = '%d', `scanned_bodies` = '%d', `scanned_traitors` = '%d', `bought_items` = '%d' WHERE communityid = \"%s\";",
    g_iPlayer[client].RoundsPlayed, g_iPlayer[client].RoundsWon, g_iPlayer[client].PlayedAsInnocent, g_iPlayer[client].PlayedAsTraitor, g_iPlayer[client].PlayedAsDetective, g_iPlayer[client].ShotsFired, g_iPlayer[client].DamageTaken, g_iPlayer[client].DamageGiven, g_iPlayer[client].BadDamageTaken, g_iPlayer[client].BadDamageGiven, g_iPlayer[client].SlayedRounds, g_iPlayer[client].KilledInnocents, g_iPlayer[client].KilledTraitors, g_iPlayer[client].KilledDetectives, g_iPlayer[client].BadKills, g_iPlayer[client].IdenfifiedBodies, g_iPlayer[client].IdentifiedTraitors, g_iPlayer[client].ScannedBodies, g_iPlayer[client].ScannedTraitors, g_iPlayer[client].BoughtItems, g_iPlayer[client].Auth);

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

bool Stats_IsValidRound()
{
    if (TTT_GetRoundStatus() == Round_Active && GetPlayerCount() >= g_cPlayers.IntValue)
    {
        return true;
    }

    return false;
}

bool Stats_IsClientValid(int client)
{
    if (TTT_IsClientValid(client) && !IsFakeClient(client))
    {
        return true;
    }
    
    return false;
}

int GetPlayerCount()
{
    int iCount = 0;

    for(int i = 1; i <= MaxClients; i++)
    {
        if (Stats_IsClientValid(i))
        {
            iCount++;
        }
    }

    return iCount;
}
