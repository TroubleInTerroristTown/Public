#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <multicolors>
#include <emitsoundany>
#include <cstrike>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - C4 & Jihad"
#define SHORT_NAME_C4 "c4"
#define SHORT_NAME_J "jihad"

#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"
#define SND_BEEP "weapons/c4/c4_beep1.wav"
#define SND_DISARM "weapons/c4/c4_disarm.wav"

#define MDL_C4 "models/weapons/w_c4_planted.mdl"

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

ConVar g_cRemoveBomb = null;
ConVar g_cSlayPlayer = null;
ConVar g_cPrice_C4 = null;
ConVar g_cPrio_C4 = null;
ConVar g_cCount_C4 = null;
ConVar g_cC4ShakeRadius = null;
ConVar g_cPrice_J = null;
ConVar g_cPrio_J = null;
ConVar g_cLongName_C4 = null;
ConVar g_cLongName_J = null;
ConVar g_cJihadPreparingTime = null;
ConVar g_cC4DamageRadius = null;
ConVar g_cC4Magnitude = null;
ConVar g_cC4KillRadius = null;
ConVar g_cJihadDamageRadius = null;
ConVar g_cJihadMagnitude = null;

int g_iPCount_C4[MAXPLAYERS + 1] =  { 0, ... };
int g_iDefusePlayerIndex[MAXPLAYERS + 1] =  { -1, ... };
int g_iWire[MAXPLAYERS + 1] =  { 0, ... };

bool g_bHasC4[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasJihad[MAXPLAYERS + 1] =  { false, ... };
bool g_bDetonate[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasActiveBomb[MAXPLAYERS + 1] =  { false, ... };

Handle g_hExplosionTimer[MAXPLAYERS + 1] =  { null, ... };
Handle g_hJihadBomb[MAXPLAYERS + 1] =  { null, ... };



char g_sPlantSeconds[][] = {
	"10",
	"20",
	"30",
	"40",
	"50",
	"60"
};

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

	g_cLongName_C4 = AutoExecConfig_CreateConVar("c4_name", "C4", "The name of the C4 in the Shop");
	g_cPrice_C4 = AutoExecConfig_CreateConVar("c4_price", "9000", "The amount of credits a c4 costs as traitor. 0 to disable.");
	g_cPrio_C4 = AutoExecConfig_CreateConVar("c4_sort_prio", "0", "The sorting priority of the C4 in the shop menu.");
	g_cCount_C4 = AutoExecConfig_CreateConVar("c4_count", "9000", "The amount of c4's a traitor can buy.");
	g_cC4ShakeRadius = AutoExecConfig_CreateConVar("c4_shake_radius", "5000", "The 'shake' radius of the C4 explosion.");
	g_cC4DamageRadius = AutoExecConfig_CreateConVar("c4_damage_radius", "850", "The damage radius of the C4 explosion.");
	g_cLongName_J = AutoExecConfig_CreateConVar("jihad_name", "Jihad Bomb", "The name of the Jihad in the Shop");
	g_cPrice_J = AutoExecConfig_CreateConVar("jihad_price", "9000", "The amount of credits a jihad costs as traitor. 0 to disable.");
	g_cPrio_J = AutoExecConfig_CreateConVar("jihad_sort_prio", "0", "The sorting priority of the Jihad in the shop menu.");
	g_cJihadPreparingTime = AutoExecConfig_CreateConVar("jihad_preparing_time", "60.0", "The amount of time in seconds until the jihad bomb is ready after buying it.");
	g_cRemoveBomb = AutoExecConfig_CreateConVar("remove_bomb_on_spawn", "1", "Remove the bomb from the map to prevent interference. 1 = Remove, 0 = Don't Remove", _, true, 0.0, true, 1.0);
	g_cJihadDamageRadius = AutoExecConfig_CreateConVar("jihad_damage_radius", "600", "The damage radius of the Jihad explosion.");
	g_cSlayPlayer = AutoExecConfig_CreateConVar("jihad_slay_player", "1", "Slay player on own jihad explosion?", _, true, 0.0, true, 1.0);
	g_cC4Magnitude = AutoExecConfig_CreateConVar("c4_magnitude", "850", "The amount of damage done by the explosion. For C4");
	g_cJihadMagnitude = AutoExecConfig_CreateConVar("jihad_magnitude", "1000", "The amount of damage done by the explosion. For Jihad");
	g_cC4KillRadius = AutoExecConfig_CreateConVar("c4_kill_radius", "275.0", "The kill radius of the C4 explosion.");


	AddCommandListener(Command_LAW, "+lookatweapon");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);

	LoadTranslations("ttt.phrases");
}

