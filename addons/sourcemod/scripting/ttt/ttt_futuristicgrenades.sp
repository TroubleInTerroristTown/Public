#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <futuristicgrenades>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Futuristic Grenades"

#define BH_SNAME_I "blackhole_i"
#define BH_SNAME_T "blackhole_t"
#define BH_SNAME_D "blackhole_d"
#define FF_SNAME_I "forcefield_i"
#define FF_SNAME_T "forcefield_t"
#define FF_SNAME_D "forcefield_d"
#define FE_SNAME_I "explosion_i"
#define FE_SNAME_T "explosion_t"
#define FE_SNAME_D "explosion_d"
#define FI_SNAME_I "implosion_i"
#define FI_SNAME_T "implosion_t"
#define FI_SNAME_D "implosion_d"
#define FUTURISTIC_I "futuristic_i"
#define FUTURISTIC_T "futuristic_t"
#define FUTURISTIC_D "futuristic_d"

ConVar g_cOneTime = null;
ConVar g_cGiveDecoy = null;
ConVar g_cLongNameF = null;
ConVar g_cPriceFI = null;
ConVar g_cPriceFT = null;
ConVar g_cPriceFD = null;
ConVar g_cPrioFI = null;
ConVar g_cPrioFT = null;
ConVar g_cPrioFD = null;
ConVar g_cLongNameBH = null;
ConVar g_cPriceBHI = null;
ConVar g_cPriceBHT = null;
ConVar g_cPriceBHD = null;
ConVar g_cPrioBHI = null;
ConVar g_cPrioBHT = null;
ConVar g_cPrioBHD = null;
ConVar g_cLongNameFF = null;
ConVar g_cPriceFFI = null;
ConVar g_cPriceFFT = null;
ConVar g_cPriceFFD = null;
ConVar g_cPrioFFI = null;
ConVar g_cPrioFFT = null;
ConVar g_cPrioFFD = null;
ConVar g_cLongNameFE = null;
ConVar g_cPriceFEI = null;
ConVar g_cPriceFET = null;
ConVar g_cPriceFED = null;
ConVar g_cPrioFEI = null;
ConVar g_cPrioFET = null;
ConVar g_cPrioFED = null;
ConVar g_cLongNameFI = null;
ConVar g_cPriceFII = null;
ConVar g_cPriceFIT = null;
ConVar g_cPriceFID = null;
ConVar g_cPrioFII = null;
ConVar g_cPrioFIT = null;
ConVar g_cPrioFID = null;

