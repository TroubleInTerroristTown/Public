#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "taser"
#define SHORT_NAME_D "taser_d"
#define LONG_NAME "Taser"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Taser"

int g_iDPrice = 0;
int g_iIPrice = 0;

int g_iDCount = 0;
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iICount = 0;
int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iDamage = 0;
int g_iCreditsTaserHurtTraitor;

bool g_bOnSpawn = false;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

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
	g_iCreditsTaserHurtTraitor = Config_LoadInt("ttt_hurt_traitor_with_taser", 2000, "The amount of credits an innocent or detective will recieve for discovering a traitor with their zues/taser.");
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/taser.cfg");
	Config_Setup("TTT-Taser", g_sConfigFile);
	
	g_iDPrice = Config_LoadInt("ta_detective_price", 9000, "The amount of credits a taser costs as detective. 0 to disable.");
	g_iIPrice = Config_LoadInt("ta_innocent_price", 9000, "The amount of credits a taser costs as innocent. 0 to disable.");
	
	g_iDCount = Config_LoadInt("ta_detective_count", 1, "The amount of usages for tasers per round as detective. 0 to disable.");
	g_iICount = Config_LoadInt("ta_innocent_count", 1, "The amount of usages for tasers per round as innocent. 0 to disable.");
	
	g_iDamage = Config_LoadInt("ta_damage", 0, "The amount of damage a taser deals");
	
	g_bOnSpawn = Config_LoadBool("ta_give_taser_spawn", true, "Give the Detective a taser when he spawns?");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetTaser(client);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void TTT_OnClientGetRole(int client, int role)
{
	if(role == TTT_TEAM_DETECTIVE && g_bOnSpawn)
	{
		GivePlayerItem(client, "weapon_taser");
		g_iDPCount[client]++;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
		ResetTaser(client);
}

public void OnAllPluginsLoaded()
{
	if(g_iDPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME_D, LONG_NAME, g_iDPrice, TTT_TEAM_DETECTIVE);
	if(g_iIPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iIPrice, TTT_TEAM_INNOCENT);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_D, false))
		{
			int role = TTT_GetClientRole(client);
			
			if(role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_iDCount)
			{
				CPrintToChat(iAttacker, g_sPluginTag, "TaserMax", g_iDCount);
				return Plugin_Stop;
			}
			else if(role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_iICount)
			{
				CPrintToChat(iAttacker, g_sPluginTag, "TaserMax", g_iICount);
				return Plugin_Stop;
			}
				
			GivePlayerItem(client, "weapon_taser");
			
			if(role == TTT_TEAM_DETECTIVE)
				g_iDPCount[client]++;
			else if(role == TTT_TEAM_INNOCENT)
				g_iIPCount[client]++;
		}
	}
	return Plugin_Continue;
}

void ResetTaser(int client)
{
	g_iDPCount[client] = 0;
	g_iIPCount[client] = 0;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!TTT_IsRoundActive())
		return Plugin_Continue;
	
	if (IsWorldDamage(iAttacker, damagetype))
		return Plugin_Continue;
	
	if (!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
		return Plugin_Continue;
	
	char item[512], sWeapon[64];
	GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
	if (StrEqual(sWeapon, "weapon_taser", false))
	{
		if (TTT_GetClientRole(iVictim) == TTT_TEAM_TRAITOR)
		{
			Format(item, sizeof(item), "-> [%N (Traitor) was tased by %N] - TRAITOR DETECTED", iVictim, iAttacker, iVictim);
			TTT_LogString(item);
			CPrintToChat(iAttacker, g_sPluginTag, "You hurt a Traitor", iVictim, iVictim);
			TTT_SetClientCredits(iAttacker, TTT_GetClientCredits(iAttacker) + g_iCreditsTaserHurtTraitor);
		}
		else if (TTT_GetClientRole(iVictim) == TTT_TEAM_DETECTIVE)
		{
			Format(item, sizeof(item), "-> [%N (Detective) was tased by %N]", iVictim, iAttacker, iVictim);
			TTT_LogString(item);
			CPrintToChat(iAttacker,  g_sPluginTag, "You hurt a Detective", iVictim, iVictim);
		}
		else if (TTT_GetClientRole(iVictim) == TTT_TEAM_INNOCENT)
		{
			Format(item, sizeof(item), "-> [%N (Innocent) was tased by %N]", iVictim, iAttacker, iVictim);
			TTT_LogString(item);
			CPrintToChat(iAttacker,  g_sPluginTag, "You hurt an Innocent", iVictim, iVictim);
		}
		
		if (g_iDamage == 0)
			return Plugin_Handled;
		else if (g_iDamage > 0)
		{
			damage = view_as<float>(g_iDamage);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}