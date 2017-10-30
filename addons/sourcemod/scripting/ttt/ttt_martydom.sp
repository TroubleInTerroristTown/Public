#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME_I "md_i"
#define SHORT_NAME_T "md_t"
#define SHORT_NAME_D "md_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Martydom"

char g_sLongName[PLATFORM_MAX_PATH];
char g_sPluginTag[PLATFORM_MAX_PATH];
char g_sConfigFile[PLATFORM_MAX_PATH];

float g_fDeathPos[MAXPLAYERS+1][3];
float g_fGrenadeDelay = 0.25;
float g_fDamage = 99.0;
float g_fExplosionSize = 350.0;

int g_iIPrice = 0;
int g_iIPrio = 0;

int g_iDPrice = 0;
int g_iDPrio = 0;

int g_iTPrice = 0;
int g_iTPrio = 0;

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

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);

	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/martydom.cfg");
	Config_Setup("TTT-Martydom", g_sConfigFile);

	Config_LoadString("martydom_name", "Martydom", "The name of this item in the shop.", g_sLongName, sizeof(g_sLongName));
	
	g_iIPrice = Config_LoadInt("md_i_price", 2000, "The amount of credits martydom costs as innocent. 0 to disable.");	
	g_iTPrice = Config_LoadInt("md_t_price", 2000, "The amount of credits martydom costs as traitor. 0 to disable.");
	g_iDPrice = Config_LoadInt("md_d_price", 2000, "The amount of credits martydom costs as detective. 0 to disable.");
	
	g_iIPrio = Config_LoadInt("md_i_sort_prio", 0, "The sorting priority of the martydom in the shop menu for innocents.");
	g_iTPrio = Config_LoadInt("md_t_sort_prio", 0, "The sorting priority of the martydom in the shop menu for traitors.");
	g_iDPrio = Config_LoadInt("md_d_sort_prio", 0, "The sorting priority of the martydom in the shop menu for detectives.");
	
	g_fGrenadeDelay = Config_LoadFloat("md_grenade_delay", 0.25, "The time delay it takes for the grenade to spawn after a player dies. Decimals allowed. (Def. 0.25)");
	g_fDamage = Config_LoadFloat("md_grenade_damage", 99.0, "The damage the grenade does at the explosions center point. Decimals allowed. (Def. 99.0)");
	g_fExplosionSize = Config_LoadFloat("md_explosion_size", 350.0, "The size of the explosion. Decimals allowed. (Def. 350.0)");

	Config_Done();

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_RoundStart);
	
}

public void OnClientDisconnect(int client) {

	g_bHasMartydom[client] = false;

}

public void OnAllPluginsLoaded() {

	TTT_RegisterCustomItem(SHORT_NAME_I, g_sLongName, g_iIPrice, TTT_TEAM_INNOCENT, g_iIPrio);
	TTT_RegisterCustomItem(SHORT_NAME_T, g_sLongName, g_iTPrice, TTT_TEAM_TRAITOR, g_iTPrio);
	TTT_RegisterCustomItem(SHORT_NAME_D, g_sLongName, g_iDPrice, TTT_TEAM_DETECTIVE, g_iDPrio);
	
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort) {

	if (TTT_IsClientValid(client) && IsPlayerAlive(client)) {
	
		if (StrEqual(itemshort, SHORT_NAME, false)) {
		
			if(g_bHasMartydom[client]) {
			
				CPrintToChat(client, "%sYou already have purchased %s!", g_sPluginTag, g_sLongName);
				return Plugin_Stop;
			
			}
			
			g_bHasMartydom[client] = true;
			
		}
		
	}
	
	return Plugin_Continue;
}

public Action Timer_CreateGrenade(Handle timer, any client) {

	if(TTT_IsClientValid(client))
		CreateGrenade(client);

}

public Action Event_RoundStart(Handle event, const char[] name, bool inrestart) {

	LoopValidClients(i) {
	
		g_bHasMartydom[i] = false;
	
	}

}

public Action Event_PlayerDeath(Handle event, const char[] name, bool inrestart) {

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!TTT_IsClientValid(client))
		return Plugin_Continue;
		
	if(!g_bHasMartydom[client])
		return Plugin_Continue;
		
	GetClientAbsOrigin(client, g_fDeathPos[client]);
	CreateTimer(g_fGrenadeDelay, Timer_CreateGrenade, client);
	
	g_bHasMartydom[client] = false;
	
	return Plugin_Continue;
	
}

public void CreateGrenade(int client) {
	
	int entity = CreateEntityByName("hegrenade_projectile");
	DispatchSpawn(entity);
	
	// Make sure the grenade doesn't spawn in the ground
	g_fDeathPos[client][2] += 30;
	
	TeleportEntity(entity, g_fDeathPos[client], NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "InitializeSpawnFromWorld");
	
	SetEntPropEnt(entity, Prop_Data, "m_hThrower", client);
	SetEntProp(entity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
	SetEntPropFloat(entity, Prop_Data, "m_flDamage", g_fDamage);
	SetEntPropFloat(entity, Prop_Data, "m_DmgRadius", g_fExplosionSize); 

}
