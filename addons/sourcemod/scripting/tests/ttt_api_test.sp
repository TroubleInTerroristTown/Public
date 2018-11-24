#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_sql>
#include <ttt_shop>
#include <ttt_grabbermod>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - API Test"

#define PLUGIN_ITEM_SHORT "testitem"
#define PLUGIN_ITEM_LONG  "Test Item"
#define PLUGIN_ITEM_PRICE 350

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    
    CreateConVar("ttt2_api_test_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);

    HookEvent("weapon_fire", Event_WeaponFire);
    
    RegAdminCmd("sm_uitem", Command_UItem, ADMFLAG_ROOT);
    RegAdminCmd("sm_trole", Command_TRole, ADMFLAG_ROOT);
    RegAdminCmd("sm_endround", Command_EndRound, ADMFLAG_ROOT);
}

public void TTT_OnLatestVersion(const char[] version)
{
    LogMessage("TTT_OnLatestVersion was called!");
    LogMessage("(TTT_OnLatestVersion) version: %s", version);
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public Action Command_TRole(int client, int args)
{
    int iRole = TTT_GetClientRole(client);
    char sRole[ROLE_LENGTH], sShort[ROLE_LENGTH];

    TTT_GetRoleNameByID(iRole, sRole, sizeof(sRole));
    TTT_GetShortRoleNameByID(iRole, sShort, sizeof(sShort));
    PrintToChat(client, "(1) Player: %N - RoleID: %d - RoleName: %s - RoleShort: %s", client, iRole, sRole, sShort);
    TTT_GetRoleNameByShortName(sShort, sRole, sizeof(sRole));
    PrintToChat(client, "(2) Player: %N - RoleID: %d - RoleName: %s - RoleShort: %s", client, iRole, sRole, sShort);
    iRole = TTT_GetRoleIDByName(sRole);
    PrintToChat(client, "(3) Player: %N - RoleID: %d - RoleName: %s - RoleShort: %s", client, iRole, sRole, sShort);
    iRole = TTT_GetRoleIDByShortName(sShort);
    PrintToChat(client, "(4) Player: %N - RoleID: %d - RoleName: %s - RoleShort: %s", client, iRole, sRole, sShort);
    TTT_GetShortRoleNameByName(sRole, sShort, sizeof(sShort));
    PrintToChat(client, "(5) Player: %N - RoleID: %d - RoleName: %s - RoleShort: %s", client, iRole, sRole, sShort);
}

public Action Command_EndRound(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_endround <delay in seconds>");
        return Plugin_Handled;
    }

    char sArg[12];
    GetCmdArg(1, sArg, sizeof(sArg));

    CS_TerminateRound(StringToFloat(sArg), CSRoundEnd_Draw, true);

    return Plugin_Handled;
}

public Action Command_UItem(int client, int args)
{
    if (args != 2)
    {
        ReplyToCommand(client, "sm_uitem <item name (short)> <price>");
        return Plugin_Handled;
    }
    
    char arg1[MAX_NAME_LENGTH], arg2[5];
    
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));
    
    TTT_UpdateCustomItem(arg1, StringToInt(arg2));
    
    return Plugin_Continue;
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

void RegisterItem()
{
    TTT_RegisterCustomItem(PLUGIN_ITEM_SHORT, PLUGIN_ITEM_LONG, PLUGIN_ITEM_PRICE);
}

public Action TTT_OnItemPurchase(int client, int &price, bool &count, const char[] item)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client) && strlen(item) > 2)
    {
        PrintToChat(client, "[TTT_OnItemPurchase] It works! Hooray! Item: %s Price: %d Count: %d", item, price, count);
    }

    return Plugin_Continue;
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client) && strlen(itemshort) > 2)
    {
        PrintToChat(client, "[TTT_OnItemPurchased] It works! Hooray! Item: %s Count: %d Price: %d", itemshort, count, price);
    }

    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        PrintToChat(client, "Player: %N, Karma %d, Credits: %d", client, TTT_GetClientKarma(client), TTT_GetClientCredits(client));
    }
}

public Action TTT_OnRoundStart_Pre()
{
    LogMessage("TTT_OnRoundStart_Pre was called!");
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    LogMessage("TTT_OnRoundStart was called!");
    LogMessage("(TTT_OnRoundStart) innocents: %d - traitors: %d - detective: %d", innocents, traitors, detective);
}

public void TTT_OnRoundStartFailed(int players, int requiredPlayers, int detective)
{
    LogMessage("TTT_OnRoundStartFailed was called!");
    LogMessage("(TTT_OnRoundStartFailed) players: %d - requiredPlayers: %d - detective: %d", players, requiredPlayers, detective);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    LogMessage("TTT_OnRoundEnd was called!");
    LogMessage("(TTT_OnRoundEnd) winner: %d - array: %d", winner, array);
}

