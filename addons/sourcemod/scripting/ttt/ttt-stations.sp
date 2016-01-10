#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>

#include <ttt>
#include <config_loader>
#include <multicolors>
#include <emitsoundany>

#define HEALTH_ITEM_SHORT "hlthstat"
#define HURT_ITEM_SHORT "hurtstat"

#define SND_WARNING "resource/warning.wav"


int g_iHealthStationCharges[MAXPLAYERS + 1] =  { 0, ... };
int g_iHealthStationHealth[MAXPLAYERS + 1] =  { 0, ... };
bool g_bHasActiveHealthStation[MAXPLAYERS + 1] =  { false, ... };
bool g_bOnHealingCoolDown[MAXPLAYERS + 1] =  { false, ... };
Handle g_hRemoveCoolDownTimer[MAXPLAYERS + 1] =  { null, ... };

int g_iHealthPrice;
int g_iHealthHeal;
int g_iHealthCharges;
int g_iHurtPrice;
int g_iHurtDamage;
int g_iHurtCharges;
float g_fHurtDistance;
float g_fHealthDistance;

char g_cHurt[64];
char g_cHealth[64];
char g_cConfigFile[PLATFORM_MAX_PATH];

char g_sPluginTag[64];

public void OnPluginStart(){
	TTT_IsGameCSGO();
	LoadTranslations("ttt.phrases");

	BuildPath(Path_SM, g_cConfigFile, sizeof(g_cConfigFile), "configs/ttt/stations.cfg");
	Config_Setup("TTT-Stations", g_cConfigFile);
	g_iHealthPrice = Config_LoadInt("health_station_price", 3000, "The price of the Health Station in the shop for traitors. 0 to disable.");
	g_iHurtPrice = Config_LoadInt("hurt_station_price", 0, "The price of the Hurt Station in the shop for traitors. 0 to disable. Recommended is double health price.");


	g_iHealthHeal = Config_LoadInt("health_station_heal", 15, "The amount of health the health station should heal each second.");
	g_iHurtDamage = Config_LoadInt("hurt_station_damage", 25, "The damage the hurt station should do each second.");

	g_iHealthCharges = Config_LoadInt("health_station_charges", 10, "The amount of charges that the health station should start off with.");
	g_iHurtCharges = Config_LoadInt("hurt_station_charges", 15, "The amount of charges that the hurt station should start off with.");

	g_fHealthDistance = Config_LoadFloat("health_station_distance", 200.0, "The distance that the health station should reach.");
	g_fHurtDistance = Config_LoadFloat("hurt_station_distance", 200.0, "The distance that the hurt station should reach.");

	Config_LoadString("health_station_name", "Health Station", "The name of the health station in the menu.", g_cHealth, sizeof(g_cHealth));
	Config_LoadString("hurt_station_name", "Hurt Station", "The name of the hurt station in the menu.", g_cHurt, sizeof(g_cHurt));

	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));

	CreateTimer(1.0, Timer_1, _, TIMER_REPEAT);
	CreateTimer(5.0, Timer_5, _, TIMER_REPEAT);

	HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnMapStart(){
	PrecacheSoundAny(SND_WARNING, true);
}

public void OnAllPluginsLoaded(){
	if(g_iHealthPrice > 0)
		TTT_RegisterCustomItem(HEALTH_ITEM_SHORT, g_cHealth, g_iHealthPrice, TTT_TEAM_DETECTIVE);

	if(g_iHurtPrice > 0)
		TTT_RegisterCustomItem(HURT_ITEM_SHORT, g_cHurt, g_iHurtPrice, TTT_TEAM_TRAITOR);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort){
	if(TTT_IsClientValid(client) && IsPlayerAlive(client)){
		bool hurt = (strcmp(itemshort, HURT_ITEM_SHORT, false) == 0);
		bool health = (strcmp(itemshort, HEALTH_ITEM_SHORT, false) == 0);
		if(hurt || health){
			if(g_bHasActiveHealthStation[client]){
				CPrintToChat(client, g_sPluginTag, "You already have an active Health Station", client);
				return Plugin_Stop;
			}

			if(health && (TTT_GetClientRole(client) != TTT_TEAM_DETECTIVE))
				return Plugin_Stop;

			if(hurt && (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR))
				return Plugin_Stop;

			spawnHealthStation(client);
		}
	}

	return Plugin_Continue;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast){
	healthStation_cleanUp();
}

