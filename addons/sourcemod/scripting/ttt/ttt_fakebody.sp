#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME "fb"
#define LONG_NAME "Fakebody"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Fake Body"

int g_iPrice = 0;

int g_iCount = 0;
int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };

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
	
	LoadTranslations("ttt_fakebody.phrases");
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/taser.cfg");
	Config_Setup("TTT-Taser", g_sConfigFile);
	
	g_iPrice = Config_LoadInt("fb_price", 9000, "The amount of credits a fake body costs as traitor. 0 to disable.");
	
	g_iCount = Config_LoadInt("fb__count", 1, "The amount of usages for fake bodys per round as traitor. 0 to disable.");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnClientDisconnect(int client)
{
	ResetFB(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
		ResetFB(client);
}

public void OnAllPluginsLoaded()
{
	if (g_iPrice > 0)
		TTT_RegisterCustomItem(SHORT_NAME, LONG_NAME, g_iPrice, TTT_TEAM_TRAITOR);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			if (g_iPCount[client] >= g_iCount)
				return Plugin_Stop;
			
			if (!SpawnFakeBody(client))
				return Plugin_Stop;
			
			g_iPCount[client]++;
		}
	}
	return Plugin_Continue;
}

void ResetFB(int client)
{
	g_iPCount[client] = 0;
}

stock bool SpawnFakeBody(int client)
{
	char sModel[256];
	float pos[3];
	char sName[32];
	
	GetClientModel(client, sModel, sizeof(sModel));
	GetClientEyePosition(client, pos);
	Format(sName, sizeof(sName), "fake_body_%d", GetClientUserId(client));
	
	int iEntity = CreateEntityByName("prop_ragdoll");
	DispatchKeyValue(iEntity, "model", sModel); //TODO: Add option to change model (random model)
	DispatchKeyValue(iEntity, "targetname", sName);
	SetEntProp(iEntity, Prop_Data, "m_nSolidType", 6);
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 2);
	
	if (DispatchSpawn(iEntity))
	{
		pos[2] -= 16.0;
		TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);
	}
	
	int iRagdollC[Ragdolls];
	iRagdollC[Ent] = EntIndexToEntRef(iEntity);
	iRagdollC[Victim] = 0;
	Format(iRagdollC[VictimName], MAX_NAME_LENGTH, "Fake!");
	iRagdollC[Scanned] = false;
	iRagdollC[Attacker] = 0;
	Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, "Fake!");
	iRagdollC[GameTime] = 0.0;
	Format(iRagdollC[Weaponused], MAX_NAME_LENGTH, "Fake!");
	
	TTT_SetRagdoll(iRagdollC[0]);
	
	return true;
}

public Action TTT_OnBodyChecked(int client, int[] iRagdollC) {
	if (!TTT_IsClientValid(client))
		return Plugin_Continue;
	
	if(StrEqual(iRagdollC[VictimName], "Fake!", false))
	{
		if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			return Plugin_Stop;
		
		LoopValidClients(j)
 						CPrintToChat(j, g_iConfig[s_pluginTag], "Found Fake", j, client);
		AcceptEntityInput(iRagdollC[Ent], "Kill");
		return Plugin_Stop;
	}
	return Plugin_Continue;
} 