#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_detective_bans>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Detective Bans"

Database g_dDatabase = null;

GlobalForward g_fwOnModelUpdate = null;
GlobalForward g_fwOnDetectiveBan = null;
GlobalForward g_fwOnDetectiveUnBan = null;

ConVar g_cChangeTeams = null;
ConVar g_cRemoveShield = null;
ConVar g_cUpdateModel = null;
ConVar g_cUpdateRole = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH];

enum struct PlayerData
{
    int iBanID;
    int iUBanTime;
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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // TTT Core
    g_fwOnModelUpdate = new GlobalForward("TTT_OnModelUpdate", ET_Ignore, Param_Cell, Param_String);

    // Detective bans
    g_fwOnDetectiveBan = new GlobalForward("TTT_OnDetectiveBan", ET_Ignore, Param_Cell, Param_Cell, Param_String);
    g_fwOnDetectiveUnBan = new GlobalForward("TTT_OnDetectiveUnBan", ET_Ignore, Param_Cell);

    CreateNative("TTT_IsDetectiveBanned", Native_IsDetectiveBanned);
    CreateNative("TTT_AddDetectiveBan", Native_AddDetectiveBan);
    CreateNative("TTT_RemoveDetectiveBan", Native_RemoveDetectiveBan);

    RegPluginLibrary("ttt_detective_bans");

    return APLRes_Success;
}

public int Native_IsDetectiveBanned(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return TTT_IsClientValid(client) && g_iPlayer[client].iBanID > 0 && (g_iPlayer[client].iUBanTime == -1 || g_iPlayer[client].iUBanTime > GetTime());
}

public int Native_AddDetectiveBan(Handle plugin, int numParams)
{
    if (g_dDatabase != null)
    {
        int client = GetNativeCell(1);
        int target = GetNativeCell(2);
        int time = GetNativeCell(3);

        if (!TTT_IsClientValid(client) || IsFakeClient(client) || !TTT_IsClientValid(target) || IsFakeClient(target) || TTT_IsDetectiveBanned(client) || time < 0)
        {
            return 0;
        }

        char sQuery[1024], reason[256], reasondb[256];
        GetNativeString(2, reason, sizeof(reason));

        g_dDatabase.Escape(reason, reasondb, sizeof(reasondb));

        DataPack dPack = new DataPack();

        g_dDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO `ttt_detective_bans` (playerid, bantime, ubantime, banlength, banreason, adminid) VALUES ('%i', '%i', '%i', '%i', '%s', '%i')", TTT_GetPlayerID(target), GetTime(), GetTime() + time, time, reasondb, TTT_GetPlayerID(client));
        g_dDatabase.Query(SQL_InsertDetectiveBan, sQuery, dPack);

        dPack.WriteCell(GetClientUserId(client));
        dPack.WriteCell(GetClientUserId(target));
        dPack.WriteCell(time);
        dPack.WriteString(reason);
    }
    
    return 0;
}

