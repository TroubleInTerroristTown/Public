#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <ttt_weapons>
#include <multicolors>

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

ConVar g_cKev_Long = null;
ConVar g_cKevHelm_Long = null;
ConVar g_cHeavy_Long = null;
ConVar g_cHelm_Long = null;
ConVar g_cUSP_Long = null;
ConVar g_cM4_Long = null;
ConVar g_cAWP_Long = null;
ConVar g_cKF_Long = null;
ConVar g_cAK_Long = null;
ConVar g_cDeagle_Long = null;
ConVar g_cRevolver_Long = null;
ConVar g_cScout_Long = null;
ConVar g_cKev_Type = null;
ConVar g_cKev_Price = null;
ConVar g_cHeavy_Type = null;
ConVar g_cHeavy_Armor = null;
ConVar g_cHeavy_Price = null;
ConVar g_cHelm_Type = null;
ConVar g_cHelm_Price = null;
ConVar g_cKevHelm_Type = null;
ConVar g_cKevHelm_Price = null;
ConVar g_cUSP_Price = null;
ConVar g_cM4_Price = null;
ConVar g_cAWP_Price = null;
ConVar g_cAWP_Min_Shots = null;
ConVar g_cAWP_Max_Shots = null;
ConVar g_cKF_Price = null;
ConVar g_cKev_Max = null;
ConVar g_cHeavy_Max = null;
ConVar g_cKev_Prio = null;
ConVar g_cHeavy_Prio = null;
ConVar g_cKevHelm_Max = null;
ConVar g_cKevHelm_Prio = null;
ConVar g_cHelm_Max = null;
ConVar g_cHelm_Prio = null;
ConVar g_cKnife_Max = null;
ConVar g_cKnife_Prio = null;
ConVar g_cUSP_Prio = null;
ConVar g_cM4_Prio = null;
ConVar g_cAWP_Prio = null;
ConVar g_cAK_Prio = null;
ConVar g_cAK_Price = null;
ConVar g_cDeagle_Prio = null;
ConVar g_cDeagle_Price = null;
ConVar g_cRevolver_Prio = null;
ConVar g_cRevolver_Price = null;
ConVar g_cScout_Prio = null;
ConVar g_cScout_Price = null;

bool g_bHasKnife[MAXPLAYERS + 1] =  { false, ... };

