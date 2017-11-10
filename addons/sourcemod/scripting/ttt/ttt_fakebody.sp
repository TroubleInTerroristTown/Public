#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "fakebody"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Fake Body"

#define COLLISION_GROUP_DEBRIS_TRIGGER 2

ConVar g_cPrice = null;
ConVar g_cShowFakeMessage = null;
ConVar g_cDeleteFakeBodyAfterFound = null;
ConVar g_cAllowProofByTraitors = null;
ConVar g_cShowTraitorAsDead = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;

int g_iPCount[MAXPLAYERS + 1] =  { 0, ... };
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

int g_iCollisionGroup = -1;

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

	StartConfig("fakebody");
	CreateConVar("ttt2_fakebody_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("fb_name", "Fakebody", "The name of the Fakebody in the Shop");
	g_cPrice = AutoExecConfig_CreateConVar("fb_price", "9000", "The amount of credits a fake body costs as traitor. 0 to disable.");
	g_cCount = AutoExecConfig_CreateConVar("fb_count", "1", "The amount of usages for fake bodys per round as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("fb_sort_prio", "0", "The sorting priority of the fake body in the shop menu.");
	g_cAllowProofByTraitors = AutoExecConfig_CreateConVar("fb_allow_proof_by_all", "1", "Allow fake body scan for traitors players?");
	g_cShowFakeMessage = AutoExecConfig_CreateConVar("fb_show_fake_message", "0", "Show the fake message (XXX has found a fake body)?");
	g_cDeleteFakeBodyAfterFound = AutoExecConfig_CreateConVar("fb_delete_fakebody_after_found", "0", "Delete fake body after found?");
	g_cShowTraitorAsDead = AutoExecConfig_CreateConVar("fb_show_traitor_as_dead", "1", "Show traitor as dead after fakebody found?");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);

	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
}

public void OnClientDisconnect(int client)
{
	ResetFB(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetFB(client);
	}
}

public void OnConfigsExecuted()
{
	ConVar hTag = FindConVar("ttt_plugin_tag");
	hTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			if (g_iPCount[client] >= g_cCount.IntValue)
			{
				char sBuffer[MAX_ITEM_LENGTH];
				g_cLongName.GetString(sBuffer, sizeof(sBuffer));
				
				CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cCount.IntValue);
				return Plugin_Stop;
			}

			if (!SpawnFakeBody(client))
			{
				return Plugin_Stop;
			}

			if (count)
			{
				g_iPCount[client]++;
			}
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
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 5);

	if (DispatchSpawn(iEntity))
	{
		pos[2] -= 16.0;
		TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);

		SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	
		int iRagdollC[Ragdolls];
		iRagdollC[Ent] = EntIndexToEntRef(iEntity);
		iRagdollC[Victim] = GetClientUserId(client);
		iRagdollC[VictimTeam] = TTT_GetClientRole(client);
		GetClientName(client, iRagdollC[VictimName], MAX_NAME_LENGTH);
		iRagdollC[Scanned] = false;
		iRagdollC[Attacker] = 0;
		iRagdollC[AttackerTeam] = TTT_TEAM_TRAITOR;
		Format(iRagdollC[AttackerName], MAX_NAME_LENGTH, "Fake!");
		iRagdollC[GameTime] = 0.0;
		Format(iRagdollC[Weaponused], MAX_NAME_LENGTH, "Fake!");
		iRagdollC[Found] = false;
	
		TTT_SetRagdoll(iRagdollC[0]);
	
		return true;
	}
	
	return false;
}

public Action TTT_OnBodyChecked(int client, int[] iRagdollC)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if (StrEqual(iRagdollC[Weaponused], "Fake!", false))
	{
		if (!g_cAllowProofByTraitors.BoolValue)
		{
			if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
		}

		LoopValidClients(j)
		{
			if (g_cShowFakeMessage.BoolValue&& !iRagdollC[Found])
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Found Fake", j, client);
			}
			else if (!g_cShowFakeMessage.BoolValue && !iRagdollC[Found])
			{
				CPrintToChat(j, "%s %T", g_sPluginTag, "Found Traitor", j, client, iRagdollC[VictimName]);
			}
			else if (iRagdollC[Found])
			{
				return Plugin_Stop;
			}
		}

		if (g_cShowTraitorAsDead.BoolValue)
		{
			TTT_SetFoundStatus(iRagdollC[Victim], true);
		}

		iRagdollC[Found] = true;

		if (g_cDeleteFakeBodyAfterFound.BoolValue)
		{
			AcceptEntityInput(iRagdollC[Ent], "Kill");
		}

		if (!g_cDeleteFakeBodyAfterFound .BoolValue&& !g_cShowFakeMessage.BoolValue)
		{
			SetEntityRenderColor(iRagdollC[Ent], 255, 0, 0, 255);
		}

		return Plugin_Changed;
	}
	return Plugin_Continue;
}

stock void SetNoBlock(int client)
{
	SetEntData(client, g_iCollisionGroup, 2, 4, true);
}