public void OnMapStart()
{
	PrecacheSoundAny(SND_BLIP, true);
	PrecacheSoundAny(SND_BURST, true);
	PrecacheSoundAny(SND_BEEP, true);
	PrecacheSoundAny(SND_DISARM, true);

	PrecacheModel("weapons/w_c4_planted.mdl", true);

	PrecacheSoundAny("ttt/jihad/explosion.mp3", true);
	PrecacheSoundAny("ttt/jihad/jihad.mp3", true);

	AddFileToDownloadsTable("sound/ttt/jihad/explosion.mp3");
	AddFileToDownloadsTable("sound/ttt/jihad/jihad.mp3");
}

public void OnClientDisconnect(int client)
{
	ResetGlobals(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetGlobals(client);
	}
}

public Action Event_PlayerDeath(Event event, const char[] menu, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		ResetJihad(client);
	}
}

public void OnConfigsExecuted()
{
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[MAX_ITEM_LENGTH];
	
	g_cLongName_C4.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_C4, sBuffer, g_cPrice_C4.IntValue, TTT_TEAM_TRAITOR, g_cPrio_C4.IntValue);
	
	g_cLongName_J.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME_J, sBuffer, g_cPrice_J.IntValue, TTT_TEAM_TRAITOR, g_cPrio_J.IntValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	}
}

public void ResetJihad(int client)
{
	g_bHasJihad[client] = false;
	g_bDetonate[client] = false;
	
	ClearTimer(g_hJihadBomb[client]);
}

public void ResetGlobals(int client)
{
	g_bHasC4[client] = false;
	g_bHasJihad[client] = false;
	g_bDetonate[client] = false;
	g_bHasActiveBomb[client] = false;
	
	g_iDefusePlayerIndex[client] = -1;
	g_iWire[client] = -1;
	g_iPCount_C4[client] = 0;
	
	ClearTimer(g_hExplosionTimer[client]);
	ClearTimer(g_hJihadBomb[client]);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME_C4, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR || g_bHasC4[client])
			{
				return Plugin_Stop;
			}
			if(g_iPCount_C4[client] >= g_cCount_C4.IntValue)
			{
				char sBuffer[MAX_ITEM_LENGTH];
				g_cLongName_C4.GetString(sBuffer, sizeof(sBuffer));
				
				CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cCount_C4.IntValue);
				return Plugin_Stop;
			}

			g_bHasC4[client] = true;

			if (count)
			{
				g_iPCount_C4[client]++;
			}

			CPrintToChat(client, "%s %T", g_sPluginTag, "Right click to plant the C4", client);
		}
		else if (StrEqual(itemshort, SHORT_NAME_J, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR || g_bHasJihad[client])
			{
				return Plugin_Stop;
			}


			ClearTimer(g_hJihadBomb[client]);
			g_hJihadBomb[client] = CreateTimer(g_cJihadPreparingTime.FloatValue, Timer_JihadPreparing, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			g_bHasJihad[client] = true;

			CPrintToChat(client, "%s %T", g_sPluginTag, "bomb will arm in 60 seconds, double tab F to explode", client);
		}
	}
	return Plugin_Continue;
}

public Action Timer_JihadPreparing(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if(!IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	CPrintToChat(client, "%s %T", g_sPluginTag, "Your bomb is now armed.", client);
	EmitAmbientSound(SND_BLIP, NULL_VECTOR, client);
	g_hJihadBomb[client] = null;
	return Plugin_Stop;
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cRemoveBomb.BoolValue)
	{
		return Plugin_Continue;
	}

	char sItem[32];
	event.GetString("item", sItem, sizeof(sItem));
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		RemoveC4(client);
	}
	return Plugin_Continue;
}

stock void RemoveC4(int client)
{
	if (!g_bHasC4[client] && !g_bHasJihad[client])
	{
		int weapon = -1;
		while((weapon = GetPlayerWeaponSlot(client, CS_SLOT_C4)) != -1)
		{
			char sWeapon[128];
			GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

			if (StrContains(sWeapon, "weapon_c4", false) != -1)
			{
				RemovePlayerItem(client, weapon);
				AcceptEntityInput(weapon, "Kill");

				break;
			}
		}
	}
}

