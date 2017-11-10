#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <multicolors>
#include <emitsoundany>
#include <ttt_shop>
#include <ttt>

#define HEALTH_ITEM_SHORT "healthstation"
#define HURT_ITEM_SHORT "hurtstation"

#define SND_WARNING "resource/warning.wav"

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Health/Hurt Stations"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

int g_iStationCharges[MAXPLAYERS + 1] =  { 0, ... };
int g_iStationHealth[MAXPLAYERS + 1] =  { 0, ... };
bool g_bHasActiveStation[MAXPLAYERS + 1] =  { false, ... };
bool g_bOnHealingCoolDown[MAXPLAYERS + 1] =  { false, ... };
Handle g_hRemoveCoolDownTimer[MAXPLAYERS + 1] =  { null, ... };

ConVar g_cHealthPrice = null;
ConVar g_cHealthPrio = null;
ConVar g_cHealthHeal = null;
ConVar g_cHealthCharges = null;
ConVar g_cHurtPrice = null;
ConVar g_cHurtPrio = null;
ConVar g_cHurtDamage = null;
ConVar g_cHurtCharges = null;
ConVar g_cMaxHealth = null;
ConVar g_cHurtDistance = null;
ConVar g_cHealthDistance = null;
ConVar g_cHurtTraitors = null;
ConVar g_cHurt = null;
ConVar g_cHealth = null;

char g_sPluginTag[64];

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	LoadTranslations("ttt.phrases");

	StartConfig("stations");
	CreateConVar("ttt2_stations_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cHealthPrice = AutoExecConfig_CreateConVar("health_station_price", "3000", "The price of the Health Station in the shop for detectives. 0 to disable.");
	g_cHurtPrice = AutoExecConfig_CreateConVar("hurt_station_price", "0", "The price of the Hurt Station in the shop for traitors. 0 to disable. Recommended is double health price.");
	g_cHealthPrio = AutoExecConfig_CreateConVar("health_sort_prio", "0", "The sorting priority of the Health Station in the shop menu.");
	g_cHurtPrio = AutoExecConfig_CreateConVar("hurt_sort_prio", "0", "The sorting priority of the Hurt Station in the shop menu.");
	g_cHealthHeal = AutoExecConfig_CreateConVar("health_station_heal", "15", "The amount of health the health station should heal each second.");
	g_cHurtDamage = AutoExecConfig_CreateConVar("hurt_station_damage", "25", "The damage the hurt station should do each second.");
	g_cHealthCharges = AutoExecConfig_CreateConVar("health_station_charges", "10", "The amount of charges that the health station should start off with.");
	g_cHurtCharges = AutoExecConfig_CreateConVar("hurt_station_charges", "15", "The amount of charges that the hurt station should start off with.");
	g_cHealthDistance = AutoExecConfig_CreateConVar("health_station_distance", "200.0", "The distance that the health station should reach.");
	g_cHurtDistance = AutoExecConfig_CreateConVar("hurt_station_distance", "200.0", "The distance that the hurt station should reach.");
	g_cHurtTraitors = AutoExecConfig_CreateConVar("hurt_station_hurt_other_traitors", "0", "Hurt other traitors with a hurtstation?", _, true, 0.0, true, 1.0);
	g_cMaxHealth = AutoExecConfig_CreateConVar("health_station_max_health", "125", "What's the max health for a health station that the player can get?");
	g_cHealth = AutoExecConfig_CreateConVar("health_station_name", "Health Station", "The name of the health station in the menu.");
	g_cHurt = AutoExecConfig_CreateConVar("hurt_station_name", "Hurt Station", "The name of the hurt station in the menu.");
	EndConfig();

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnMapStart()
{
	PrecacheSoundAny(SND_WARNING, true);
}

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cHealth.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(HEALTH_ITEM_SHORT, sBuffer, g_cHealthPrice.IntValue, TTT_TEAM_DETECTIVE, g_cHealthPrio.IntValue);
	
	g_cHurt.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(HURT_ITEM_SHORT, sBuffer, g_cHurtPrice.IntValue, TTT_TEAM_TRAITOR, g_cHurtPrio.IntValue);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		bool hurt = (strcmp(itemshort, HURT_ITEM_SHORT, false) == 0);
		bool health = (strcmp(itemshort, HEALTH_ITEM_SHORT, false) == 0);

		if (hurt || health)
		{
			if (health && (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE))
			{
				return Plugin_Stop;
			}

			if (hurt && (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR))
			{
				return Plugin_Stop;
			}

			if (g_bHasActiveStation[client])
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "You already have an active Station", client);

				return Plugin_Stop;
			}

			spawnStation(client);
		}
	}

	return Plugin_Continue;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	cleanupStation();
}

public void TTT_OnUpdate1(int i)
{
	if (!IsPlayerAlive(i) || TTT_GetClientRole(i) < TTT_TEAM_INNOCENT)
	{
		return;
	}

	checkDistanceFromStation(i);
}

