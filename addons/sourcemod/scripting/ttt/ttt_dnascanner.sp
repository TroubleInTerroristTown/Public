#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>
#include <ttt_shop>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Overlays"
#define SHORT_NAME "dna"
#define LONG_NAME "DNA - Scanner"

int g_iPrice = 0;

bool g_bHasScanner[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

enum Ragdolls
{
	ent, 
	victim, 
	attacker, 
	String:victimName[MAX_NAME_LENGTH], 
	String:attackerName[MAX_NAME_LENGTH], 
	bool:scanned, 
	Float:gameTime, 
	String:weaponused[32], 
	bool:found
}

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
	
	LoadTranslations("ttt.phrases");
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/dnascanner.cfg");
	Config_Setup("TTT-Scanner", g_sConfigFile);
	
	g_iPrice = Config_LoadInt("dna_price", 9000, "The amount of credits a dna scanner costs as detective. 0 to disable.");
}

public void OnClientDisconnect(int client)
{
	ResetScanner(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
		ResetScanner(client);
}

public void OnAllPluginsLoaded()
{
	if(g_iPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iPrice, TTT_TEAM_DETECTIVE);
}

void ResetScanner(int client)
{
	g_bHasScanner[client] = false;
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if(role != TTT_TEAM_DETECTIVE)
				return Plugin_Stop;
			
			g_bHasScanner[client] = true;
		}
	}
	return Plugin_Continue;
}

public void TTT_OnBodyChecked(int client, int Victim, const char[] deadPlayer)
{
	if(!TTT_IsClientValid(client))
		return;
	
	if(TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE || g_bHasScanner[client] == false)
		return;
	int Items[Ragdolls];
	TTT_GetClientRagdoll(Victim, Items[0]);
	if (Items[attacker] > 0 && Items[attacker] != Items[victim])
	{
		LoopValidClients(j)
			CPrintToChat(j, g_sPluginTag, "Detective scan found body", j, client, Items[attackerName], Items[weaponused]);
	}
	else
	{
		LoopValidClients(j)
			CPrintToChat(j, g_sPluginTag, "Detective scan found body suicide", j, client);
	}
	TTT_SetFoundStatus(client, true);
	
}