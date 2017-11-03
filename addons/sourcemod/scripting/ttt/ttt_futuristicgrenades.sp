#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <config_loader>
#include <futuristicgrenades>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Futuristic Grenades"

// General
bool g_bOneTime = true;
bool g_bGiveDecoy = true;

char g_sConfigFile[PLATFORM_MAX_PATH] = "";

// All grenades
#define FUTURISTIC_I "futuristic_i"
#define FUTURISTIC_T "futuristic_t"
#define FUTURISTIC_D "futuristic_d"
char g_sLongNameF[64];
int g_iPriceFI = 0;
int g_iPriceFT = 0;
int g_iPriceFD = 0;
int g_iPrioFI = 0;
int g_iPrioFT = 0;
int g_iPrioFD = 0;
bool g_bFuturistic[MAXPLAYERS + 1] =  { false, ... };

// Blackhole
#define BH_SNAME_I "blackhole_i"
#define BH_SNAME_T "blackhole_t"
#define BH_SNAME_D "blackhole_d"
char g_sLongNameBH[64];
int g_iPriceBHI = 0;
int g_iPriceBHT = 0;
int g_iPriceBHD = 0;
int g_iPrioBHI = 0;
int g_iPrioBHT = 0;
int g_iPrioBHD = 0;

// Forcefield
#define FF_SNAME_I "forcefield_i"
#define FF_SNAME_T "forcefield_t"
#define FF_SNAME_D "forcefield_d"
char g_sLongNameFF[64];
int g_iPriceFFI = 0;
int g_iPriceFFT = 0;
int g_iPriceFFD = 0;
int g_iPrioFFI = 0;
int g_iPrioFFT = 0;
int g_iPrioFFD = 0;

// Explosion
#define FE_SNAME_I "explosion_i"
#define FE_SNAME_T "explosion_t"
#define FE_SNAME_D "explosion_d"
char g_sLongNameFE[64];
int g_iPriceFEI = 0;
int g_iPriceFET = 0;
int g_iPriceFED = 0;
int g_iPrioFEI = 0;
int g_iPrioFET = 0;
int g_iPrioFED = 0;

// Implosion
#define FI_SNAME_I "implosion_i"
#define FI_SNAME_T "implosion_t"
#define FI_SNAME_D "implosion_d"
char g_sLongNameFI[64];
int g_iPriceFII = 0;
int g_iPriceFIT = 0;
int g_iPriceFID = 0;
int g_iPrioFII = 0;
int g_iPrioFIT = 0;
int g_iPrioFID = 0;