public void TTT_OnUpdate5(int i)
{
	if (!TTT_IsClientValid(i) || !IsPlayerAlive(i))
	{
		return;
	}

	if (g_bHasActiveStation[i] && g_iStationCharges[i] < 9)
	{
		g_iStationCharges[i]++;
	}
}

public void OnClientDisconnect(int client)
{
	ClearTimer(g_hRemoveCoolDownTimer[client]);
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}

public Action removeCoolDown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_bOnHealingCoolDown[client] = false;
	g_hRemoveCoolDownTimer[client] = null;
	return Plugin_Stop;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	cleanupStation();

	return Plugin_Continue;
}

public Action OnTakeDamageStation(int stationIndex, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidEntity(stationIndex) || stationIndex == INVALID_ENT_REFERENCE || stationIndex <= MaxClients || iAttacker < 1 || iAttacker > MaxClients || !IsClientInGame(iAttacker))
	{
		return Plugin_Continue;
	}

	int owner = GetEntProp(stationIndex, Prop_Send, "m_hOwnerEntity");
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
	{
		return Plugin_Continue;
	}

	g_iStationHealth[owner]--;

	if (g_iStationHealth[owner] <= 0)
	{
		AcceptEntityInput(stationIndex, "Kill");
		g_bHasActiveStation[owner] = false;
	}
	return Plugin_Continue;
}

void checkDistanceFromStation(int client)
{
	if (!IsPlayerAlive(client))
	{
		return;
	}

	float clientPos[3];
	float stationPos[3];
	int curHealth;
	int newHealth;
	int iEnt;
	char sModelName[PLATFORM_MAX_PATH];

	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics_multiplayer")) != -1)
	{
		int owner = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");
		if (!TTT_IsClientValid(owner))
		{
			continue;
		}

		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "microwave") == -1)
		{
			continue;
		}

		bool hurt = (TTT_GetClientRole(owner) == TTT_TEAM_TRAITOR);

		GetClientEyePosition(client, clientPos);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", stationPos);

		if (GetVectorDistance(clientPos, stationPos) > (hurt ? g_cHurtDistance.FloatValue : g_cHealthDistance.FloatValue))
		{
			continue;
		}

		if (g_bOnHealingCoolDown[client])
		{
			continue;
		}

		curHealth = GetClientHealth(client);

		if (!g_cHurtTraitors.BoolValue && hurt && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		{
			continue;
		}

		if ((!hurt) && (curHealth >= g_cMaxHealth.IntValue))
		{
			continue;
		}

		if (g_iStationCharges[owner] > 0 && ((hurt == false) || (client != owner)))
		{
			newHealth = (hurt ? (curHealth - g_cHurtDamage.IntValue) : (curHealth + g_cHealthHeal.IntValue));
			if (newHealth >= 125)
			{
				SetEntityHealth(client, 125);
			}
			else if (newHealth <= 0)
			{
				ForcePlayerSuicide(client);
			}
			else
			{
				SetEntityHealth(client, newHealth);
			}

			if (!hurt)
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "Healing From", client, owner);
			}

			EmitSoundToClientAny(client, SND_WARNING);
			g_iStationCharges[owner]--;
			g_bOnHealingCoolDown[client] = true;
			g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			if (!hurt)
			{
				CPrintToChat(client, g_sPluginTag, "Health Station Out Of Charges", client);
				g_bOnHealingCoolDown[client] = true;
				g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

void spawnStation(int client)
{
	if (!IsPlayerAlive(client))
	{
		return;
	}

	int iStation = CreateEntityByName("prop_physics_multiplayer");
	if (iStation != -1)
	{
		int role = TTT_GetClientRole(client);
		float clientPos[3];
		GetClientAbsOrigin(client, clientPos);
		SetEntProp(iStation, Prop_Send, "m_hOwnerEntity", client);
		DispatchKeyValue(iStation, "model", "models/props/cs_office/microwave.mdl");
		DispatchSpawn(iStation);
		SDKHook(iStation, SDKHook_OnTakeDamage, OnTakeDamageStation);
		TeleportEntity(iStation, clientPos, NULL_VECTOR, NULL_VECTOR);
		g_iStationHealth[client] = 10;
		g_bHasActiveStation[client] = true;
		g_iStationCharges[client] = ((role == TTT_TEAM_TRAITOR) ? g_cHurtCharges.IntValue : g_cHealthCharges.IntValue);
		CPrintToChat(client, "%s %T", g_sPluginTag, ((role == TTT_TEAM_TRAITOR) ? "Hurt Station Deployed" : "Health Station Deployed"), client);
	}
}

void cleanupStation()
{
	LoopValidClients(i)
	{
		g_iStationCharges[i] = 0;
		g_bHasActiveStation[i] = false;
		g_bOnHealingCoolDown[i] = false;

		ClearTimer(g_hRemoveCoolDownTimer[i]);
	}
}
