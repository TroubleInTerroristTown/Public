#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Icons"

int g_iIcon[MAXPLAYERS + 1] =  { -1, ... };

char g_sAdminImmunity[16];
bool g_bSeeRoles = false;

char g_sTraitorIcon[PLATFORM_MAX_PATH] = "";
char g_sDetectiveIcon[PLATFORM_MAX_PATH] = "";
char g_sConfigFile[PLATFORM_MAX_PATH] = "";

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_SetIcon", Native_SetIcon);
	
	RegPluginLibrary("ttt_icon");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	g_bSeeRoles = Config_LoadBool("ttt_dead_players_can_see_other_roles", false, "Allow dead players to see other roles. 0 = Disabled (default). 1 = Enabled.");
	Config_Done();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/icon.cfg");
	Config_Setup("TTT-Icons", g_sConfigFile);
	Config_LoadString("ttt_icon_traitor_icon", "sprites/sg_traitor_icon", "Path to traitor icon file", g_sTraitorIcon, sizeof(g_sTraitorIcon));
	Config_LoadString("ttt_icon_detective_icon", "sprites/sg_detective_icon", "Path to detective icon file", g_sDetectiveIcon, sizeof(g_sDetectiveIcon));
	Config_LoadString("ttt_icon_dead_admin", "bz", "Show traitor icon for dead admins? (Nothing to disable it)", g_sAdminImmunity, sizeof(g_sAdminImmunity));
	Config_Done();
	
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
}

public void OnMapStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sTraitorIcon);
	AddFileToDownloadsTable(sBuffer);
	PrecacheModel(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", g_sDetectiveIcon);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", g_sDetectiveIcon);
	AddFileToDownloadsTable(sBuffer);
	PrecacheModel(sBuffer);
}

public void OnClientDisconnect(int client)
{
	ClearIcon(client);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	LoopValidClients(client)
	{
		ClearIcon(client);
	}
}

public void TTT_OnUpdate1(int client)
{
	if (IsPlayerAlive(client))
	{
		g_iIcon[client] = CreateIcon(client, TTT_GetClientRole(client));
	}
}

public void TTT_OnRoundStart()
{
	ApplyIcons();
}

public void TTT_OnClientGetRole(int client, int role)
{
	g_iIcon[client] = CreateIcon(client, role);
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	ClearIcon(client);
}

stock void ApplyIcons()
{
	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			g_iIcon[i] = CreateIcon(i, TTT_GetClientRole(i));
		}
	}
}

stock int CreateIcon(int client, int role)
{
	ClearIcon(client);
	
	if (role < TTT_TEAM_TRAITOR)
	{
		return -1;
	}

	char iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float origin[3];

	GetClientAbsOrigin(client, origin);
	origin[2] = origin[2] + 80.0;

	int ent = CreateEntityByName("env_sprite");
	if (!ent)
	{
		return -1;
	}
	
	char sBuffer[PLATFORM_MAX_PATH];
	
	if (role == TTT_TEAM_DETECTIVE)
	{
		Format(sBuffer, sizeof(sBuffer), "%s.vmt", g_sDetectiveIcon);
	}
	else if (role == TTT_TEAM_TRAITOR)
	{
		Format(sBuffer, sizeof(sBuffer), "%s.vmt", g_sTraitorIcon);
	}
	
	DispatchKeyValue(ent, "model", sBuffer);
	DispatchKeyValue(ent, "classname", "env_sprite");
	DispatchKeyValue(ent, "spawnflags", "1");
	DispatchKeyValue(ent, "scale", "0.08");
	DispatchKeyValue(ent, "rendermode", "1");
	DispatchKeyValue(ent, "rendercolor", "255 255 255");
	DispatchSpawn(ent);
	TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(ent, "SetParent", ent, ent);

	if (role == TTT_TEAM_TRAITOR)
	{
		SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmitT);
	}
	return ent;
}

public Action Hook_SetTransmitT(int entity, int client)
{
	if (TTT_IsClientValid(client))
	{
		if (!IsPlayerAlive(client))
		{
			if (g_bSeeRoles)
			{
				return Plugin_Continue;
			}
			else
			{
				if (strlen(g_sAdminImmunity) > 1)
				{
					char sFlags[16];
					AdminFlag aFlags[16];
					
					Format(sFlags, sizeof(sFlags), g_sAdminImmunity);
					FlagBitsToArray(ReadFlagString(sFlags), aFlags, sizeof(aFlags));
					
					if (TTT_HasFlags(client, aFlags))
					{
						return Plugin_Continue;
					}
				}
			}
		}
		
		if (IsPlayerAlive(client) && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		{
			return Plugin_Continue;
		}
	}	
	return Plugin_Handled;
}

stock void ClearIcon(int client)
{
	int role = TTT_GetClientRole(client);
	
	if (IsValidEdict(g_iIcon[client]))
	{
		if (role == TTT_TEAM_TRAITOR)
		{
			SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
		}
		AcceptEntityInput(g_iIcon[client], "Kill");
	}
	
	g_iIcon[client] = -1;

}

public int Native_SetIcon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int role = GetNativeCell(2);
	
	g_iIcon[client] = CreateIcon(client, role);
		
	return 0;
}