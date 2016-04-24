#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Icons"

int g_iIcon[MAXPLAYERS + 1] =  { 0, ... };

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
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	g_bSeeRoles = Config_LoadBool("ttt_dead_players_can_see_other_roles", false, "Allow dead players to see other roles. 0 = Disabled (default). 1 = Enabled.");
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/icon.cfg");
	Config_Setup("TTT-Icons", g_sConfigFile);
	Config_LoadString("ttt_icon_traitor_icon", "sprites/sg_traitor_icon", "Path to traitor icon file", g_sTraitorIcon, sizeof(g_sTraitorIcon));
	Config_LoadString("ttt_icon_detective_icon", "sprites/sg_detective_icon", "Path to detective icon file", g_sDetectiveIcon, sizeof(g_sDetectiveIcon));
	
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
		if(IsPlayerAlive(client))
			ClearIcon(client);
}

public void TTT_OnUpdate()
{
	LoopValidClients(i)
		if(IsPlayerAlive(i))
			g_iIcon[i] = CreateIcon(i, TTT_GetClientRole(i));
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
	
	if(TTT_GetClientRole(client) > TTT_TEAM_UNASSIGNED)
		ClearIcon(client);
}

stock void ApplyIcons()
{
	LoopValidClients(i)
		if(IsPlayerAlive(i))
			g_iIcon[i] = CreateIcon(i, TTT_GetClientRole(i));
}

stock int CreateIcon(int client, int role)
{
	ClearIcon(client);
	
	if(role < TTT_TEAM_TRAITOR)
		return 0;

	char iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float origin[3];

	GetClientAbsOrigin(client, origin);
	origin[2] = origin[2] + 80.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent)
		return -1;
	
	char sBuffer[PLATFORM_MAX_PATH];
	
	if(role == TTT_TEAM_DETECTIVE)
	{
		Format(sBuffer, sizeof(sBuffer), "%s.vmt", g_sDetectiveIcon);
		DispatchKeyValue(Ent, "model", sBuffer);
	}
	else if(role == TTT_TEAM_TRAITOR)
	{
		Format(sBuffer, sizeof(sBuffer), "%s.vmt", g_sTraitorIcon);
		DispatchKeyValue(Ent, "model", sBuffer);
	}
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.08");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent);

	if(role == TTT_TEAM_TRAITOR)
		SDKHook(Ent, SDKHook_SetTransmit, Hook_SetTransmitT);
	return Ent;
}

public Action Hook_SetTransmitT(int entity, int client)
{
	if ((entity != client && TTT_GetClientRole(client) != TTT_TEAM_TRAITOR && IsPlayerAlive(client)) || g_bSeeRoles && (!IsPlayerAlive(client) || GetClientTeam(client < CS_TEAM_CT)))
		return Plugin_Handled;

	return Plugin_Continue;
}

stock void ClearIcon(int client)
{
	int role = TTT_GetClientRole(client);
	if(role > 0 && IsValidEdict(g_iIcon[client]))
	{
		if(role == TTT_TEAM_TRAITOR) SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
		AcceptEntityInput(g_iIcon[client], "Kill");
	}
	ShowOverlayToClient(client, " ");
	g_iIcon[client] = 0;

}

public int Native_SetIcon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int role = GetNativeCell(2);
	
	g_iIcon[client] = CreateIcon(client, role);
		
	return 0;
}