public void TTT_OnClientGetRole(int client, int role)
{
    LogMessage("TTT_OnClientGetRole was called!");
    LogMessage("(TTT_OnClientGetRole) client: %d - role: %d", client, role);
}

public void TTT_OnTakeDamage(int victim, int attacker, float damage, int weapon, bool badAction)
{
    LogMessage("TTT_OnTakeDamage was called!");
    LogMessage("(TTT_OnTakeDamage) victim: %d - attacker: %d, damage: %f, weapon: %d, badAction: %d", victim, attacker, damage, weapon, badAction);
}

public void TTT_OnClientDeath(int victim, int attacker)
{
    LogMessage("TTT_OnClientDeath was called!");
    LogMessage("(TTT_OnClientDeath) victim: %d - attacker: %d", victim, attacker);
}

public Action TTT_OnClientDeathPre(int victim, int attacker)
{
    LogMessage("TTT_OnClientDeathPre was called!");
    LogMessage("(TTT_OnClientDeathPre) victim: %d - attacker: %d", victim, attacker);
}

public void TTT_OnBodyFound(int client, int victim, int[] ragdoll, bool silent)
{
    LogMessage("TTT_OnBodyFound was called!");
    LogMessage("(TTT_OnBodyFound) client: %d - victim: %d - ragdoll: %d - silent: %b", client, victim, ragdoll, silent);
}

public Action TTT_OnRulesMenu(int client, bool &show)
{
    LogMessage("TTT_OnRulesMenu was called!");
    LogMessage("(TTT_OnRulesMenu) client: %d, show: %d", client, show);
}

public Action TTT_OnDetectiveMenu(int client, bool &show)
{
    LogMessage("TTT_OnDetectiveMenu was called!");
    LogMessage("(TTT_OnDetectiveMenu) client: %d, show: %d", client, show);
}

public Action TTT_OnBodyCheck(int client, int[] ragdoll)
{
    LogMessage("TTT_OnBodyCheck was called!");
    LogMessage("(TTT_OnBodyCheck) client: %d, ragdoll: %d", client, ragdoll);
}

public void TTT_OnModelUpdate(int client, const char[] model)
{
    LogMessage("TTT_OnModelUpdate was called!");
    LogMessage("(TTT_OnModelUpdate) client: %d, model: %s", client, model);
}

public void TTT_OnPlayerRespawn(int client)
{
    LogMessage("TTT_OnPlayerRespawn was called!");
    LogMessage("(TTT_OnPlayerRespawn) client: %d", client);
}

public int TTT_OnButtonPress(int client, int button)
{
    LogMessage("TTT_OnButtonPress was called!");
    LogMessage("(TTT_OnButtonPress) client: %d, button: %s", client, button);
}

public int TTT_OnButtonRelease(int client, int button)
{
    LogMessage("TTT_OnButtonRelease was called!");
    LogMessage("(TTT_OnButtonRelease) client: %d, button: %s", client, button);
}

public void TTT_OnBodyScanned(int client, int victim, const char[] deadPlayer)
{
    LogMessage("TTT_OnBodyScanned was called!");
    LogMessage("(TTT_OnBodyScanned) client: %d - victim: %d - deadPlayer: %s", client, victim, deadPlayer);
}

public Action TTT_OnPlayerDeath(int victim, int attacker)
{
    LogMessage("TTT_OnPlayerDeath was called!");
    LogMessage("(TTT_OnPlayerDeath) victim: %d - attacker: %d", victim, attacker);
}

public void TTT_OnKarmaUpdate(int client, KarmaUpdate type, int karma)
{
    LogMessage("TTT_OnKarmaUpdate was called!");
    LogMessage("(TTT_OnKarmaUpdate) client: %d - type: %d - karma: %d", client, type, karma);
}

public bool TTT_OnCheckCommandAccess(int client, const char[] command, const char[] flags, bool access)
{
    LogMessage("TTT_OnCheckCommandAccess was called!");
    LogMessage("(TTT_OnCheckCommandAccess) client: %d - command: %s - flags: %d - access", client, command, flags, access);
}

public void TTT_OnSQLConnect(Database db)
{
    LogMessage("TTT_OnSQLConnect was called!");
    LogMessage("(TTT_OnSQLConnect) db: %d", db);

    Database dDB = TTT_GetSQLConnection();
    LogMessage("(TTT_OnSQLConnect) dDB: %d", dDB);

    if (dDB == db)
    {
        LogMessage("(TTT_OnSQLConnect) db and dDB are equal!", db);
    }
}

public Action TTT_OnGrabbing(int client, int entity)
{
    LogMessage("TTT_OnGrabbing was called!");
    LogMessage("(TTT_OnGrabbing) Client: %N - Entity: %d", client, entity);
}