public int Native_RemoveDetectiveBan(Handle plugin, int numParams)
{
    if (g_dDatabase != null)
    {
        int client = GetNativeCell(1);
        int target = GetNativeCell(2);

        if (!TTT_IsClientValid(client) || IsFakeClient(client) || !TTT_IsClientValid(target) || IsFakeClient(target) || !TTT_IsDetectiveBanned(client))
        {
            return 0;
        }

        char sQuery[1024];
        g_dDatabase.Format(sQuery, sizeof(sQuery), "UPDATE `ttt_detective_bans` SET `removeid` = %i, `removetype` = 'U' WHERE `id` = %i;", TTT_GetPlayerID(client), g_iPlayer[target].iBanID);
        g_dDatabase.Query(SQL_RemoveDetectiveBan, sQuery, GetClientUserId(target));
    }
    
    return 0;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();
    
    TTT_StartConfig("detective_bans");
    CreateConVar("detective_bans_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cChangeTeams = AutoExecConfig_CreateConVar("dbans_switch_teams", "1", "Should this plugin change player team after they get banned?", _, true, 0.0, true, 1.0);
    g_cRemoveShield = AutoExecConfig_CreateConVar("dbans_remove_shield", "1", "Should this plugin remove shield after the ban?", _, true, 0.0, true, 1.0);
    g_cUpdateModel = AutoExecConfig_CreateConVar("dbans_update_model", "1", "Should this plugin use global ttt update forward?", _, true, 0.0, true, 1.0);
    g_cUpdateRole = AutoExecConfig_CreateConVar("dbans_update_role", "1", "Should this plugin change player role after they've got banned?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    RegAdminCmd("sm_dban", Command_BanDetective, ADMFLAG_BAN, "sm_dban <#userid|name> <minutes|0> [reason]", "Bans player for playing in detectives team");
    RegAdminCmd("sm_udban", Command_UBanDetective, ADMFLAG_BAN, "sm_udban <#userid|name> <minutes|0> [reason]", "Unbans player for playing in detectives team");

    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void TTT_OnSQLConnect(Database db)
{
    g_dDatabase = db;

    if (g_dDatabase == null)
    {
        SetFailState("Database handle is invalid");
        return;
    }

    char sQuery[1024];
    g_dDatabase.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `ttt_detective_bans` (`id` int(10) UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT, `playerid` int(11) NOT NULL, `bantime` int(10) UNSIGNED NOT NULL DEFAULT 0, `ubantime` int(10) UNSIGNED NOT NULL DEFAULT 0, `banlength` int(10) UNSIGNED NOT NULL DEFAULT 0, `banreason` varchar(255) NOT NULL, `adminid` int(11) NOT NULL, `removeid` int(11) NULL, `removetype` enum('E', 'U') NOT NULL DEFAULT 'E', FOREIGN KEY (`playerid`) REFERENCES `ttt` (`id`), FOREIGN KEY (`adminid`) REFERENCES `ttt` (`id`), FOREIGN KEY (`removeid`) REFERENCES `ttt` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    g_dDatabase.Query(SQL_CreateDetectiveBanTable, sQuery);
}

public void SQL_CreateDetectiveBanTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CreateDetectiveBanTable) Query failed: %s", error);
        return;
    }
}

public void OnClientPutInServer(int client)
{
    if (!TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    ClearClientData(client);
    
    CreateTimer(2.5, Timer_OnClientPutInServer, GetClientUserId(client));
}

public Action Timer_OnClientPutInServer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        char sCommunityID[64];

        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return Plugin_Handled;
        }

        if (g_dDatabase != null)
        {
            char sQuery[1024];
            g_dDatabase.Format(sQuery, sizeof(sQuery), "SELECT `id`, `bantime`, `ubantime` FROM `ttt_detective_bans` WHERE `playerid` = %i AND (`banlength` = 0 OR `ubantime` > %i) AND `removetype` = 'E';", TTT_GetPlayerID(client), GetTime());
            g_dDatabase.Query(SQL_OnClientPutInServer, sQuery, userid);
        }
    }
    
    return Plugin_Handled;
}

public void SQL_OnClientPutInServer(Database db, DBResultSet results, const char[] error, any userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_OnClientPutInServer) Query failed: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (results.RowCount > 0 && results.FetchRow())
    {
        char sCommunityID[64];

        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return;
        }

        g_iPlayer[client].iBanID = results.FetchInt(0);
        g_iPlayer[client].iUBanTime = results.FetchInt(1) == results.FetchInt(2) ? -1 : results.FetchInt(1);
    }
}

public Action TTT_OnRoundStart_Pre()
{
    LoopValidClients(i)
    {
        if (!TTT_IsDetectiveBanned(i))
        {
            continue;
        }

        g_iPlayer[i].iBanID = 0;
        g_iPlayer[i].iUBanTime = 0;
    }
    
    return Plugin_Continue;
}

public Action Command_BanDetective(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_dban <#userid|name> <minutes|0> [reason]");
        return Plugin_Handled;
    }

    char sBuffer[256];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));

    int iTarget = FindTarget(client, sBuffer, true);

    if (!TTT_IsClientValid(iTarget))
    {
        ReplyToCommand(client, "[SM] That player cannot be found!");
        return Plugin_Handled;
    }

    if (TTT_IsDetectiveBanned(iTarget))
    {
        ReplyToCommand(client, "[SM] That player already have a detective ban!");
        return Plugin_Handled;
    }

    GetCmdArg(2, sBuffer, sizeof(sBuffer));

    int iTime = StringToInt(sBuffer) * 60;

    if (iTime < 0)
    {
        ReplyToCommand(client, "[SM] You cant ban player for negative time!");
        return Plugin_Handled;
    }

    char sQuery[1024], sReason[256], sReasonDB[256];

    if (args >= 3)
    {
        for (int i = 3; i <= args; i++)
        {
            GetCmdArg(i, sBuffer, sizeof(sBuffer));
            Format(sReason, sizeof(sReason), "%s %s", sReason, sBuffer);
        }
    }

    if (strlen(sReason) <= 1)
    {
        Format(sReason, sizeof(sReason), "%T", "Detective bans: Empty reason", iTarget);
    }

    if (g_dDatabase == null)
    {
        ReplyToCommand(client, "[SM] Database connection is null!");
        return Plugin_Handled;
    }

    g_dDatabase.Escape(sReason, sReasonDB, sizeof(sReasonDB));

    DataPack dPack = new DataPack();

    g_dDatabase.Format(sQuery, sizeof(sQuery), "INSERT INTO `ttt_detective_bans` (playerid, bantime, ubantime, banlength, banreason, adminid) VALUES ('%i', '%i', '%i', '%i', '%s', '%i')", TTT_GetPlayerID(iTarget), GetTime(), GetTime() + iTime, iTime, sReasonDB, TTT_GetPlayerID(client));
    g_dDatabase.Query(SQL_InsertDetectiveBan, sQuery, dPack);

    dPack.WriteCell(GetClientUserId(client));
    dPack.WriteCell(GetClientUserId(iTarget));
    dPack.WriteCell(iTime);
    dPack.WriteString(sReason);
    return Plugin_Handled;
}

