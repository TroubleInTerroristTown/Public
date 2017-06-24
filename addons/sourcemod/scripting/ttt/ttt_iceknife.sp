#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "icek"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Ice Knife"

int g_iPrice = 0;
int g_iDamage = 0;
int g_iCount = 0;
int g_iPrio = 0;
int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };

int g_iOldColors[MAXPLAYERS + 1][4];

float g_fFreezeTime = 0.0;

bool g_bFreezeTraitors = false;
bool g_bFreezed[MAXPLAYERS + 1] =  { false, ... };
bool g_bIceKnife[MAXPLAYERS + 1] = { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sFreezeSound[PLATFORM_MAX_PATH] = "";
char g_sLongName[64] = "";

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	Config_Done();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/iceknife.cfg");
	Config_Setup("TTT-IceKnife", g_sConfigFile);
	
	Config_LoadString("icek_name", "Ice Knife", "The name of the Ice Knife in the Shop", g_sLongName, sizeof(g_sLongName));
	
	g_iPrice = Config_LoadInt("icek_price", 9000, "The amount of credits a Ice Knife costs as traitor. 0 to disable.");
	g_iCount = Config_LoadInt("icek_count", 1, "The amount of usages for Ice Knifes per round as traitor. 0 to disable.");
	g_iPrio = Config_LoadInt("icek_sort_prio", 0, "The sorting priority of the Ice Knife in the shop menu.");
	g_iDamage = Config_LoadInt("icek_damage", 0, "Amount of damage with a ice knife. 0 to disable.");
	g_bFreezeTraitors = Config_LoadBool("icek_freeze_traitors", false, "Allow to freeze other traitors?");
	g_fFreezeTime = Config_LoadFloat("icek_freeze_time", 5.0, "Length of the freeze time.");
	
	
	Config_Done();
	
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

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iPrice, TTT_TEAM_TRAITOR, g_iPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			if (g_iPCount[client] >= g_iCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iCount);
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
	
	if (!g_bFreezeTraitors && TTT_GetClientRole(iVictim) == TTT_TEAM_TRAITOR)
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
		
		if (g_fFreezeTime > 0.0)
		{
			CreateTimer(g_fFreezeTime, Timer_FreezeEnd, GetClientUserId(iVictim));
		}
		
		if (g_iDamage == 0)
		{
			return Plugin_Handled;
		}
		else if (g_iDamage > 0)
		{
			damage = view_as<float>(g_iDamage);
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