DecoyMode g_iGMode[MAXPLAYERS + 1] =  { DecoyMode_Normal, ... };

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
	
	g_bOneTime = Config_LoadBool("futuristic_one_time", true, "Effect for just one grenade?");
	g_bGiveDecoy = Config_LoadBool("futuristic_give_decoy", true, "Give decoy on purchase?");
	
	// All grenades
	Config_LoadString("futuristic_name", "Futuristic Grenades", "The name of this in Shop", g_sLongNameF, sizeof(g_sLongNameF));
	g_iPriceFI = Config_LoadInt("futuristic_price_innocent", 20000, "The amount of credits futuristic grenades costs as innocent. 0 to disable.");
	g_iPriceFT = Config_LoadInt("futuristic_price_traitor", 20000, "The amount of credits futuristic grenades costs as traitor. 0 to disable.");
	g_iPriceFD = Config_LoadInt("futuristic_price_detective", 20000, "The amount of credits futuristic grenades costs as detective. 0 to disable.");
	g_iPrioFI = Config_LoadInt("futuristic_sort_prio_innocent", 0, "The sorting priority of the futuristic grenades in the shop menu for innocents.");
	g_iPrioFT = Config_LoadInt("futuristic_sort_prio_traitor", 0, "The sorting priority of the futuristic grenades in the shop menu for traitors.");
	g_iPrioFD = Config_LoadInt("futuristic_sort_prio_detective", 0, "The sorting priority of the futuristic grenades in the shop menu for detectives.");
	
	// Forcefield
	Config_LoadString("forcefield_name", "Force Field", "The name of this in Shop", g_sLongNameFF, sizeof(g_sLongNameFF));
	g_iPriceFFI = Config_LoadInt("forcefield_price_innocent", 8000, "The amount of credits forcefield grenades costs as innocent. 0 to disable.");
	g_iPriceFFT = Config_LoadInt("forcefield_price_traitor", 8000, "The amount of credits forcefield grenades costs as traitor. 0 to disable.");
	g_iPriceFFD = Config_LoadInt("forcefield_price_detective", 8000, "The amount of credits forcefield grenades costs as detective. 0 to disable.");
	g_iPrioFFI = Config_LoadInt("forcefield_sort_prio_innocent", 0, "The sorting priority of the forcefield grenades in the shop menu for innocents.");
	g_iPrioFFT = Config_LoadInt("forcefield_sort_prio_traitor", 0, "The sorting priority of the forcefield grenades in the shop menu for traitors.");
	g_iPrioFFD = Config_LoadInt("forcefield_sort_prio_detective", 0, "The sorting priority of the forcefield grenades in the shop menu for detectives.");
	
	// Blackhole
	Config_LoadString("blackhole_name", "Blackhole", "The name of this in Shop", g_sLongNameBH, sizeof(g_sLongNameBH));
	g_iPriceBHI = Config_LoadInt("blackhole_price_innocent", 8000, "The amount of credits blackhole grenades costs as innocent. 0 to disable.");
	g_iPriceBHT = Config_LoadInt("blackhole_price_traitor", 8000, "The amount of credits blackhole grenades costs as traitor. 0 to disable.");
	g_iPriceBHD = Config_LoadInt("blackhole_price_detective", 8000, "The amount of credits blackhole grenades costs as detective. 0 to disable.");
	g_iPrioBHI = Config_LoadInt("blackhole_sort_prio_innocent", 0, "The sorting priority of the blackhole grenades in the shop menu for innocents.");
	g_iPrioBHT = Config_LoadInt("blackhole_sort_prio_traitor", 0, "The sorting priority of the blackhole grenades in the shop menu for traitors.");
	g_iPrioBHD = Config_LoadInt("blackhole_sort_prio_detective", 0, "The sorting priority of the blackhole grenades in the shop menu for detectives.");
	
	// Explosion
	Config_LoadString("explosion_name", "Force Explosion", "The name of this in Shop", g_sLongNameFE, sizeof(g_sLongNameFE));
	g_iPriceFEI = Config_LoadInt("explosion_price_innocent", 8000, "The amount of credits explosion grenades costs as innocent. 0 to disable.");
	g_iPriceFET = Config_LoadInt("explosion_price_traitor", 8000, "The amount of credits explosion grenades costs as traitor. 0 to disable.");
	g_iPriceFED = Config_LoadInt("explosion_price_detective", 8000, "The amount of credits explosion grenades costs as detective. 0 to disable.");
	g_iPrioFEI = Config_LoadInt("explosion_sort_prio_innocent", 0, "The sorting priority of the explosion grenades in the shop menu for innocents.");
	g_iPrioFET = Config_LoadInt("explosion_sort_prio_traitor", 0, "The sorting priority of the explosion grenades in the shop menu for traitors.");
	g_iPrioFED = Config_LoadInt("explosion_sort_prio_detective", 0, "The sorting priority of the explosion grenades in the shop menu for detectives.");
	
	// Implosion
	Config_LoadString("implosion_name", "Force Implosion", "The name of this in Shop", g_sLongNameFI, sizeof(g_sLongNameFI));
	g_iPriceFII = Config_LoadInt("implosion_price_innocent", 8000, "The amount of credits implosion grenades costs as innocent. 0 to disable.");
	g_iPriceFIT = Config_LoadInt("implosion_price_traitor", 8000, "The amount of credits implosion grenades costs as traitor. 0 to disable.");
	g_iPriceFID = Config_LoadInt("implosion_price_detective", 8000, "The amount of credits implosion grenades costs as detective. 0 to disable.");
	g_iPrioFII = Config_LoadInt("implosion_sort_prio_innocent", 0, "The sorting priority of the implosion grenades in the shop menu for innocents.");
	g_iPrioFIT = Config_LoadInt("implosion_sort_prio_traitor", 0, "The sorting priority of the implosion grenades in the shop menu for traitors.");
	g_iPrioFID = Config_LoadInt("implosion_sort_prio_detective", 0, "The sorting priority of the implosion grenades in the shop menu for detectives.");

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
	TTT_RegisterCustomItem(FUTURISTIC_I, g_sLongNameF, g_iPriceFI, TTT_TEAM_INNOCENT, g_iPrioFI);
	TTT_RegisterCustomItem(FUTURISTIC_T, g_sLongNameF, g_iPriceFT, TTT_TEAM_TRAITOR, g_iPrioFT);
	TTT_RegisterCustomItem(FUTURISTIC_D, g_sLongNameF, g_iPriceFD, TTT_TEAM_DETECTIVE, g_iPrioFD);
	
	// Forcefield
	TTT_RegisterCustomItem(FF_SNAME_I, g_sLongNameFF, g_iPriceFFI, TTT_TEAM_INNOCENT, g_iPrioFFI);
	TTT_RegisterCustomItem(FF_SNAME_T, g_sLongNameFF, g_iPriceFFT, TTT_TEAM_TRAITOR, g_iPrioFFT);
	TTT_RegisterCustomItem(FF_SNAME_D, g_sLongNameFF, g_iPriceFFD, TTT_TEAM_DETECTIVE, g_iPrioFFD);
	
	// Blackhole
	TTT_RegisterCustomItem(BH_SNAME_I, g_sLongNameBH, g_iPriceBHI, TTT_TEAM_INNOCENT, g_iPrioBHI);
	TTT_RegisterCustomItem(BH_SNAME_T, g_sLongNameBH, g_iPriceBHT, TTT_TEAM_TRAITOR, g_iPrioBHT);
	TTT_RegisterCustomItem(BH_SNAME_D, g_sLongNameBH, g_iPriceBHD, TTT_TEAM_DETECTIVE, g_iPrioBHD);
	
	// Explosion
	TTT_RegisterCustomItem(FE_SNAME_I, g_sLongNameFE, g_iPriceFEI, TTT_TEAM_INNOCENT, g_iPrioFEI);
	TTT_RegisterCustomItem(FE_SNAME_T, g_sLongNameFE, g_iPriceFET, TTT_TEAM_TRAITOR, g_iPrioFET);
	TTT_RegisterCustomItem(FE_SNAME_D, g_sLongNameFE, g_iPriceFED, TTT_TEAM_DETECTIVE, g_iPrioFED);
	
	// Implosion
	TTT_RegisterCustomItem(FI_SNAME_I, g_sLongNameFI, g_iPriceFII, TTT_TEAM_INNOCENT, g_iPrioFII);
	TTT_RegisterCustomItem(FI_SNAME_T, g_sLongNameFI, g_iPriceFIT, TTT_TEAM_TRAITOR, g_iPrioFIT);
	TTT_RegisterCustomItem(FI_SNAME_D, g_sLongNameFI, g_iPriceFID, TTT_TEAM_DETECTIVE, g_iPrioFID);
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
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FUTURISTIC_I, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FUTURISTIC_T, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FUTURISTIC_D, false)))
		{
			g_bFuturistic[client] = true;
			
			if (g_bGiveDecoy)
			{
				GivePlayerItem(client, "weapon_decoy");
			}
		}
		
		// Forcefield
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FF_SNAME_I, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FF_SNAME_I, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FF_SNAME_I, false)))
		{
			g_iGMode[client] = DecoyMode_Forcefield;
			
			if (g_bGiveDecoy)
			{
				GivePlayerItem(client, "weapon_decoy");
			}
		}
		
		// Blackhole
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, BH_SNAME_I, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, BH_SNAME_I, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, BH_SNAME_I, false)))
		{
			g_iGMode[client] = DecoyMode_Blackhole;
			
			if (g_bGiveDecoy)
			{
				GivePlayerItem(client, "weapon_decoy");
			}
		}
		
		// Explosion
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FE_SNAME_I, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FE_SNAME_I, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FE_SNAME_I, false)))
		{
			g_iGMode[client] = DecoyMode_ForceExplosion;
			
			if (g_bGiveDecoy)
			{
				GivePlayerItem(client, "weapon_decoy");
			}
		}
		
		// Implosion
		if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FI_SNAME_I, false)) ||
			(role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FI_SNAME_I, false)) ||
			(role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FI_SNAME_I, false)))
		{
			g_iGMode[client] = DecoyMode_ForceImplosion;
			
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
	if (!g_bFuturistic[client] && g_iGMode[client] == DecoyMode_Normal && newmode != DecoyMode_Normal)
	{
		newmode = DecoyMode_Normal;
		return Plugin_Continue;
	}
	
	if (g_bFuturistic[client])
	{
		return Plugin_Continue;
	}
	
	if (g_iGMode[client] > DecoyMode_Normal)
	{
		if (newmode != g_iGMode[client])
		{
			newmode = g_iGMode[client];
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

public void FGrenades_OnGrenadeStart(int owner, int &particle, float pos[3], DecoyMode mode, int duration)
{
	if (g_bOneTime && (g_bFuturistic[owner] || g_iGMode[owner] != DecoyMode_Normal))
	{
		ResetFuturistic(owner);
	}
}

void ResetFuturistic(int client)
{
	g_bFuturistic[client] = false;
	g_iGMode[client] = DecoyMode_Normal;
}
