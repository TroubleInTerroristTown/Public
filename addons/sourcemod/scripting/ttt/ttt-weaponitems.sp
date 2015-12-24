#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt>
#include <ttt-weaponitems>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Weapons"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

bool g_bHasKnife[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH];

int g_iKev_Type;
int g_iKev_Price;
int g_iUSP_Price;
int g_iM4_Price;
int g_iKF_Price;

int g_iKev_Max;
int g_iKnife_Max;

int g_iKnives[MAXPLAYERS+1];
int g_iKevs[MAXPLAYERS+1];

char g_cKev_Long[64];
char g_cUSP_Long[64];
char g_cM4_Long[64];
char g_cKF_Long[64];

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/weapons.cfg");

	Config_Setup("TTT-BaseWeapons", g_sConfigFile);

	g_iKev_Type = Config_LoadInt("kevlar_type", 1, "Type of kevlar configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_iKev_Price = Config_LoadInt("kevlar_price", 2500, "The amount of credits the kevlar costs. 0 to disable.");
	g_iKev_Max = Config_LoadInt("kevlar_max", 5, "The max amount of times a player can purchase kevlar in one round. 0 for unlimited.");
	Config_LoadString("kevlar_name", "Kevlar", "The name of the Kevlar in the shop menu.", g_cKev_Long, sizeof(g_cKev_Long));


	g_iUSP_Price = Config_LoadInt("usp_price", 3000, "The amount of credits the USP-S costs. 0 to disable.");
	Config_LoadString("usp_name", "USP-S", "The name of the USP-S in the shop menu.", g_cUSP_Long, sizeof(g_cUSP_Long));

	g_iM4_Price = Config_LoadInt("m4a1_price", 3000, "The amount of credits the USP-S costs. 0 to disable.");
	Config_LoadString("m4a1_name", "M4A1-S", "The name of the M4A1-S in the shop menu.", g_cM4_Long, sizeof(g_cM4_Long));

	g_iKF_Price = Config_LoadInt("1knife_price", 3000, "The amount of credits the USP-S costs. 0 to disable.");
	g_iKnife_Max = Config_LoadInt("1knife_max", 5, "The max amount of times a player can purchase 1-knife in one round. 0 for unlimited.");
	Config_LoadString("1knife_name", "1-Hit Knife", "The name of the 1-hit knife in the shop menu.", g_cKF_Long, sizeof(g_cKF_Long));

	LoadTranslations("ttt.phrases");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnAllPluginsLoaded()
{
	if(g_iKev_Price > 0)
	{
		if(g_iKev_Type == 0)
			TTT_RegisterCustomItem(KEV_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_UNASSIGNED);
		if(g_iKev_Type == 1)
		{
			TTT_RegisterCustomItem(KEV_T_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_TRAITOR);
			TTT_RegisterCustomItem(KEV_D_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_DETECTIVE);
		}
		if(g_iKev_Type == 2)
			TTT_RegisterCustomItem(KEV_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_TRAITOR);
	}

	if(g_iKF_Price > 0)
		TTT_RegisterCustomItem(KF_ITEM_SHORT, g_cKF_Long, g_iKF_Price, TTT_TEAM_TRAITOR);
	if(g_iM4_Price > 0)
		TTT_RegisterCustomItem(M4_ITEM_SHORT, g_cM4_Long, g_iM4_Price, TTT_TEAM_TRAITOR);
	if(g_iUSP_Price > 0)
		TTT_RegisterCustomItem(USP_ITEM_SHORT, g_cUSP_Long, g_iUSP_Price, TTT_TEAM_TRAITOR);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	ResetKnifes();
	return Plugin_Continue;
}

public Action TTT_OnRoundStart_Pre()
{
	ResetKnifes();
	return Plugin_Continue;
}

public void TTT_OnRoundStartFailed(int p, int r, int d)
{
	ResetKnifes();
}

public void TTT_OnRoundStart(int i, int t, int d)
{
	ResetKnifes();
}

public void TTT_OnClientDeath(int v, int a)
{
	g_bHasKnife[v] = false;
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(strcmp(itemshort, USP_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
					return Plugin_Stop;

			if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));

			GivePlayerItem(client, "weapon_usp_silencer");
		}
		else if(strcmp(itemshort, M4_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
				return Plugin_Stop;
			if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));

			GivePlayerItem(client, "weapon_m4a1_silencer");
		}
		else if(strcmp(itemshort, KF_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
				return Plugin_Stop;

			if(g_iKnives[client] > g_iKnife_Max > 0){
				CPrintToChat(client, "%t", "You reached limit", g_iKnife_Max);
				return Plugin_Stop;
			}

			g_bHasKnife[client] = true;
			g_iKnives[client]++;
		}else if(	(strcmp(itemshort, KEV_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iKevs[client] > g_iKev_Max > 0){
					CPrintToChat(client, "%t", "You reached limit", g_iKev_Max);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_iKev_Type == 0)
						GiveArmor(client);
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_iKev_Type == 0 || g_iKev_Type == 1)
						GiveArmor(client);
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
					GiveArmor(client);
		}
	}

	return Plugin_Continue;
}

void GiveArmor(int client)
{
	g_iKevs[client]++;
	SetEntData(client, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
}

void ResetKnifes()
{
	LoopValidClients(i){
		g_bHasKnife[i] = false;
		g_iKnives[i] = 0;
		g_iKevs[i] = 0;
	}
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if(!TTT_IsRoundActive())
		return Plugin_Continue;

	if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
		return Plugin_Continue;

	if(g_bHasKnife[iAttacker])
	{
		char sWeapon[64];
		GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));

		if((StrContains(sWeapon, "knife", false) != -1) || (StrContains(sWeapon, "bayonet", false) != -1))
		{
			g_bHasKnife[iAttacker] = false;
			damage = float(GetClientHealth(iVictim) + GetClientArmor(iVictim));
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}