stock void Detonate(int client)
{
	int ExplosionIndex = CreateEntityByName("env_explosion");
	if (ExplosionIndex != -1)
	{
		SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", g_cJihadMagnitude.IntValue);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", g_cJihadDamageRadius.IntValue);

		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);

		float playerEyes[3];
		GetClientEyePosition(client, playerEyes);

		TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client);

		EmitAmbientSoundAny("ttt/jihad/explosion.mp3", NULL_VECTOR, client, SNDLEVEL_RAIDSIREN);


		AcceptEntityInput(ExplosionIndex, "Explode");

		AcceptEntityInput(ExplosionIndex, "Kill");
		
		// Slay players
		if (g_cSlayPlayer.BoolValue&& IsPlayerAlive(client))
		{
			ForcePlayerSuicide(client);
		}
	}
	g_bHasJihad[client] = false;
}

public Action Command_Detonate(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!g_bHasJihad[client])
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "You dont have it!", client);
		return Plugin_Handled;
	}

	if (g_hJihadBomb[client] != null)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Your bomb is not armed.", client);
		return Plugin_Handled;
	}

	EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);

	CreateTimer(2.0, TimerCallback_Detonate, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	g_bHasJihad[client] = false;

	return Plugin_Handled;
}

public Action TimerCallback_Detonate(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		Detonate(client);
	}

	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if (IsPlayerAlive(client) && g_bHasJihad[client] && g_hJihadBomb[client] == null && g_bDetonate[client])
	{
		EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);

		CreateTimer(2.0, TimerCallback_Detonate, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		g_bHasJihad[client] = false;

		return Plugin_Continue;
	}
	else
	{
		g_bDetonate[client] = true;
		CreateTimer(2.0, Timer_Reset, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_Reset(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		g_bDetonate[client] = false;
	}

	return Plugin_Handled;
}

public Action explodeC4(Handle timer, Handle pack)
{
	int clientUserId;
	int bombEnt;
	ResetPack(pack);
	clientUserId = ReadPackCell(pack);
	bombEnt = ReadPackCell(pack);

	if (!IsValidEntity(bombEnt))
	{
		return Plugin_Stop;
	}

	int client = GetClientOfUserId(clientUserId);
	float explosionOrigin[3];
	GetEntPropVector(bombEnt, Prop_Send, "m_vecOrigin", explosionOrigin);
	if (TTT_IsClientValid(client))
	{
		g_bHasActiveBomb[client] = false;
		g_hExplosionTimer[client] = null;
		CPrintToChat(client, "%s %T", g_sPluginTag, "Bomb Detonated", client);
	}
	else
	{
		return Plugin_Stop;
	}

	int explosionIndex = CreateEntityByName("env_explosion");
	int particleIndex = CreateEntityByName("info_particle_system");
	int shakeIndex = CreateEntityByName("env_shake");
	if (explosionIndex != -1 && particleIndex != -1 && shakeIndex != -1)
	{
		char sShakeRadius[8];
		IntToString(g_cC4ShakeRadius.IntValue, sShakeRadius, sizeof(sShakeRadius));

		DispatchKeyValue(shakeIndex, "amplitude", "4");
		DispatchKeyValue(shakeIndex, "duration", "1");
		DispatchKeyValue(shakeIndex, "frequency", "2.5");
		DispatchKeyValue(shakeIndex, "radius", sShakeRadius);
		DispatchKeyValue(particleIndex, "effect_name", "explosion_c4_500");
		SetEntProp(explosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(explosionIndex, Prop_Data, "m_iRadiusOverride", g_cC4DamageRadius.IntValue);
		SetEntProp(explosionIndex, Prop_Data, "m_iMagnitude", g_cC4Magnitude.IntValue);
		SetEntPropEnt(explosionIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchSpawn(particleIndex);
		DispatchSpawn(explosionIndex);
		DispatchSpawn(shakeIndex);
		ActivateEntity(shakeIndex);
		ActivateEntity(particleIndex);
		ActivateEntity(explosionIndex);
		TeleportEntity(particleIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(explosionIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(shakeIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(bombEnt, "Kill");
		AcceptEntityInput(explosionIndex, "Explode");
		AcceptEntityInput(particleIndex, "Start");
		AcceptEntityInput(shakeIndex, "StartShake");
		AcceptEntityInput(explosionIndex, "Kill");

		LoopValidClients(i)
		{
			if (!IsPlayerAlive(i))
			{
				continue;
			}

			float clientOrigin[3];
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", clientOrigin);

			if (GetVectorDistance(clientOrigin, explosionOrigin) <= g_cC4KillRadius.FloatValue)
			{
				Handle killEvent = CreateEvent("player_death", true);
				SetEventInt(killEvent, "userid", GetClientUserId(i));
				SetEventInt(killEvent, "attacker", GetClientUserId(client));
				FireEvent(killEvent, false);
				ForcePlayerSuicide(i);
			}
		}

		for (int i = 1; i <= 2; i++)
		{
			EmitAmbientSoundAny(SND_BURST, explosionOrigin, _, SNDLEVEL_RAIDSIREN);
		}
	}
	return Plugin_Continue;
}

public int TTT_OnButtonPress(int client, int button)
{
	if (button & IN_ATTACK2 && !g_bHasActiveBomb[client] && g_bHasC4[client])
	{
		g_bHasActiveBomb[client] = true;
		int bombEnt = CreateEntityByName("prop_physics");
		if (bombEnt != -1)
		{
			float clientPos[3];
			GetClientAbsOrigin(client, clientPos);
			SetEntProp(bombEnt, Prop_Data, "m_CollisionGroup", 1);
			SetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity", client);
			DispatchKeyValue(bombEnt, "model", MDL_C4);
			if(DispatchSpawn(bombEnt))
			{
				TeleportEntity(bombEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
				showPlantMenu(client);
			}
		}
	}
	if (button & IN_RELOAD && g_iDefusePlayerIndex[client] == -1)
	{
		int target = GetClientAimTarget(client, false);
		if (target > 0)
		{
			float clientEyes[3], targetOrigin[3];
			GetClientEyePosition(client, clientEyes);
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetOrigin);
			if (GetVectorDistance(clientEyes, targetOrigin) > 100.0)
			{
				return;
			}

			int iEnt;
			while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
			{
				int planter = GetEntProp(target, Prop_Send, "m_hOwnerEntity");

				if (planter < 1 || planter > MaxClients || !IsClientInGame(planter))
				{
					return;
				}

				char sModelPath[PLATFORM_MAX_PATH];
				GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

				if(!StrEqual(MDL_C4, sModelPath))
				{
					return;
				}

				if (target == iEnt)
				{
					g_iDefusePlayerIndex[client] = planter;
					showDefuseMenu(client);
				}
			}
		}
	}
}

stock void showPlantMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	
	Handle menuHandle = CreateMenu(plantBombMenu);
	
	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%T", "Set C4 Timer", client);
	SetMenuTitle(menuHandle, sTitle);
	
	char sSeconds[64];
	for(int i; i < sizeof(g_sPlantSeconds); i++)
	{
		Format(sSeconds, sizeof(sSeconds), "%T", "Seconds", client, StringToInt(g_sPlantSeconds[i]));
		AddMenuItem(menuHandle, g_sPlantSeconds[i], sSeconds);
	}
	
	SetMenuPagination(menuHandle, 6);
	DisplayMenu(menuHandle, client, 10);
}

stock void showDefuseMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	char sTitle[128];
	char sWire1[64], sWire2[64], sWire3[64], sWire4[64];

	Format(sTitle, sizeof(sTitle), "%T", "Defuse C4", client);
	Format(sWire1, sizeof(sWire1), "%T", "C4 Wire", client, 1);
	Format(sWire2, sizeof(sWire2), "%T", "C4 Wire", client, 2);
	Format(sWire3, sizeof(sWire3), "%T", "C4 Wire", client, 3);
	Format(sWire4, sizeof(sWire4), "%T", "C4 Wire", client, 4);

	Handle menuHandle = CreateMenu(defuseBombMenu);
	SetMenuTitle(menuHandle, sTitle);
	AddMenuItem(menuHandle, "1", sWire1);
	AddMenuItem(menuHandle, "2", sWire2);
	AddMenuItem(menuHandle, "3", sWire3);
	AddMenuItem(menuHandle, "4", sWire4);
	SetMenuPagination(menuHandle, 4);
	DisplayMenu(menuHandle, client, 10);
}

public int plantBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	if (action == MenuAction_Select)
	{
		char info[100];
		GetMenuItem(menu, option, info, sizeof(info));
		
		for(int i; i < sizeof(g_sPlantSeconds); i++)
		{
			if (StrEqual(info, g_sPlantSeconds[i]))
			{
				plantBomb(client, StringToFloat(g_sPlantSeconds[i]));
				break;
			}
		}
		
		g_bHasC4[client] = false;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
		g_bHasActiveBomb[client] = false;
		removeBomb(client);
	}
	else if (action == MenuAction_Cancel)
	{
		g_bHasActiveBomb[client] = false;
		removeBomb(client);
	}
}

public int defuseBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	if (action == MenuAction_Select)
	{
		char info[100];
		int planter = g_iDefusePlayerIndex[client];
		g_iDefusePlayerIndex[client] = -1;

		if (planter < 1 || planter > MaxClients || !IsClientInGame(planter))
		{
			g_iDefusePlayerIndex[client] = -1;
			return;
		}

		int wire;
		int correctWire;
		int planterBombIndex = findBomb(planter);
		float bombPos[3];
		GetEntPropVector(planterBombIndex, Prop_Data, "m_vecOrigin", bombPos);
		correctWire = g_iWire[planter];
		GetMenuItem(menu, option, info, sizeof(info));
		wire = StringToInt(info);
		if (wire == correctWire)
		{
			if (1 <= planter <= MaxClients && IsClientInGame(planter))
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "You Defused Bomb", client, planter);
				CPrintToChat(planter, "%s %T", g_sPluginTag, "Has Defused Bomb", planter, client);
				EmitAmbientSoundAny(SND_DISARM, bombPos);
				g_bHasActiveBomb[planter] = false;
				ClearTimer(g_hExplosionTimer[planter]);
				SetEntProp(planterBombIndex, Prop_Send, "m_hOwnerEntity", -1);
			}
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Failed Defuse", client);
			ForcePlayerSuicide(client);
			g_iDefusePlayerIndex[client] = -1;
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
		g_iDefusePlayerIndex[client] = -1;
	}
	else if (action == MenuAction_Cancel)
	{
		g_iDefusePlayerIndex[client] = -1;
	}
}

stock float plantBomb(int client, float time)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Alive to Plant", client);
		return;
	}

	CPrintToChat(client, "%s %T", g_sPluginTag, "Will Explode In", client, time);

	bool bombFound;
	int bombEnt;
	while ((bombEnt = FindEntityByClassname(bombEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity") != client)
		{
			continue;
		}

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(bombEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if (!StrEqual(MDL_C4, sModelPath))
		{
			continue;
		}

		Handle explosionPack;
		Handle beepPack;
		
		ClearTimer(g_hExplosionTimer[client]);
		
		g_hExplosionTimer[client] = CreateDataTimer(time, explodeC4, explosionPack, TIMER_FLAG_NO_MAPCHANGE);
		CreateDataTimer(1.0, bombBeep, beepPack);
		WritePackCell(explosionPack, GetClientUserId(client));
		WritePackCell(explosionPack, bombEnt);
		WritePackCell(beepPack, bombEnt);
		WritePackCell(beepPack, (time - 1));
		g_bHasActiveBomb[client] = true;
		bombFound = true;
	}

	if (!bombFound)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Bomb Was Not Found", client);
	}

	g_iWire[client] = GetRandomInt(1, 4);
	CPrintToChat(client, "%s %T", g_sPluginTag, "Wire Is", client, g_iWire[client]);
}

stock int findBombPlanter(int &bomb)
{
	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		int iPlanter = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");

		if (iPlanter <= 0)
		{
			continue;
		}

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if (!StrEqual(MDL_C4, sModelPath))
		{
			continue;
		}

		bomb = iEnt;
		return iPlanter;
	}

	return -1;
}

