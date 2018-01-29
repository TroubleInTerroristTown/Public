#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Radar"
#define SHORT_NAME "radar"
#define SHORT_NAME_T "radar_t"

ConVar g_cLongName = null;

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cDiscount = null;
ConVar g_cInterval = null;
ConVar g_cRed = null;
ConVar g_cGreen = null;
ConVar g_cBlue = null;
ConVar g_cAlpha = null;

ConVar g_cTPrice = null;
ConVar g_cTPrio = null;
ConVar g_cTDiscount = null;
ConVar g_cTInterval = null;
ConVar g_cTRed = null;
ConVar g_cTGreen = null;
ConVar g_cTBlue = null;
ConVar g_cTAlpha = null;

bool g_bRadar[MAXPLAYERS + 1] =  { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

int g_iBeam = -1;
int g_iHalo = -1;

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
	
	TTT_StartConfig("radar");
	CreateConVar("ttt2_radar_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("radar_name", "Radar", "The name of this in Shop");
	
	g_cPrice = AutoExecConfig_CreateConVar("radar_price", "9000", "The amount of credits Radar costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("radar_sort_prio", "0", "The sorting priority of the Radar in the detective shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("radar_discount", "0", "Should detective Radar discountable?", _, true, 0.0, true, 1.0);
	g_cInterval = AutoExecConfig_CreateConVar("radar_update_interval", "30", "Time in seconds to update player locations for detective radar");
	g_cRed = AutoExecConfig_CreateConVar("radar_player_color_red", "255", "Red colors for detective radar", _, true, 0.0, true, 255.0);
	g_cGreen = AutoExecConfig_CreateConVar("radar_player_color_green", "0", "Green colors for detective radar", _, true, 0.0, true, 255.0);
	g_cBlue = AutoExecConfig_CreateConVar("radar_player_color_blue", "255", "Blue colors for detective radar", _, true, 0.0, true, 255.0);
	g_cAlpha = AutoExecConfig_CreateConVar("radar_player_color_alpha", "255", "Visibility for detective radar", _, true, 0.0, true, 255.0);
	
	g_cTPrice = AutoExecConfig_CreateConVar("radar_price_traitor", "9000", "The amount of credits Radar costs as traitor. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("radar_sort_prio_traitor", "0", "The sorting priority of the Radar in the traitor shop menu.");
	g_cTDiscount = AutoExecConfig_CreateConVar("radar_discount_traitor", "0", "Should traitor Radar discountable?", _, true, 0.0, true, 1.0);
	g_cTInterval = AutoExecConfig_CreateConVar("radar_update_interval_traitor", "30", "Time in seconds to update player locations for traitor radar");
	g_cTRed = AutoExecConfig_CreateConVar("radar_player_color_traitor_red", "255", "Red colors for traitor radar", _, true, 0.0, true, 255.0);
	g_cTGreen = AutoExecConfig_CreateConVar("radar_player_color_traitor_green", "0", "Green colors for traitor radar", _, true, 0.0, true, 255.0);
	g_cTBlue = AutoExecConfig_CreateConVar("radar_player_color_traitor_blue", "255", "Blue colors for traitor radar", _, true, 0.0, true, 255.0);
	g_cTAlpha = AutoExecConfig_CreateConVar("radar_player_color_traitor_alpha", "255", "Visibility for traitor radar", _, true, 0.0, true, 255.0);
	TTT_EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	g_iBeam = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_iHalo = PrecacheModel("materials/sprites/halo.vtf");
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, g_cDiscount.BoolValue);
	TTT_RegisterCustomItem(SHORT_NAME_T, sName, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTDiscount.BoolValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public void OnClientDisconnect(int client)
{
	ResetRadar(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false) || StrEqual(itemshort, SHORT_NAME_T, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_DETECTIVE && role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			
			if (!IsPlayerAlive(client))
			{
				return Plugin_Stop;
			}
			
			g_bRadar[client] = true;
			
			SetBeam(client);
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetRadar(client);
	}
}

void ResetRadar(int client)
{
	g_bRadar[client] = false;
}

void SetBeam(int client)
{
	int role = TTT_GetClientRole(client);
	float fPos[3];
	
	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			if (i == client)
			{
				continue;
			}
			
			GetClientAbsOrigin(i, fPos);
			
			int iColor[4];
			
			if (role == TTT_TEAM_TRAITOR)
			{
				iColor[0] = g_cRed.IntValue;
				iColor[1] = g_cGreen.IntValue;
				iColor[2] = g_cBlue.IntValue;
				iColor[3] = g_cAlpha.IntValue;

				TE_SetupBeamRingPoint(fPos, 30.0, 31.0, g_iBeam, g_iHalo, 0, 15, g_cTInterval.FloatValue, 5.0, 0.0, iColor, 10, 0);
			}
			else if (role == TTT_TEAM_DETECTIVE)
			{
				iColor[0] = g_cTRed.IntValue;
				iColor[1] = g_cTGreen.IntValue;
				iColor[2] = g_cTBlue.IntValue;
				iColor[3] = g_cTAlpha.IntValue;

				TE_SetupBeamRingPoint(fPos, 30.0, 31.0, g_iBeam, g_iHalo, 0, 15, g_cInterval.FloatValue, 5.0, 0.0, iColor, 10, 0);
			}

			TE_SendToClient(client);
		}
	}

	CPrintToChat(client, "%s %T", g_sPluginTag, "Radar Updated", client);

	if (IsPlayerAlive(client))
	{
		if (role == TTT_TEAM_TRAITOR)
		{
			CreateTimer((g_cTInterval.FloatValue - 1.5), Timer_UpdateRadar, GetClientUserId(client));
		}
		else if (role == TTT_TEAM_DETECTIVE)
		{
			CreateTimer((g_cInterval.FloatValue - 1.5), Timer_UpdateRadar, GetClientUserId(client));
		}
	}
}

public Action Timer_UpdateRadar(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client))
	{
		if (IsPlayerAlive(client) && g_bRadar[client])
		{
			SetBeam(client);
		}
	}
	
	return Plugin_Stop;
}
