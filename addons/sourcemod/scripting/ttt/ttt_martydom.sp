#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME_I "md_i"
#define SHORT_NAME_T "md_t"
#define SHORT_NAME_D "md_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Martydom"

ConVar g_cLongName = null;
ConVar g_cGrenadeDelay = null;
ConVar g_cDamage = null;
ConVar g_cExplosionSize = null;
ConVar g_cIPrice = null;
ConVar g_cIPrio = null;
ConVar g_cDPrice = null;
ConVar g_cDPrio = null;
ConVar g_cTPrice = null;
ConVar g_cTPrio = null;

float g_fDeathPos[MAXPLAYERS+1][3];

bool g_bHasMartydom[MAXPLAYERS+1];

/* Drops a live high explosive grenade on a players body */

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION, 
	version = TTT_PLUGIN_VERSION, 
	url = TTT_PLUGIN_URL
};

public void OnPluginStart() {

	TTT_IsGameCSGO();
	
	LoadTranslations("ttt.phrases");

	StartConfig("martydom");
	CreateConVar("ttt2_martydom_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("martydom_name", "Martydom", "The name of this item in the shop.");
	g_cIPrice = AutoExecConfig_CreateConVar("md_i_price", "2000", "The amount of credits martydom costs as innocent. 0 to disable.");	
	g_cTPrice = AutoExecConfig_CreateConVar("md_t_price", "2000", "The amount of credits martydom costs as traitor. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("md_d_price", "2000", "The amount of credits martydom costs as detective. 0 to disable.");
	g_cIPrio = AutoExecConfig_CreateConVar("md_i_sort_prio", "0", "The sorting priority of the martydom in the shop menu for innocents.");
	g_cTPrio = AutoExecConfig_CreateConVar("md_t_sort_prio", "0", "The sorting priority of the martydom in the shop menu for traitors.");
	g_cDPrio = AutoExecConfig_CreateConVar("md_d_sort_prio", "0", "The sorting priority of the martydom in the shop menu for detectives.");
	g_cGrenadeDelay = AutoExecConfig_CreateConVar("md_grenade_delay", "0.25", "The time delay it takes for the grenade to spawn after a player dies. Decimals allowed. (Def. 0.25)");
	g_cDamage = AutoExecConfig_CreateConVar("md_grenade_damage", "99.0", "The damage the grenade does at the explosions center point. Decimals allowed. (Def. 99.0)");
	g_cExplosionSize = AutoExecConfig_CreateConVar("md_explosion_size", "350.0", "The size of the explosion. Decimals allowed. (Def. 350.0)");
	EndConfig();

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
}

public void OnClientDisconnect(int client)
{
	g_bHasMartydom[client] = false;
}

public void OnAllPluginsLoaded()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_I, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_I, false) || StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
		{
			if(g_bHasMartydom[client])
			{
				return Plugin_Stop;
			}
			g_bHasMartydom[client] = true;
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_CreateGrenade(Handle timer, any client)
{
	if(TTT_IsClientValid(client))
	{
		CreateGrenade(client);
	}
}

public Action Event_RoundStart(Handle event, const char[] name, bool inrestart)
{
	LoopValidClients(i)
	{
		g_bHasMartydom[i] = false;
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool inrestart)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}
		
	if(!g_bHasMartydom[client])
	{
		return Plugin_Continue;
	}
		
	GetClientAbsOrigin(client, g_fDeathPos[client]);
	CreateTimer(g_cGrenadeDelay.FloatValue, Timer_CreateGrenade, client);
	
	g_bHasMartydom[client] = false;
	
	return Plugin_Continue;
	
}

public void CreateGrenade(int client)
{
	
	int entity = CreateEntityByName("hegrenade_projectile");
	DispatchSpawn(entity);
	
	// Make sure the grenade doesn't spawn in the ground
	g_fDeathPos[client][2] += 30;
	
	TeleportEntity(entity, g_fDeathPos[client], NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "InitializeSpawnFromWorld");
	
	SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);
	SetEntProp(entity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
	SetEntPropFloat(entity, Prop_Data, "m_flDamage", g_cDamage.FloatValue);
	SetEntPropFloat(entity, Prop_Data, "m_DmgRadius", g_cExplosionSize.FloatValue); 

}