int g_iKnives[MAXPLAYERS+1] = { -1, ...};
int g_iKevs[MAXPLAYERS+1] = { -1, ...};
int g_iHeavy[MAXPLAYERS+1] = { -1, ...};
int g_iHelms[MAXPLAYERS+1] = { -1, ...};
int g_iKevHelms[MAXPLAYERS+1] = { -1, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ttt_weapons");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	StartConfig("weapons");
	CreateConVar("ttt2_weapons_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cKev_Type = AutoExecConfig_CreateConVar("kevlar_type", "1", "Type of kevlar configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_cKev_Price = AutoExecConfig_CreateConVar("kevlar_price", "3000", "The amount of credits the kevlar costs. 0 to disable.");
	g_cKev_Max = AutoExecConfig_CreateConVar("kevlar_max", "5", "The max amount of times a player can purchase kevlar in one round. 0 for unlimited.");
	g_cKev_Prio = AutoExecConfig_CreateConVar("kevlar_sort_prio", "0", "The sorting priority of the kevlar in the shop menu.");
	g_cHeavy_Type = AutoExecConfig_CreateConVar("heavy_type", "1", "Type of heavy configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_cHeavy_Armor = AutoExecConfig_CreateConVar("heavy_armor", "100", "The amount of armor the heavy has. 100 is default.");
	g_cHeavy_Price = AutoExecConfig_CreateConVar("heavy_price", "10000", "The amount of credits the heavy costs. 0 to disable.");
	g_cHeavy_Max = AutoExecConfig_CreateConVar("heavy_max", "5", "The max amount of times a player can purchase heavy in one round. 0 for unlimited.");
	g_cHeavy_Prio = AutoExecConfig_CreateConVar("heavy_sort_prio", "0", "The sorting priority of the heavy in the shop menu.");
	g_cHelm_Type = AutoExecConfig_CreateConVar("helm_type", "1", "Type of helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_cHelm_Price = AutoExecConfig_CreateConVar("helm_price", "2000", "The amount of credits the helm costs. 0 to disable.");
	g_cHelm_Max = AutoExecConfig_CreateConVar("helm_max", "5", "The max amount of times a player can purchase helm in one round. 0 for unlimited.");
	g_cHelm_Prio = AutoExecConfig_CreateConVar("helm_sort_prio", "0", "The sorting priority of the helm in the shop menu.");
	g_cKevHelm_Type = AutoExecConfig_CreateConVar("kevhelm_type", "1", "Type of kevlar+helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
	g_cKevHelm_Price = AutoExecConfig_CreateConVar("kevhelm_price", "2000", "The amount of credits the kevlar+helm costs. 0 to disable.");
	g_cKevHelm_Max = AutoExecConfig_CreateConVar("kevhelm_max", "5", "The max amount of times a player can purchase kevlar+helm in one round. 0 for unlimited.");
	g_cKevHelm_Prio = AutoExecConfig_CreateConVar("kevhelm_sort_prio", "0", "The sorting priority of the kevlar+helm in the shop menu.");
	g_cUSP_Price = AutoExecConfig_CreateConVar("usp_price", "3000", "The amount of credits the USP-S costs. 0 to disable.");
	g_cUSP_Prio = AutoExecConfig_CreateConVar("usp_sort_prio", "0", "The sorting priority of the USP-S in the shop menu.");
	g_cAK_Price = AutoExecConfig_CreateConVar("ak47_price", "3000", "The amount of credits the AK47 costs. 0 to disable.");
	g_cAK_Prio = AutoExecConfig_CreateConVar("ak47_sort_prio", "0", "The sorting priority of the AK47 in the shop menu.");
	g_cDeagle_Price = AutoExecConfig_CreateConVar("deagle_price", "3000", "The amount of credits the Deagle costs. 0 to disable.");
	g_cDeagle_Prio = AutoExecConfig_CreateConVar("deagle_sort_prio", "0", "The sorting priority of the Deagle in the shop menu.");
	g_cRevolver_Price = AutoExecConfig_CreateConVar("revolver_price", "3000", "The amount of credits the Revolver costs. 0 to disable.");
	g_cRevolver_Prio = AutoExecConfig_CreateConVar("revolver_sort_prio", "0", "The sorting priority of the Revolver in the shop menu.");
	g_cScout_Price = AutoExecConfig_CreateConVar("scout_price", "3000", "The amount of credits the Scout costs. 0 to disable.");
	g_cScout_Prio = AutoExecConfig_CreateConVar("scout_sort_prio", "0", "The sorting priority of the Scout in the shop menu.");
	g_cM4_Price = AutoExecConfig_CreateConVar("m4a1_price", "3000", "The amount of credits the M4A1-S costs. 0 to disable.");
	g_cM4_Prio = AutoExecConfig_CreateConVar("m4a1_sort_prio", "0", "The sorting priority of the M4A1-S in the shop menu.");
	g_cAWP_Price = AutoExecConfig_CreateConVar("awp_price", "3000", "The amount of credits the AWP costs. 0 to disable.");
	g_cAWP_Min_Shots = AutoExecConfig_CreateConVar("awp_min_shots", "1", "The min. amount of shots of traitor awp.");
	g_cAWP_Max_Shots = AutoExecConfig_CreateConVar("awp_max_shots", "3", "The max. amount of shots of traitor awp.");
	g_cAWP_Prio = AutoExecConfig_CreateConVar("awp_sort_prio", "0", "The sorting priority of the AWP in the shop menu.");
	g_cKF_Price = AutoExecConfig_CreateConVar("1knife_price", "3000", "The amount of credits the One-Hit Knife costs. 0 to disable.");
	g_cKnife_Max = AutoExecConfig_CreateConVar("1knife_max", "5", "The max amount of times a player can purchase 1-knife in one round. 0 for unlimited.");
	g_cKnife_Prio = AutoExecConfig_CreateConVar("1knife_sort_prio", "0", "The sorting priority of the One-Hit Knife in the shop menu.");
	g_cKev_Long = AutoExecConfig_CreateConVar("kevlar_name", "Kevlar", "The name of the kevlar in the shop menu.");
	g_cHeavy_Long = AutoExecConfig_CreateConVar("heavy_name", "Heavy", "The name of the heavy in the shop menu.");
	g_cHelm_Long = AutoExecConfig_CreateConVar("helm_name", "Helm", "The name of the helm in the shop menu.");
	g_cKevHelm_Long = AutoExecConfig_CreateConVar("kevhelm_name", "Kevlar+Helm", "The name of the kevlar+helm in the shop menu.");
	g_cUSP_Long = AutoExecConfig_CreateConVar("usp_name", "USP-S", "The name of the USP-S in the shop menu.");
	g_cAK_Long = AutoExecConfig_CreateConVar("ak47_name", "AK47", "The name of the AK47 in the shop menu.");
	g_cDeagle_Long = AutoExecConfig_CreateConVar("deagle_name", "Deagle", "The name of the Deagle in the shop menu.");
	g_cRevolver_Long = AutoExecConfig_CreateConVar("revolver_name", "Revolver", "The name of the Revolver in the shop menu.");
	g_cScout_Long = AutoExecConfig_CreateConVar("scout_name", "Scout", "The name of the Scout in the shop menu.");
	g_cM4_Long = AutoExecConfig_CreateConVar("m4a1_name", "M4A1-S", "The name of the M4A1-S in the shop menu.");
	g_cAWP_Long = AutoExecConfig_CreateConVar("awp_name", "AWP", "The name of the AWP in the shop menu.");
	g_cKF_Long = AutoExecConfig_CreateConVar("1knife_name", "1-Hit Knife", "The name of the 1-hit knife in the shop menu.");
	EndConfig();

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
	char sBuffer[128];
	
	g_cKev_Long.GetString(sBuffer, sizeof(sBuffer));
	if(g_cKev_Type.IntValue == 0)
	{
		TTT_RegisterCustomItem(KEV_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cKev_Prio.IntValue);
	}
	else if(g_cKev_Type.IntValue == 1)
	{
		TTT_RegisterCustomItem(KEV_T_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_TRAITOR, g_cKev_Prio.IntValue);
		TTT_RegisterCustomItem(KEV_D_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_DETECTIVE, g_cKev_Prio.IntValue);
	}
	else if(g_cKev_Type.IntValue == 2)
	{
		TTT_RegisterCustomItem(KEV_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_TRAITOR, g_cKev_Prio.IntValue);
	}


	g_cHeavy_Long.GetString(sBuffer, sizeof(sBuffer));
	if(g_cHeavy_Type.IntValue == 0)
	{
		TTT_RegisterCustomItem(HEAVY_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cHeavy_Prio.IntValue);
	}
	else if(g_cHeavy_Type.IntValue == 1)
	{
		TTT_RegisterCustomItem(HEAVY_T_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_TRAITOR, g_cHeavy_Prio.IntValue);
		TTT_RegisterCustomItem(HEAVY_D_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_DETECTIVE, g_cHeavy_Prio.IntValue);
	}
	else if(g_cHeavy_Type.IntValue == 2)
	{
		TTT_RegisterCustomItem(HEAVY_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_TRAITOR, g_cHeavy_Prio.IntValue);
	}

	g_cHelm_Long.GetString(sBuffer, sizeof(sBuffer));
	if(g_cHelm_Type.IntValue == 0)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cHelm_Prio.IntValue);
	}
	else if(g_cHelm_Type.IntValue == 1)
	{
		TTT_RegisterCustomItem(HELM_T_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cHelm_Prio.IntValue);
		TTT_RegisterCustomItem(HELM_D_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_DETECTIVE, g_cHelm_Prio.IntValue);
	}
	else if(g_cHelm_Type.IntValue == 2)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cHelm_Prio.IntValue);
	}

	g_cKevHelm_Long.GetString(sBuffer, sizeof(sBuffer));
	if(g_cKevHelm_Type.IntValue == 0)
	{
		TTT_RegisterCustomItem(KEVHELM_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cKevHelm_Prio.IntValue);
	}
	else if(g_cKevHelm_Type.IntValue == 1)
	{
		TTT_RegisterCustomItem(KEVHELM_T_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cKevHelm_Prio.IntValue);
		TTT_RegisterCustomItem(KEVHELM_D_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_DETECTIVE, g_cKevHelm_Prio.IntValue);
	}
	else if(g_cKevHelm_Type.IntValue == 2)
	{
		TTT_RegisterCustomItem(HELM_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cKevHelm_Prio.IntValue);
	}

	g_cKF_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(KF_ITEM_SHORT, sBuffer, g_cKF_Price.IntValue, TTT_TEAM_TRAITOR, g_cKnife_Prio.IntValue);

	g_cM4_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(M4_ITEM_SHORT, sBuffer, g_cM4_Price.IntValue, TTT_TEAM_TRAITOR, g_cM4_Prio.IntValue);

	g_cAWP_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(AWP_ITEM_SHORT, sBuffer, g_cAWP_Price.IntValue, TTT_TEAM_TRAITOR, g_cAWP_Prio.IntValue);

	g_cUSP_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(USP_ITEM_SHORT, sBuffer, g_cUSP_Price.IntValue, TTT_TEAM_TRAITOR, g_cUSP_Prio.IntValue);

	g_cAK_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(AK_ITEM_SHORT, sBuffer, g_cAK_Price.IntValue, TTT_TEAM_TRAITOR, g_cAK_Prio.IntValue);

	g_cDeagle_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(DEAGLE_ITEM_SHORT, sBuffer, g_cDeagle_Price.IntValue, TTT_TEAM_TRAITOR, g_cDeagle_Prio.IntValue);

	g_cRevolver_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(REVOLVER_ITEM_SHORT, sBuffer, g_cRevolver_Price.IntValue, TTT_TEAM_TRAITOR, g_cRevolver_Prio.IntValue);

	g_cScout_Long.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SCOUT_ITEM_SHORT, sBuffer, g_cScout_Price.IntValue, TTT_TEAM_TRAITOR, g_cScout_Prio.IntValue);

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
				SetEntProp(iAWP, Prop_Send, "m_iClip1", GetRandomInt(g_cAWP_Min_Shots.IntValue, g_cAWP_Max_Shots.IntValue));
			}
			else
			{
				TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cAWP_Price.IntValue);
			}
		}
		else if(strcmp(itemshort, KF_ITEM_SHORT, false) == 0)
		{
			if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}

			if(g_iKnives[client] > g_cKnife_Max.IntValue > 0)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_cKnife_Max.IntValue);
				return Plugin_Stop;
			}

			g_bHasKnife[client] = true;
			g_iKnives[client]++;
		}
		else if(	(strcmp(itemshort, KEV_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, KEV_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iKevs[client] > g_cKev_Max.IntValue > 0)
				{
					CPrintToChat(client, "%T", "You reached limit", client, g_cKev_Max.IntValue);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_cKev_Type.IntValue == 0)
					{
						GiveArmor(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_cKev_Type.IntValue == 0 || g_cKev_Type.IntValue == 1)
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
			if(g_iKevHelms[client] > g_cKevHelm_Max.IntValue > 0)
			{
				CPrintToChat(client, "%T", "You reached limit", client, g_cKevHelm_Max.IntValue);
				return Plugin_Stop;
			}

			GiveArmor(client);
			GiveHelm(client);
		}
		else if(	(strcmp(itemshort, HELM_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HELM_T_ITEM_SHORT, false) == 0)
		 || (strcmp(itemshort, HELM_D_ITEM_SHORT, false) == 0))
		 {
				if(g_iHelms[client] > g_cHelm_Max.IntValue > 0)
				{
					CPrintToChat(client, "%T", "You reached limit", client, g_cHelm_Max.IntValue);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_cHelm_Type.IntValue == 0)
					{
						GiveHelm(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_cHelm_Type.IntValue == 0 || g_cHelm_Type.IntValue == 1)
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
				if(g_iHeavy[client] > g_cHeavy_Max.IntValue > 0)
				{
					CPrintToChat(client, "%T", "You reached limit", client, g_cHeavy_Max.IntValue);
					return Plugin_Stop;
				}

				if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if(g_cHeavy_Type.IntValue == 0)
					{
						GiveHeavy(client);
					}
				}
				if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
				{
					if(g_cHeavy_Type.IntValue == 0 || g_cHeavy_Type.IntValue == 1)
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
	GivePlayerItem(client, "item_heavyassaultsuit");
	SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);

	if(g_cHeavy_Armor.IntValue > 100)
	{
		SetEntProp(client, Prop_Data, "m_ArmorValue", g_cHeavy_Armor.IntValue, 1);
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