public void SQL_InsertDetectiveBan(Database db, DBResultSet results, const char[] error, any pack) 
{
    view_as<DataPack>(pack).Reset();

    int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());
    int iTarget = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());
    int iTime = view_as<DataPack>(pack).ReadCell();

    char sReason[256];
    view_as<DataPack>(pack).ReadString(sReason, sizeof(sReason));

    delete view_as<DataPack>(pack);

    if (results == null || strlen(error) > 0)
    {
        SetFailState("(SQL_InsertDetectiveBan) Query failed: %s", error);
        return;
    }

    if (!TTT_IsClientValid(client) || IsFakeClient(client) || !TTT_IsClientValid(iTarget) || IsFakeClient(iTarget))
    {
        return;
    }

    g_iPlayer[iTarget].iBanID = results.InsertId;
    g_iPlayer[iTarget].iUBanTime = iTime == 0 ? -1 : GetTime() + iTime;

    if (g_cChangeTeams.BoolValue)
    {
        CS_SwitchTeam(iTarget, CS_TEAM_T);
    }

    if (g_cUpdateRole.BoolValue && TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
    {
        TTT_SetClientRole(iTarget, TTT_TEAM_INNOCENT);
    }

    if (g_cRemoveShield.BoolValue)
    {
        int iShield = TTT_HasClientWeapon(client, "weapon_shield");

        if (iShield != -1)
        {
            RemovePlayerItem(client, iShield);
            RemoveEdict(iShield);
        }
    }

    if (g_cUpdateModel.BoolValue)
    {
        char sModel[PLATFORM_MAX_PATH + 1];
        GetClientModel(iTarget, sModel, sizeof(sModel));

        CS_UpdateClientModel(iTarget);

        Call_StartForward(g_fwOnModelUpdate);
        Call_PushCell(iTarget);
        Call_PushString(sModel);
        Call_Finish();
    }

    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(iTarget, sName, sizeof(sName));

    LoopValidClients(i)
    {
        CPrintToChat(i, "%s %T", g_sPluginTag, "Detective bans: Banned", i, sName, sReason);
    }

    Call_StartForward(g_fwOnDetectiveBan);
    Call_PushCell(iTarget);
    Call_PushCell(iTime);
    Call_PushString(sReason);
    Call_Finish();
}

public Action Command_UBanDetective(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_udban <#userid|name>");
        return Plugin_Handled;
    }

    char sBuffer[256];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));

    int iTarget = FindTarget(client, sBuffer, true);

    if (!TTT_IsClientValid(iTarget))
    {
        ReplyToCommand(client, "[SM] That player cannot be found!");
        return Plugin_Handled;
    }

    if (!TTT_IsDetectiveBanned(iTarget))
    {
        ReplyToCommand(client, "[SM] That player do not have a detective ban!");
        return Plugin_Handled;
    }

    if (g_dDatabase == null)
    {
        ReplyToCommand(client, "[SM] Database connection is null!");
        return Plugin_Handled;
    }

    char sQuery[1024];
    g_dDatabase.Format(sQuery, sizeof(sQuery), "UPDATE `ttt_detective_bans` SET `removeid` = %i, `removetype` = 'U' WHERE `id` = %i;", TTT_GetPlayerID(client), g_iPlayer[iTarget].iBanID);
    g_dDatabase.Query(SQL_RemoveDetectiveBan, sQuery, GetClientUserId(iTarget));
    return Plugin_Handled;
}

public void SQL_RemoveDetectiveBan(Database db, DBResultSet results, const char[] error, any userid)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_RemoveDetectiveBan) Query failed: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sName, sizeof(sName));

    LoopValidClients(i)
    {
        CPrintToChat(i, "%s %T", g_sPluginTag, "Detective bans: Unbanned", i, sName);
    }

    ClearClientData(client);

    Call_StartForward(g_fwOnDetectiveUnBan);
    Call_PushCell(client);
    Call_Finish();
}

void ClearClientData(int client)
{
    g_iPlayer[client].iBanID = 0;
    g_iPlayer[client].iUBanTime = 0;
}