bool g_bFuturistic[MAXPLAYERS + 1] =  { false, ... };
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

	StartConfig("futuristicgrenades");
	CreateConVar("ttt2_futuristic_grenades_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cOneTime = AutoExecConfig_CreateConVar("futuristic_one_time", "1", "Effect for just one grenade?", _, true, 0.0, true, 1.0);
	g_cGiveDecoy = AutoExecConfig_CreateConVar("futuristic_give_decoy", "1", "Give decoy on purchase?", _, true, 0.0, true, 1.0);
	g_cLongNameF = AutoExecConfig_CreateConVar("futuristic_name", "Futuristic Grenades", "The name of this in Shop");
	g_cPriceFI = AutoExecConfig_CreateConVar("futuristic_price_innocent", "20000", "The amount of credits futuristic grenades costs as innocent. 0 to disable.");
	g_cPriceFT = AutoExecConfig_CreateConVar("futuristic_price_traitor", "20000", "The amount of credits futuristic grenades costs as traitor. 0 to disable.");
	g_cPriceFD = AutoExecConfig_CreateConVar("futuristic_price_detective", "20000", "The amount of credits futuristic grenades costs as detective. 0 to disable.");
	g_cPrioFI = AutoExecConfig_CreateConVar("futuristic_sort_prio_innocent", "0", "The sorting priority of the futuristic grenades in the shop menu for innocents.");
	g_cPrioFT = AutoExecConfig_CreateConVar("futuristic_sort_prio_traitor", "0", "The sorting priority of the futuristic grenades in the shop menu for traitors.");
	g_cPrioFD = AutoExecConfig_CreateConVar("futuristic_sort_prio_detective", "0", "The sorting priority of the futuristic grenades in the shop menu for detectives.");
	g_cLongNameFF = AutoExecConfig_CreateConVar("forcefield_name", "Force Field", "The name of this in Shop");
	g_cPriceFFI = AutoExecConfig_CreateConVar("forcefield_price_innocent", "8000", "The amount of credits forcefield grenades costs as innocent. 0 to disable.");
	g_cPriceFFT = AutoExecConfig_CreateConVar("forcefield_price_traitor", "8000", "The amount of credits forcefield grenades costs as traitor. 0 to disable.");
	g_cPriceFFD = AutoExecConfig_CreateConVar("forcefield_price_detective", "8000", "The amount of credits forcefield grenades costs as detective. 0 to disable.");
	g_cPrioFFI = AutoExecConfig_CreateConVar("forcefield_sort_prio_innocent", "0", "The sorting priority of the forcefield grenades in the shop menu for innocents.");
	g_cPrioFFT = AutoExecConfig_CreateConVar("forcefield_sort_prio_traitor", "0", "The sorting priority of the forcefield grenades in the shop menu for traitors.");
	g_cPrioFFD = AutoExecConfig_CreateConVar("forcefield_sort_prio_detective", "0", "The sorting priority of the forcefield grenades in the shop menu for detectives.");
	g_cLongNameBH = AutoExecConfig_CreateConVar("blackhole_name", "Blackhole", "The name of this in Shop");
	g_cPriceBHI = AutoExecConfig_CreateConVar("blackhole_price_innocent", "8000", "The amount of credits blackhole grenades costs as innocent. 0 to disable.");
	g_cPriceBHT = AutoExecConfig_CreateConVar("blackhole_price_traitor", "8000", "The amount of credits blackhole grenades costs as traitor. 0 to disable.");
	g_cPriceBHD = AutoExecConfig_CreateConVar("blackhole_price_detective", "8000", "The amount of credits blackhole grenades costs as detective. 0 to disable.");
	g_cPrioBHI = AutoExecConfig_CreateConVar("blackhole_sort_prio_innocent", "0", "The sorting priority of the blackhole grenades in the shop menu for innocents.");
	g_cPrioBHT = AutoExecConfig_CreateConVar("blackhole_sort_prio_traitor", "0", "The sorting priority of the blackhole grenades in the shop menu for traitors.");
	g_cPrioBHD = AutoExecConfig_CreateConVar("blackhole_sort_prio_detective", "0", "The sorting priority of the blackhole grenades in the shop menu for detectives.");
	g_cLongNameFE = AutoExecConfig_CreateConVar("explosion_name", "Force Explosion", "The name of this in Shop");
	g_cPriceFEI = AutoExecConfig_CreateConVar("explosion_price_innocent", "8000", "The amount of credits explosion grenades costs as innocent. 0 to disable.");
	g_cPriceFET = AutoExecConfig_CreateConVar("explosion_price_traitor", "8000", "The amount of credits explosion grenades costs as traitor. 0 to disable.");
	g_cPriceFED = AutoExecConfig_CreateConVar("explosion_price_detective", "8000", "The amount of credits explosion grenades costs as detective. 0 to disable.");
	g_cPrioFEI = AutoExecConfig_CreateConVar("explosion_sort_prio_innocent", "0", "The sorting priority of the explosion grenades in the shop menu for innocents.");
	g_cPrioFET = AutoExecConfig_CreateConVar("explosion_sort_prio_traitor", "0", "The sorting priority of the explosion grenades in the shop menu for traitors.");
	g_cPrioFED = AutoExecConfig_CreateConVar("explosion_sort_prio_detective", "0", "The sorting priority of the explosion grenades in the shop menu for detectives.");
	g_cLongNameFI = AutoExecConfig_CreateConVar("implosion_name", "Force Implosion", "The name of this in Shop");
	g_cPriceFII = AutoExecConfig_CreateConVar("implosion_price_innocent", "8000", "The amount of credits implosion grenades costs as innocent. 0 to disable.");
	g_cPriceFIT = AutoExecConfig_CreateConVar("implosion_price_traitor", "8000", "The amount of credits implosion grenades costs as traitor. 0 to disable.");
	g_cPriceFID = AutoExecConfig_CreateConVar("implosion_price_detective", "8000", "The amount of credits implosion grenades costs as detective. 0 to disable.");
	g_cPrioFII = AutoExecConfig_CreateConVar("implosion_sort_prio_innocent", "0", "The sorting priority of the implosion grenades in the shop menu for innocents.");
	g_cPrioFIT = AutoExecConfig_CreateConVar("implosion_sort_prio_traitor", "0", "The sorting priority of the implosion grenades in the shop menu for traitors.");
	g_cPrioFID = AutoExecConfig_CreateConVar("implosion_sort_prio_detective", "0", "The sorting priority of the implosion grenades in the shop menu for detectives.");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
	char sFile[] = "futuristicgrenades.smx";
	Handle hPlugin = FindPluginByFile(sFile);
	
	if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
	{
		SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?p=2499362", sFile);
		return;
	}
	
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongNameF.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(FUTURISTIC_I, sBuffer, g_cPriceFI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFI.IntValue);
	TTT_RegisterCustomItem(FUTURISTIC_T, sBuffer, g_cPriceFT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFT.IntValue);
	TTT_RegisterCustomItem(FUTURISTIC_D, sBuffer, g_cPriceFD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFD.IntValue);
	
	g_cLongNameFF.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(FF_SNAME_I, sBuffer, g_cPriceFFI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFFI.IntValue);
	TTT_RegisterCustomItem(FF_SNAME_T, sBuffer, g_cPriceFFT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFFT.IntValue);
	TTT_RegisterCustomItem(FF_SNAME_D, sBuffer, g_cPriceFFD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFFD.IntValue);
	
	g_cLongNameBH.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(BH_SNAME_I, sBuffer, g_cPriceBHI.IntValue, TTT_TEAM_INNOCENT, g_cPrioBHI.IntValue);
	TTT_RegisterCustomItem(BH_SNAME_T, sBuffer, g_cPriceBHT.IntValue, TTT_TEAM_TRAITOR, g_cPrioBHT.IntValue);
	TTT_RegisterCustomItem(BH_SNAME_D, sBuffer, g_cPriceBHD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioBHD.IntValue);
	
	g_cLongNameFE.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(FE_SNAME_I, sBuffer, g_cPriceFEI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFEI.IntValue);
	TTT_RegisterCustomItem(FE_SNAME_T, sBuffer, g_cPriceFET.IntValue, TTT_TEAM_TRAITOR, g_cPrioFET.IntValue);
	TTT_RegisterCustomItem(FE_SNAME_D, sBuffer, g_cPriceFED.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFED.IntValue);
	
	g_cLongNameFI.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(FI_SNAME_I, sBuffer, g_cPriceFII.IntValue, TTT_TEAM_INNOCENT, g_cPrioFII.IntValue);
	TTT_RegisterCustomItem(FI_SNAME_T, sBuffer, g_cPriceFIT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFIT.IntValue);
	TTT_RegisterCustomItem(FI_SNAME_D, sBuffer, g_cPriceFID.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFID.IntValue);
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
			
			if (g_cGiveDecoy.BoolValue)
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
			
			if (g_cGiveDecoy.BoolValue)
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
			
			if (g_cGiveDecoy.BoolValue)
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
			
			if (g_cGiveDecoy.BoolValue)
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
			
			if (g_cGiveDecoy.BoolValue)
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
	if (g_cOneTime.BoolValue && (g_bFuturistic[owner] || g_iGMode[owner] != DecoyMode_Normal))
	{
		ResetFuturistic(owner);
	}
}

void ResetFuturistic(int client)
{
	g_bFuturistic[client] = false;
	g_iGMode[client] = DecoyMode_Normal;
}
