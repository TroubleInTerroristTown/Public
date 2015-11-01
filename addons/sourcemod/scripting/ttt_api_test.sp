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
