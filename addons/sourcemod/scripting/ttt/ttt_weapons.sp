#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <ttt_weapons>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Weapons"

#define HEAVY_MODEL "models/player/custom_player/legacy/tm_phoenix_heavy.mdl"

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

int g_iKev_Type = -1;
int g_iKev_Price = -1;
int g_iHeavy_Type = -1;
int g_iHeavy_Armor = -1;
int g_iHeavy_Price = -1;
int g_iHelm_Type = -1;
int g_iHelm_Price = -1;
int g_iKevHelm_Type = -1;
int g_iKevHelm_Price = -1;
int g_iUSP_Price = -1;
int g_iM4_Price = -1;

int g_iAWP_Price = -1;
int g_iAWP_Min_Shots = -1;
int g_iAWP_Max_Shots = -1;

int g_iKF_Price = -1;

int g_iKev_Max = -1;
int g_iHeavy_Max = -1;
int g_iKev_Prio = -1;
int g_iHeavy_Prio = -1;

int g_iKevHelm_Max = -1;
int g_iKevHelm_Prio = -1;

int g_iHelm_Max = -1;
int g_iHelm_Prio = -1;

int g_iKnife_Max = -1;
int g_iKnife_Prio = -1;

int g_iUSP_Prio = -1;
int g_iM4_Prio = -1;
int g_iAWP_Prio = -1;

int g_iAK_Prio = -1;
int g_iAK_Price = -1;
char g_cAK_Long[64];

int g_iDeagle_Prio = -1;
int g_iDeagle_Price = -1;
char g_cDeagle_Long[64];

int g_iRevolver_Prio = -1;
int g_iRevolver_Price = -1;
char g_cRevolver_Long[64];

int g_iScout_Prio = -1;
int g_iScout_Price = -1;
char g_cScout_Long[64];

int g_iKnives[MAXPLAYERS+1] = { -1, ...};
int g_iKevs[MAXPLAYERS+1] = { -1, ...};
int g_iHeavy[MAXPLAYERS+1] = { -1, ...};
int g_iHelms[MAXPLAYERS+1] = { -1, ...};
int g_iKevHelms[MAXPLAYERS+1] = { -1, ...};

