#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Poison Smoke"
#define SHORT_NAME "posion_smoke"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;
ConVar g_cOwnDamage = null;
ConVar g_cTraitorDamage = null;
ConVar g_cDistance = null;
ConVar g_cDamageInterval = null;
ConVar g_cDamage = null;

bool g_bPoison[MAXPLAYERS + 1] =  { false, ... };
bool g_bActivePoison[MAXPLAYERS + 1] =  { false, ... };

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
	
	TTT_StartConfig("posion_smoke");
	CreateConVar("ttt2_posion_smoke_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("posion_smoke_name", "Poison Smoke", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("posion_smoke_price", "9000", "The amount of credits poison smoke costs as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("posion_smoke_sort_prio", "0", "The sorting priority of the poison smoke in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("posion_smoke_discount", "0", "Should poison smoke discountable?", _, true, 0.0, true, 1.0);
	g_cOwnDamage = AutoExecConfig_CreateConVar("poison_smoke_own_damange", "0", "Allow damage to the owner of poison smoke?", _, true, 0.0, true, 1.0);
	g_cTraitorDamage = AutoExecConfig_CreateConVar("poison_smoke_traitor_damange", "1", "Allow damage to other traitors?", _, true, 0.0, true, 1.0);
	g_cDistance = AutoExecConfig_CreateConVar("poison_smoke_distance", "145", "Distance from the middle which should do damage");
	g_cDamageInterval = AutoExecConfig_CreateConVar("poison_smoke_damage_interval", "1.0", "Damage interval in seconds", _, true, 1.0);
	g_cDamage = AutoExecConfig_CreateConVar("poison_smoke_damage_per_interval", "10", "Damage per interval by poison smoke");
	TTT_EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Post);
	HookEvent("smokegrenade_expired", Event_SmokeExpired);
}

public void OnConfigsExecuted()
{
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
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

public void OnClientDisconnect(int client)
{
	ResetStuff(client);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}
			
			if (g_bPoison[client] || g_bActivePoison[client])
			{
				return Plugin_Stop;
			}
			
			GivePlayerItem(client, "weapon_smokegrenade");
			g_bPoison[client] = true;
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetStuff(client);
	}
}

public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int entity = event.GetInt("entityid");
	
	if (!TTT_IsClientValid(client) || !IsValidEntity(entity))
	{
		return Plugin_Continue;
	}
	
	if (!g_bPoison[client] || g_bActivePoison[client])
	{
		return Plugin_Continue;
	}
	
	float fOrigin[3];
	fOrigin[0] = event.GetFloat("x");
	fOrigin[1] = event.GetFloat("y");
	fOrigin[2] = event.GetFloat("z");
	
	g_bPoison[client] = false;
	g_bActivePoison[client] = true;
	
	DataPack pack = new DataPack();
	CreateDataTimer(g_cDamageInterval.FloatValue, Timer_CheckPlayers, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(entity));
	
	return Plugin_Continue;
}

public Action Timer_CheckPlayers(Handle timer, any pack)
{
	ResetPack(pack);
	
	int attacker = GetClientOfUserId(ReadPackCell(pack));
	int entity = EntRefToEntIndex(ReadPackCell(pack));
	
	if (TTT_IsClientValid(attacker) && IsValidEntity(entity))
	{
		if (!g_bActivePoison[attacker])
		{
			return Plugin_Stop;
		}
		
		float fEOrigin[3], fCOrigin[3], fDistance;
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEOrigin);
		
		LoopValidClients(victim)
		{
			if (IsPlayerAlive(victim))
			{
				GetClientAbsOrigin(victim, fCOrigin);
				fDistance = GetVectorDistance(fEOrigin, fCOrigin);
				
				if (!g_cOwnDamage.BoolValue && victim == attacker)
				{
					continue;
				}
				
				if (!g_cTraitorDamage.BoolValue && TTT_GetClientRole(victim) == TTT_TEAM_TRAITOR)
				{
					continue;
				}
				
				if (fDistance <= g_cDistance.FloatValue)
				{
					SDKHooks_TakeDamage(victim, entity, attacker, g_cDamage.FloatValue, DMG_POISON, entity);
				}
			}
		}
		
		DataPack pack2 = new DataPack();
		CreateDataTimer(g_cDamageInterval.FloatValue, Timer_CheckPlayers, pack2, TIMER_FLAG_NO_MAPCHANGE);
		pack2.WriteCell(GetClientUserId(attacker));
		pack2.WriteCell(EntIndexToEntRef(entity));
	}
	
	return Plugin_Stop;
}

public Action Event_SmokeExpired(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		ResetStuff(client);
	}
	
	return Plugin_Continue;
}

void ResetStuff(int client)
{
	g_bPoison[client] = false;
	g_bActivePoison[client] = false;
}
