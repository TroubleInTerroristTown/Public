#pragma semicolon 1

#include <sourcemod>
#include <ttt>
#include <ttt_sql>
#include <ttt_shop>

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

	HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnAllPluginsLoaded()
{
	if (TTT_IsLoaded())
	{
		TTT_RegisterCustomItem(PLUGIN_ITEM_SHORT, PLUGIN_ITEM_LONG, PLUGIN_ITEM_PRICE);
	}
}

public Action TTT_OnItemPurchase(int client, int &price, bool &count, const char[] item)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client) && strlen(item) > 2)
	{
		PrintToChat(client, "[TTT_OnItemPurchase] It works! Hooray! Item: %s Price: %d Count: %d", item, price, count);
	}

	return Plugin_Continue;
}

public Action TTT_OnItemPurchased(int client, const char[] item, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client) && strlen(item) > 2)
	{
		PrintToChat(client, "[TTT_OnItemPurchased] It works! Hooray! Item: %s Count: %d", item, count);
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

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
	PrintToServer("TTT_OnRoundStart was called!");
	PrintToServer("(TTT_OnRoundStart) innocents: %d - traitors: %d - detective: %d", innocents, traitors, detective);
}

public void TTT_OnRoundStartFailed(int players, int requiredPlayers, int detective)
{
	PrintToServer("TTT_OnRoundStartFailed was called!");
	PrintToServer("(TTT_OnRoundStartFailed) players: %d - requiredPlayers: %d - detective: %d", players, requiredPlayers, detective);
}

public void TTT_OnClientGetRole(int client, int role)
{
	PrintToServer("TTT_OnClientGetRole was called!");
	PrintToServer("(TTT_OnClientGetRole) client: %d - role: %d", client, role);
}

public void TTT_OnClientDeath(int victim, int attacker)
{
	PrintToServer("TTT_OnClientDeath was called!");
	PrintToServer("(TTT_OnClientDeath) victim: %d - attacker: %d", victim, attacker);
}

public void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer)
{
	PrintToServer("TTT_OnBodyFound was called!");
	PrintToServer("(TTT_OnBodyFound) client: %d - victim: %d - deadPlayer: %s", client, victim, deadPlayer);
}

public void TTT_OnBodyScanned(int client, int victim, const char[] deadPlayer)
{
	PrintToServer("TTT_OnBodyScanned was called!");
	PrintToServer("(TTT_OnBodyScanned) client: %d - victim: %d - deadPlayer: %s", client, victim, deadPlayer);
}

public void TTT_OnSQLConnect(Database db)
{
	PrintToServer("TTT_OnSQLConnect was called!");
	PrintToServer("(TTT_OnSQLConnect) db: %d", db);

	Database dDB = TTT_GetSQLConnection();
	PrintToServer("(TTT_OnSQLConnect) dDB: %d", dDB);

	if (dDB == db)
	{
		PrintToServer("(TTT_OnSQLConnect) db and dDB are equal!", db);
	}
}
