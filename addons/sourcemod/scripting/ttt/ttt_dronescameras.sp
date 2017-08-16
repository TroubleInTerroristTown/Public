#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <config_loader>
#include <camerasanddrones>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Cameras and Drones"

#define CAMERA_SHORT_NAME "camera"
char g_sCLongName[64];
int g_iCPrice = 0;
int g_iCPrio = 0;

#define DRONE_SHORT_NAME "drone"
char g_sDLongName[64];
int g_iDPrice = 0;
int g_iDPrio = 0;

int g_iMyWeapons = -1;

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

	g_iMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	if (g_iMyWeapons == -1)
	{
		SetFailState("m_hMyWeapons not found...");
	}

	LoadTranslations("ttt.phrases");

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);

	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/camerasanddrones.cfg");
	Config_Setup("TTT-CAD", g_sConfigFile);

	Config_LoadString("cad_camera_name", "Camera", "The name of this in Shop", g_sCLongName, sizeof(g_sCLongName));
	g_iCPrice = Config_LoadInt("cad_camera_price", 9000, "The amount of credits a camera costs as detective. 0 to disable.");
	g_iCPrio = Config_LoadInt("cad_camera_sort_prio", 0, "The sorting priority of the TEMPLATE in the shop menu.");

	Config_LoadString("cad_drone_name", "Drone", "The name of this in Shop", g_sDLongName, sizeof(g_sDLongName));
	g_iDPrice = Config_LoadInt("cad_drone_price", 9000, "The amount of credits a drone costs as detective. 0 to disable.");
	g_iDPrio = Config_LoadInt("cad_drone_sort_prio", 0, "The sorting priority of the drone in the shop menu.");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetCAD(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, CAMERA_SHORT_NAME, false) || StrEqual(itemshort, DRONE_SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role == TTT_TEAM_DETECTIVE)
			{
				OverridePlayerGear(client, 1);
			}
			else if (role == TTT_TEAM_TRAITOR)
			{
				OverridePlayerGear(client, 2);
			}
			else
			{
				return Plugin_Stop;
			}
			
			for(int offset = 0; offset < 128; offset += 4)
			{
				int weapon = GetEntDataEnt2(client, g_iMyWeapons + offset);
	
				if (IsValidEntity(weapon))
				{
					char sClass[32];
					GetEntityClassname(weapon, sClass, sizeof(sClass));
	
					if (StrEqual(sClass, "weapon_tagrenade", false))
					{
						TTT_SafeRemoveWeapon(client, weapon);
					}
				}
			}
	
			GivePlayerItem(client, "weapon_tagrenade");
		}
	}
	return Plugin_Continue;
}


public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetCAD(client);
	}
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(CAMERA_SHORT_NAME, g_sCLongName, g_iCPrice, TTT_TEAM_DETECTIVE, g_iCPrio);
	TTT_RegisterCustomItem(DRONE_SHORT_NAME, g_sDLongName, g_iDPrice, TTT_TEAM_TRAITOR, g_iDPrio);
}

void ResetCAD(int client)
{
	OverridePlayerGear(client, -1);
}
