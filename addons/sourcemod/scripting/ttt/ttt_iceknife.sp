#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "iceknife"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Ice Knife"

ConVar g_cPrice = null;
ConVar g_cDamage = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cFreezeTime = null;
ConVar g_cFreezeTraitors = null;
ConVar g_cLongName = null;

int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iOldColors[MAXPLAYERS + 1][4];

bool g_bFreezed[MAXPLAYERS + 1] =  { false, ... };
bool g_bIceKnife[MAXPLAYERS + 1] = { false, ... };

char g_sFreezeSound[PLATFORM_MAX_PATH] = "";

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

	StartConfig("ice_knife");
	CreateConVar("ttt2_ice_knife_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("iceknife_name", "Ice Knife", "The name of the Ice Knife in the Shop");
	g_cPrice = AutoExecConfig_CreateConVar("iceknife_price", "9000", "The amount of credits a Ice Knife costs as traitor. 0 to disable.");
	g_cCount = AutoExecConfig_CreateConVar("iceknife_count", "1", "The amount of usages for Ice Knifes per round as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("iceknife_sort_prio", "0", "The sorting priority of the Ice Knife in the shop menu.");
	g_cDamage = AutoExecConfig_CreateConVar("iceknife_damage", "0", "Amount of damage with a ice knife. 0 to disable.");
	g_cFreezeTraitors = AutoExecConfig_CreateConVar("iceknife_freeze_traitors", "0", "Allow to freeze other traitors?", _, true, 0.0, true, 1.0);
	g_cFreezeTime = AutoExecConfig_CreateConVar("iceknife_freeze_time", "5.0", "Length of the freeze time.");
	EndConfig();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	LateLoadAll();
}

public void OnMapStart()
{
	Handle hConfig = LoadGameConfigFile("funcommands.games");
	if (hConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	if (GameConfGetKeyValue(hConfig, "SoundFreeze", g_sFreezeSound, sizeof(g_sFreezeSound)) && g_sFreezeSound[0])
	{
		PrecacheSound(g_sFreezeSound, true);
	}
	
	delete hConfig;
}

public void OnClientPutInServer(int client)
{
	HookClient(client);
}

public void LateLoadAll()
{
	LoopValidClients(i)
	{
		LateLoadClient(i);
	}
}
public void LateLoadClient(int client)
{
	HookClient(client);
}

public void HookClient(int client)
{
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}


public void OnClientDisconnect(int client)
{
	if (TTT_IsClientValid(client))
	{
		ResetIceK(client);
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		GetEntityRenderColor(client, g_iOldColors[client][0], g_iOldColors[client][1], g_iOldColors[client][2], g_iOldColors[client][3]);
	}
}

public void OnConfigsExecuted()
{
	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			if (g_iPCount[client] >= g_cCount.IntValue)
			{
				char sName[MAX_ITEM_LENGTH], sTag[64];
				g_cLongName.GetString(sName, sizeof(sName));
				
				ConVar hTag = FindConVar("ttt_plugin_tag");
				hTag.GetString(sTag, sizeof(sTag));
				
				CPrintToChat(client, "%s %T", sTag, "Bought All", client, sName, g_cCount.IntValue);
				return Plugin_Stop;
			}

			if (count)
			{
				g_bIceKnife[client] = true;
			}

			g_iPCount[client]++;
		}
	}
	return Plugin_Continue;
}

void ResetIceK(int client)
{
	g_iPCount[client] = 0;
	g_bFreezed[client] = false;
	g_bIceKnife[client] = false;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}

	if (!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
	{
		return Plugin_Continue;
	}

	if (g_bFreezed[iVictim])
	{
		return Plugin_Handled;
	}

	if (IsWorldDamage(iAttacker, damagetype))
	{
		return Plugin_Continue;
	}

	if (!g_bIceKnife[iAttacker])
	{
		return Plugin_Continue;
	}

	if (!g_cFreezeTraitors.BoolValue && TTT_GetClientRole(iVictim) == TTT_TEAM_TRAITOR)
	{
		return Plugin_Continue;
	}

	char sWeapon[64];
	GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
	if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1)
	{
		g_bFreezed[iVictim] = true;
		g_bIceKnife[iAttacker] = false;

		SetEntityMoveType(iVictim, MOVETYPE_NONE);
		SetEntPropFloat(iVictim, Prop_Data, "m_flLaggedMovementValue", 0.0);

		GetEntityRenderColor(iVictim, g_iOldColors[iVictim][0], g_iOldColors[iVictim][1], g_iOldColors[iVictim][2], g_iOldColors[iVictim][3]);
		SetEntityRenderColor(iVictim, 0, 128, 255, 135);

		PlayFreezeSound(iVictim);

		if (g_cFreezeTime.FloatValue > 0.0)
		{
			CreateTimer(g_cFreezeTime.FloatValue, Timer_FreezeEnd, GetClientUserId(iVictim));
		}

		if (g_cDamage.IntValue == 0)
		{
			return Plugin_Handled;
		}
		else if (g_cDamage.IntValue > 0)
		{
			damage = view_as<float>(g_cDamage.IntValue);
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action Timer_FreezeEnd(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		PlayFreezeSound(client);

		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

		SetEntityRenderColor(client, g_iOldColors[client][0], g_iOldColors[client][1], g_iOldColors[client][2], g_iOldColors[client][3]);

		g_bFreezed[client] = false;
	}
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (g_bFreezed[client])
	{
		float fVel[3];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);

		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void PlayFreezeSound(int client)
{
	if (g_sFreezeSound[0])
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		vec[2] += 10;

		GetClientEyePosition(client, vec);
		EmitAmbientSound(g_sFreezeSound, vec, client, SNDLEVEL_RAIDSIREN);
	}
}
