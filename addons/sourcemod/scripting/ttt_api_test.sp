#pragma semicolon 1

#include <sourcemod>
#include <ttt>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "TTT API Test",
	author = "Bara",
	description = "",
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
		PrintToChat(client, "Player: %N, Karma %d, Credits: %d", client, TTT_GetClientKarma(client), TTT_GetClientCredits(client));
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
	PrintToServer("(TTT_OnClientDeath) client: %d - victim: %d - deadPlayer: %s", client, victim, deadPlayer);
}

public void TTT_OnBodyScanned(int client, int victim, const char[] deadPlayer)
{
	PrintToServer("TTT_OnBodyScanned was called!");
	PrintToServer("(TTT_OnClientDeath) client: %d - victim: %d - deadPlayer: %s", client, victim, deadPlayer);
}