public Action Timer_1(Handle timer){
	LoopValidClients(i){
		if (!IsPlayerAlive(i))
			continue;

		checkDistanceFromHealthStation(i);
	}

	return Plugin_Continue;
}

public Action Timer_5(Handle timer){
	LoopValidClients(i){
		if (!IsPlayerAlive(i))
			continue;

		if (g_bHasActiveHealthStation[i] && g_iHealthStationCharges[i] < 9)
			g_iHealthStationCharges[i]++;
	}
}

public void OnClientDisconnect(int client){
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

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason){
	healthStation_cleanUp();

	return Plugin_Continue;
}

public Action OnTakeDamageHealthStation(int stationIndex, int &iAttacker, int &inflictor, float &damage, int &damagetype){
	if (!IsValidEntity(stationIndex) || stationIndex == INVALID_ENT_REFERENCE || stationIndex <= MaxClients || iAttacker < 1 || iAttacker > MaxClients || !IsClientInGame(iAttacker))
		return Plugin_Continue;

	int owner = GetEntProp(stationIndex, Prop_Send, "m_hOwnerEntity");
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
		return Plugin_Continue;

	g_iHealthStationHealth[owner]--;

	if (g_iHealthStationHealth[owner] <= 0)
	{
		AcceptEntityInput(stationIndex, "Kill");
		g_bHasActiveHealthStation[owner] = false;
	}
	return Plugin_Continue;
}

void checkDistanceFromHealthStation(int client){
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	float clientPos[3], stationPos[3];
	int curHealth, newHealth, iEnt;
	char sModelName[PLATFORM_MAX_PATH];
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics_multiplayer")) != -1)
	{
		int owner = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");
		if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
			continue;

		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "microwave") == -1)
			continue;

		bool hurt = (TTT_GetClientRole(owner) == TTT_TEAM_TRAITOR);

		GetClientEyePosition(client, clientPos);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", stationPos);

		if (GetVectorDistance(clientPos, stationPos) > (hurt ? g_fHurtDistance : g_fHealthDistance))
			continue;

		if (g_bOnHealingCoolDown[client]) continue;
		curHealth = GetClientHealth(client);

		if ((!hurt) && (curHealth >= 125)) continue;

		if (g_iHealthStationCharges[owner] > 0)
		{
			newHealth = (hurt ? (curHealth - g_iHurtDamage) : (curHealth + g_iHealthHeal));
			if (newHealth >= 125)
				SetEntityHealth(client, 125);
			else if (newHealth <= 0)
				ForcePlayerSuicide(client);
			else
				SetEntityHealth(client, newHealth);

			if(!hurt)
				CPrintToChat(client, g_sPluginTag, "Healing From", client, owner);

			EmitSoundToClientAny(client, SND_WARNING);
			g_iHealthStationCharges[owner]--;
			g_bOnHealingCoolDown[client] = true;
			g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			if(!hurt){
				CPrintToChat(client, g_sPluginTag, "Health Station Out Of Charges", client);
				g_bOnHealingCoolDown[client] = true;
				g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

void spawnHealthStation(int client){
	if (!IsPlayerAlive(client))
		return;

	int healthStationIndex = CreateEntityByName("prop_physics_multiplayer");
	if (healthStationIndex != -1)
	{
		float clientPos[3];
		GetClientAbsOrigin(client, clientPos);
		SetEntProp(healthStationIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchKeyValue(healthStationIndex, "model", "models/props/cs_office/microwave.mdl");
		DispatchSpawn(healthStationIndex);
		SDKHook(healthStationIndex, SDKHook_OnTakeDamage, OnTakeDamageHealthStation);
		TeleportEntity(healthStationIndex, clientPos, NULL_VECTOR, NULL_VECTOR);
		g_iHealthStationHealth[client] = 10;
		g_bHasActiveHealthStation[client] = true;
		g_iHealthStationCharges[client] = ((TTT_GetClientRole(client) == TTT_TEAM_TRAITOR) ? g_iHurtCharges : g_iHealthCharges);
		CPrintToChat(client, g_sPluginTag, ((TTT_GetClientRole(client) == TTT_TEAM_TRAITOR) ? "Health Station Deployed" : "Hurt Station Deployed"), client);
	}
}

void healthStation_cleanUp(){
	LoopValidClients(i)
	{
		g_iHealthStationCharges[i] = 0;
		g_bHasActiveHealthStation[i] = false;
		g_bOnHealingCoolDown[i] = false;

		ClearTimer(g_hRemoveCoolDownTimer[i]);
	}
}
