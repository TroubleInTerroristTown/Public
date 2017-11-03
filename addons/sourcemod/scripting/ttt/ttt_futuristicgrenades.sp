#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <config_loader>
#include <futuristicgrenades>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Futuristic Grenades"

// All grenades
#define SHORT_NAME_FI "futuristic_grenade_i"
#define SHORT_NAME_FT "futuristic_grenade_t"
#define SHORT_NAME_FD "futuristic_grenade_d"
bool g_bOneTime = true;
bool g_bGiveDecoy = true;
int g_iPriceFI = 0;
int g_iPriceFT = 0;
int g_iPriceFD = 0;
int g_iPrioFI = 0;
int g_iPrioFT = 0;
int g_iPrioFD = 0;

bool g_bFuturistic[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

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

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/futuristicgrenades.cfg");
	Config_Setup("TTT-FuturisticGrenades", g_sConfigFile);
	
	// All grenades
	Config_LoadString("futuristic_name", "Futuristic Grenades", "The name of this in Shop", g_sLongName, sizeof(g_sLongName));
	g_bOneTime = Config_LoadBool("futuristic_one_time", true, "Effect for just one grenade?");
	g_bGiveDecoy = Config_LoadBool("futuristic_give_decoy", true, "Give decoy on purchase?");
	g_iPriceFI = Config_LoadInt("futuristic_price_innocent", 20000, "The amount of credits futuristic grenades costs as innocent. 0 to disable.");
	g_iPriceFT = Config_LoadInt("futuristic_price_traitor", 20000, "The amount of credits futuristic grenades costs as traitor. 0 to disable.");
	g_iPriceFD = Config_LoadInt("futuristic_price_detective", 20000, "The amount of credits futuristic grenades costs as detective. 0 to disable.");
	g_iPrioFI = Config_LoadInt("futuristic_sort_prio_innocent", 0, "The sorting priority of the futuristic grenades in the shop menu for innocents.");
	g_iPrioFT = Config_LoadInt("futuristic_sort_prio_traitor", 0, "The sorting priority of the futuristic grenades in the shop menu for traitors.");
	g_iPrioFD = Config_LoadInt("futuristic_sort_prio_detective", 0, "The sorting priority of the futuristic grenades in the shop menu for detectives.");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnAllPluginsLoaded()
{
	char sFile[] = "futuristicgrenades.smx";
	Handle hPlugin = FindPluginByFile(sFile);
	
	if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
	{
		SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?p=2499362", sFile);
		return;
	}
	
	// All grenades
	TTT_RegisterCustomItem(SHORT_NAME_FI, g_sLongName, g_iPriceFI, TTT_TEAM_INNOCENT, g_iPrioFI);
	TTT_RegisterCustomItem(SHORT_NAME_FT, g_sLongName, g_iPriceFT, TTT_TEAM_TRAITOR, g_iPrioFT);
	TTT_RegisterCustomItem(SHORT_NAME_FD, g_sLongName, g_iPriceFD, TTT_TEAM_DETECTIVE, g_iPrioFD);
}

public void OnClientDisconnect(int client)
{
	ResetFuturistic(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetFuturistic(client);
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		int role = TTT_GetClientRole(client);
		
		// All grenades
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, SHORT_NAME_FI, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, SHORT_NAME_FT, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, SHORT_NAME_FD, false)))
		{
			g_bFuturistic[client] = true;
			
			if (g_bGiveDecoy)
			{
				GivePlayerItem(client, "weapon_decoy");
			}
		}
	}
	return Plugin_Continue;
}

public Action FGrenades_OnSwitchMode(int client, DecoyMode previousmode, DecoyMode &newmode, int weapon)
{
	if (g_bFuturistic[client])
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

public void FGrenades_OnGrenadeStart(int owner, int &particle, float pos[3], DecoyMode mode, int duration)
{
	if (g_bOneTime && g_bFuturistic[owner])
	{
		g_bFuturistic[owner] = false;
	}
}

void ResetFuturistic(int client)
{
	g_bFuturistic[client] = false;
}