char g_cKev_Long[64];
char g_cKevHelm_Long[64];
char g_cHeavy_Long[64];
char g_cHelm_Long[64];
char g_cUSP_Long[64];
char g_cM4_Long[64];
char g_cAWP_Long[64];
char g_cKF_Long[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ttt_weapons");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/weapons.cfg");

	Config_Setup("TTT-BaseWeapons", g_sConfigFile);

	g_iKev_Type = Config_LoadInt("kevlar_type", 1, "Type of kevlar configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_iKev_Price = Config_LoadInt("kevlar_price", 3000, "The amount of credits the kevlar costs. 0 to disable.");
	g_iKev_Max = Config_LoadInt("kevlar_max", 5, "The max amount of times a player can purchase kevlar in one round. 0 for unlimited.");
	g_iKev_Prio = Config_LoadInt("kevlar_sort_prio", 0, "The sorting priority of the kevlar in the shop menu.");
	Config_LoadString("kevlar_name", "Kevlar", "The name of the kevlar in the shop menu.", g_cKev_Long, sizeof(g_cKev_Long));
	
	g_iHeavy_Type = Config_LoadInt("heavy_type", 1, "Type of heavy configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_iHeavy_Armor = Config_LoadInt("heavy_armor", 100, "The amount of armor the heavy has. 100 is default.");
	g_iHeavy_Price = Config_LoadInt("heavy_price", 10000, "The amount of credits the heavy costs. 0 to disable.");
	g_iHeavy_Max = Config_LoadInt("heavy_max", 5, "The max amount of times a player can purchase heavy in one round. 0 for unlimited.");
	g_iHeavy_Prio = Config_LoadInt("heavy_sort_prio", 0, "The sorting priority of the heavy in the shop menu.");
	Config_LoadString("heavy_name", "Heavy", "The name of the heavy in the shop menu.", g_cHeavy_Long, sizeof(g_cHeavy_Long));
	
	g_iHelm_Type = Config_LoadInt("helm_type", 1, "Type of helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_iHelm_Price = Config_LoadInt("helm_price", 2000, "The amount of credits the helm costs. 0 to disable.");
	g_iHelm_Max = Config_LoadInt("helm_max", 5, "The max amount of times a player can purchase helm in one round. 0 for unlimited.");
	g_iHelm_Prio = Config_LoadInt("helm_sort_prio", 0, "The sorting priority of the helm in the shop menu.");
	Config_LoadString("helm_name", "Helm", "The name of the helm in the shop menu.", g_cHelm_Long, sizeof(g_cHelm_Long));
	
	g_iKevHelm_Type = Config_LoadInt("kevhelm_type", 1, "Type of kevlar+helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_iKevHelm_Price = Config_LoadInt("kevhelm_price", 2000, "The amount of credits the kevlar+helm costs. 0 to disable.");
	g_iKevHelm_Max = Config_LoadInt("kevhelm_max", 5, "The max amount of times a player can purchase kevlar+helm in one round. 0 for unlimited.");
	g_iKevHelm_Prio = Config_LoadInt("kevhelm_sort_prio", 0, "The sorting priority of the kevlar+helm in the shop menu.");
	Config_LoadString("kevhelm_name", "Kevlar+Helm", "The name of the kevlar+helm in the shop menu.", g_cKevHelm_Long, sizeof(g_cKevHelm_Long));

	g_iUSP_Price = Config_LoadInt("usp_price", 3000, "The amount of credits the USP-S costs. 0 to disable.");
	g_iUSP_Prio = Config_LoadInt("usp_sort_prio", 0, "The sorting priority of the USP-S in the shop menu.");
	Config_LoadString("usp_name", "USP-S", "The name of the USP-S in the shop menu.", g_cUSP_Long, sizeof(g_cUSP_Long));
	
	g_iAK_Price = Config_LoadInt("ak47_price", 3000, "The amount of credits the AK47 costs. 0 to disable.");
	g_iAK_Prio = Config_LoadInt("ak47_sort_prio", 0, "The sorting priority of the AK47 in the shop menu.");
	Config_LoadString("ak47_name", "AK47", "The name of the AK47 in the shop menu.", g_cAK_Long, sizeof(g_cAK_Long));
	
	g_iDeagle_Price = Config_LoadInt("deagle_price", 3000, "The amount of credits the Deagle costs. 0 to disable.");
	g_iDeagle_Prio = Config_LoadInt("deagle_sort_prio", 0, "The sorting priority of the Deagle in the shop menu.");
	Config_LoadString("deagle_name", "Deagle", "The name of the Deagle in the shop menu.", g_cDeagle_Long, sizeof(g_cDeagle_Long));
	
	g_iRevolver_Price = Config_LoadInt("revolver_price", 3000, "The amount of credits the Revolver costs. 0 to disable.");
	g_iRevolver_Prio = Config_LoadInt("revolver_sort_prio", 0, "The sorting priority of the Revolver in the shop menu.");
	Config_LoadString("revolver_name", "Revolver", "The name of the Revolver in the shop menu.", g_cRevolver_Long, sizeof(g_cRevolver_Long));
	
	g_iScout_Price = Config_LoadInt("scout_price", 3000, "The amount of credits the Scout costs. 0 to disable.");
	g_iScout_Prio = Config_LoadInt("scout_sort_prio", 0, "The sorting priority of the Scout in the shop menu.");
	Config_LoadString("scout_name", "Scout", "The name of the Scout in the shop menu.", g_cScout_Long, sizeof(g_cScout_Long));
	
	g_iM4_Price = Config_LoadInt("m4a1_price", 3000, "The amount of credits the M4A1-S costs. 0 to disable.");
	g_iM4_Prio = Config_LoadInt("m4a1_sort_prio", 0, "The sorting priority of the M4A1-S in the shop menu.");
	Config_LoadString("m4a1_name", "M4A1-S", "The name of the M4A1-S in the shop menu.", g_cM4_Long, sizeof(g_cM4_Long));

	g_iAWP_Price = Config_LoadInt("awp_price", 3000, "The amount of credits the AWP costs. 0 to disable.");
	g_iAWP_Min_Shots = Config_LoadInt("awp_min_shots", 1, "The min. amount of shots of traitor awp.");
	g_iAWP_Max_Shots = Config_LoadInt("awp_max_shots", 3, "The max. amount of shots of traitor awp.");
	g_iAWP_Prio = Config_LoadInt("awp_sort_prio", 0, "The sorting priority of the AWP in the shop menu.");
	Config_LoadString("awp_name", "AWP", "The name of the AWP in the shop menu.", g_cAWP_Long, sizeof(g_cAWP_Long));

	g_iKF_Price = Config_LoadInt("1knife_price", 3000, "The amount of credits the One-Hit Knife costs. 0 to disable.");
	g_iKnife_Max = Config_LoadInt("1knife_max", 5, "The max amount of times a player can purchase 1-knife in one round. 0 for unlimited.");
	g_iKnife_Prio = Config_LoadInt("1knife_sort_prio", 0, "The sorting priority of the One-Hit Knife in the shop menu.");
	Config_LoadString("1knife_name", "1-Hit Knife", "The name of the 1-hit knife in the shop menu.", g_cKF_Long, sizeof(g_cKF_Long));
	
	Config_Done();

	LoadTranslations("ttt.phrases");
}

public void OnMapStart()
{
	PrecacheModel(HEAVY_MODEL, true);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnAllPluginsLoaded()
{
	if(g_iKev_Type == 0)
	{
		TTT_RegisterCustomItem(KEV_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_UNASSIGNED, g_iKev_Prio);
	}
	else if(g_iKev_Type == 1)
	{
		TTT_RegisterCustomItem(KEV_T_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_TRAITOR, g_iKev_Prio);
		TTT_RegisterCustomItem(KEV_D_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_DETECTIVE, g_iKev_Prio);
	}
	else if(g_iKev_Type == 2)
	{
		TTT_RegisterCustomItem(KEV_ITEM_SHORT, g_cKev_Long, g_iKev_Price, TTT_TEAM_TRAITOR, g_iKev_Prio);
	}
	
	
	
	if(g_iHeavy_Type == 0)
	{
		TTT_RegisterCustomItem(HEAVY_ITEM_SHORT, g_cHeavy_Long, g_iHeavy_Price, TTT_TEAM_UNASSIGNED, g_iHeavy_Prio);
	}
	else if(g_iHeavy_Type == 1)
	{
		TTT_RegisterCustomItem(HEAVY_T_ITEM_SHORT, g_cHeavy_Long, g_iHeavy_Price, TTT_TEAM_TRAITOR, g_iHeavy_Prio);
		TTT_RegisterCustomItem(HEAVY_D_ITEM_SHORT, g_cHeavy_Long, g_iHeavy_Price, TTT_TEAM_DETECTIVE, g_iHeavy_Prio);
	}
	else if(g_iHeavy_Type == 2)
	{
		TTT_RegisterCustomItem(HEAVY_ITEM_SHORT, g_cHelm_Long, g_iHeavy_Price, TTT_TEAM_TRAITOR, g_iHeavy_Prio);
	}
	
	
	
	
	if(g_iHelm_Type == 0)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, g_cHelm_Long, g_iHelm_Price, TTT_TEAM_UNASSIGNED, g_iHelm_Prio);
	}
	else if(g_iHelm_Type == 1)
	{
		TTT_RegisterCustomItem(HELM_T_ITEM_SHORT, g_cHelm_Long, g_iHelm_Price, TTT_TEAM_TRAITOR, g_iHelm_Prio);
		TTT_RegisterCustomItem(HELM_D_ITEM_SHORT, g_cHelm_Long, g_iHelm_Price, TTT_TEAM_DETECTIVE, g_iHelm_Prio);
	}
	else if(g_iHelm_Type == 2)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, g_cHelm_Long, g_iHelm_Price, TTT_TEAM_TRAITOR, g_iHelm_Prio);
	}
		
	
	if(g_iKevHelm_Type == 0)
	{
		TTT_RegisterCustomItem(KEVHELM_ITEM_SHORT, g_cKevHelm_Long, g_iKevHelm_Price, TTT_TEAM_UNASSIGNED, g_iKevHelm_Prio);
	}
	else if(g_iKevHelm_Type == 1)
	{
		TTT_RegisterCustomItem(KEVHELM_T_ITEM_SHORT, g_cKevHelm_Long, g_iKevHelm_Price, TTT_TEAM_TRAITOR, g_iKevHelm_Prio);
		TTT_RegisterCustomItem(KEVHELM_D_ITEM_SHORT, g_cKevHelm_Long, g_iKevHelm_Price, TTT_TEAM_DETECTIVE, g_iKevHelm_Prio);
	}
	else if(g_iKevHelm_Type == 2)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, g_cKevHelm_Long, g_iKevHelm_Price, TTT_TEAM_TRAITOR, g_iKevHelm_Prio);
	}

	TTT_RegisterCustomItem(KF_ITEM_SHORT, g_cKF_Long, g_iKF_Price, TTT_TEAM_TRAITOR, g_iKnife_Prio);
	TTT_RegisterCustomItem(M4_ITEM_SHORT, g_cM4_Long, g_iM4_Price, TTT_TEAM_TRAITOR, g_iM4_Prio);
	TTT_RegisterCustomItem(AWP_ITEM_SHORT, g_cAWP_Long, g_iAWP_Price, TTT_TEAM_TRAITOR, g_iAWP_Prio);
	TTT_RegisterCustomItem(USP_ITEM_SHORT, g_cUSP_Long, g_iUSP_Price, TTT_TEAM_TRAITOR, g_iUSP_Prio);
	TTT_RegisterCustomItem(AK_ITEM_SHORT, g_cAK_Long, g_iAK_Price, TTT_TEAM_TRAITOR, g_iAK_Prio);
	TTT_RegisterCustomItem(DEAGLE_ITEM_SHORT, g_cDeagle_Long, g_iDeagle_Price, TTT_TEAM_TRAITOR, g_iDeagle_Prio);
	TTT_RegisterCustomItem(REVOLVER_ITEM_SHORT, g_cRevolver_Long, g_iRevolver_Price, TTT_TEAM_TRAITOR, g_iRevolver_Prio);
	TTT_RegisterCustomItem(SCOUT_ITEM_SHORT, g_cScout_Long, g_iScout_Price, TTT_TEAM_TRAITOR, g_iScout_Prio);
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

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(strcmp(itemshort, USP_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}

			if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
			}

			GivePlayerItem(client, "weapon_usp_silencer");
		}
		else if(strcmp(itemshort, AK_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
			}

			GivePlayerItem(client, "weapon_ak47");
		}
		else if(strcmp(itemshort, DEAGLE_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
			}

			GivePlayerItem(client, "weapon_deagle");
		}
		else if(strcmp(itemshort, REVOLVER_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
			}

			GivePlayerItem(client, "weapon_revolver");
		}
		else if(strcmp(itemshort, SCOUT_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
			}

			GivePlayerItem(client, "weapon_ssg08");
		}
		else if(strcmp(itemshort, M4_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
			}

			GivePlayerItem(client, "weapon_m4a1_silencer");
		}
		if(strcmp(itemshort, AWP_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
			{
				SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
			}

			int iAWP = GivePlayerItem(client, "weapon_awp");

			if(iAWP != -1)
			{
				EquipPlayerWeapon(client, iAWP);
				SetEntProp(iAWP, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
				SetEntProp(iAWP, Prop_Send, "m_iClip1", GetRandomInt(g_iAWP_Min_Shots, g_iAWP_Max_Shots));
			}
			else
			{
				TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_iAWP_Price);
			}
		}
		else if(strcmp(itemshort, KF_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}

			if(g_iKnives[client] > g_iKnife_Max > 0)
			{
				CPrintToChat(client, "%t", "You reached limit", g_iKnife_Max);
				return Plugin_Stop;
			}

			g_bHasKnife[client] = true;
			g_iKnives[client]++;
		}
		else if(	(strcmp(itemshort, KEV_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iKevs[client] > g_iKev_Max > 0)
				{
					CPrintToChat(client, "%t", "You reached limit", g_iKev_Max);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_iKev_Type == 0)
					{
						GiveArmor(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_iKev_Type == 0 || g_iKev_Type == 1)
					{
						GiveArmor(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
				{
					GiveArmor(client);
				}
		}
		else if((strcmp(itemshort, KEVHELM_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEVHELM_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEVHELM_D_ITEM_SHORT, false) == 0))
		 {
			if(g_iKevHelms[client] > g_iKevHelm_Max > 0)
			{
				CPrintToChat(client, "%t", "You reached limit", g_iKev_Max);
				return Plugin_Stop;
			}
			
			GiveArmor(client);
			GiveHelm(client);
		}
		else if(	(strcmp(itemshort, HELM_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HELM_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HELM_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iHelms[client] > g_iHelm_Max > 0)
				{
					CPrintToChat(client, "%t", "You reached limit", g_iHelm_Max);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_iHelm_Type == 0)
					{
						GiveHelm(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_iHelm_Type == 0 || g_iHelm_Type == 1)
					{
						GiveHelm(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
				{
					GiveArmor(client);
				}
		}
		else if(	(strcmp(itemshort, HEAVY_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HEAVY_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HEAVY_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iHeavy[client] > g_iHeavy_Max > 0)
				{
					CPrintToChat(client, "%t", "You reached limit", g_iHeavy_Max);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_iHeavy_Type == 0)
					{
						GiveHeavy(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_iHeavy_Type == 0 || g_iHeavy_Type == 1)
					{
						GiveHeavy(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
				{
					GiveHeavy(client);
				}
		}
	}

	return Plugin_Continue;
}

void GiveArmor(int client)
{
	g_iKevs[client]++;
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
}

void GiveHeavy(int client)
{
	g_iHeavy[client]++;
	SetEntityModel(client, HEAVY_MODEL);
	GivePlayerItem(client, "item_assaultsuit");
	SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
	
	if(g_iHeavy_Armor > 100)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", g_iHeavy_Armor, 1);
	}
}

void GiveHelm(int client)
{
	g_iHelms[client]++;
	SetEntData(client, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
}

void ResetKnifes()
{
	LoopValidClients(i)
	{
		g_bHasKnife[i] = false;
		g_iKnives[i] = 0;
		g_iKevs[i] = 0;
		g_iHeavy[i] = 0;
		g_iHelms[i] = 0;
	}
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3])
{
	if(!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}

	if(!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
	{
		return Plugin_Continue;
	}

	if(g_bHasKnife[iAttacker] && IsValidEntity(iWeapon))
	{
		char sWeapon[64];
		
		GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));

		if((StrContains(sWeapon, "knife", false) != -1) || (StrContains(sWeapon, "bayonet", false) != -1))
		{
			g_bHasKnife[iAttacker] = false;
			fDamage = float(GetClientHealth(iVictim) + GetClientArmor(iVictim));
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}