stock int findBomb(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return -1;
	}

	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
		{
			continue;
		}

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if (!StrEqual(MDL_C4, sModelPath))
		{
			continue;
		}

		return iEnt;
	}
	return -1;
}

public Action bombBeep(Handle timer, Handle pack)
{
	int bombEnt;
	int beeps;
	ResetPack(pack);
	bombEnt = ReadPackCell(pack);
	beeps = ReadPackCell(pack);
	if (!IsValidEntity(bombEnt))
	{
		return Plugin_Stop;
	}

	int owner = GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity");
	if (!TTT_IsClientValid(owner))
	{
		return Plugin_Stop;
	}

	float bombPos[3];
	GetEntPropVector(bombEnt, Prop_Data, "m_vecOrigin", bombPos);
	bool stopBeeping = false;
	if (beeps > 0)
	{
		EmitAmbientSoundAny(SND_BEEP, bombPos);
		beeps--;
		stopBeeping = false;
	}
	else
	{
		stopBeeping = true;
	}

	if (stopBeeping)
	{
		return Plugin_Stop;
	}

	Handle bombBeep2;
	CreateDataTimer(1.0, bombBeep, bombBeep2);
	WritePackCell(bombBeep2, bombEnt);
	WritePackCell(bombBeep2, beeps);
	return Plugin_Stop;
}

stock void removeBomb(int client)
{
	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") != client)
		{
			continue;
		}

		char sModelPath[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));

		if (!StrEqual(MDL_C4, sModelPath))
		{
			continue;
		}

		AcceptEntityInput(iEnt, "Kill");
	}
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}
