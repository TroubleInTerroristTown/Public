#pragma semicolon 1

#define DEBUG

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>
#include <ttt_shop>
#include <multicolors>
#include <emitsoundany>
#include <cstrike>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - C4 & Jihad"
#define SHORT_NAME_C4 "c4"
#define SHORT_NAME_J "jihad"

#define SND_BLIP "buttons/blip2.wav"
#define SND_BURST "training/firewerks_burst_02.wav"
#define SND_BEEP "weapons/c4/c4_beep1.wav"
#define SND_DISARM "weapons/c4/c4_disarm.wav"

#define MDL_C4 "models/weapons/w_c4_planted.mdl"

int g_iPrice_C4 = 0;
int g_iPrio_C4 = 0;
int g_iCount_C4 = 0;
int g_iPCount_C4[MAXPLAYERS + 1] =  { 0, ... };
int g_iC4ShakeRadius = 0;
int g_iDefusePlayerIndex[MAXPLAYERS + 1] =  { -1, ... };
int g_iWire[MAXPLAYERS + 1] =  { 0, ... };

int g_iPrice_J = 0;
int g_iPrio_J = 0;

bool g_bHasC4[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasJ[MAXPLAYERS + 1] =  { false, ... };
bool g_bDetonate[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasActiveBomb[MAXPLAYERS + 1] =  { false, ... };

bool g_bRemoveBomb = false;

Handle g_hExplosionTimer[MAXPLAYERS + 1] =  { null, ... };
Handle g_hJihadBomb[MAXPLAYERS + 1] =  { null, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName_C4[64];
char g_sLongName_J[64];

float g_fJihadPreparingTime = 60.0;

int g_iC4DamageRadius = 850;
int g_iC4Magnitude = 850;
float g_fC4KillRadius = 275.0;

int g_iJihadDamageRadius = 600;
int g_iJihadMagnitude = 1000;

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
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/c4_jihad.cfg");
	Config_Setup("TTT-Bomb", g_sConfigFile);
	
	Config_LoadString("c4_name", "C4", "The name of the C4 in the Shop", g_sLongName_C4, sizeof(g_sLongName_C4));
	g_iPrice_C4 = Config_LoadInt("c4_price", 9000, "The amount of credits a c4 costs as traitor. 0 to disable.");
	g_iPrio_C4 = Config_LoadInt("c4_sort_prio", 0, "The sorting priority of the C4 in the shop menu.");
	g_iCount_C4 = Config_LoadInt("c4_count", 9000, "The amount of c4's a traitor can buy.");
	g_iC4ShakeRadius = Config_LoadInt("c4_shake_radius", 5000, "The 'shake' radius of the C4 explosion.");
	g_iC4DamageRadius = Config_LoadInt("c4_damage_radius", 850, "The damage radius of the C4 explosion.");
	
	Config_LoadString("jihad_name", "Jihad Bomb", "The name of the Jihad in the Shop", g_sLongName_J, sizeof(g_sLongName_J));
	g_iPrice_J = Config_LoadInt("jihad_price", 9000, "The amount of credits a jihad costs as traitor. 0 to disable.");
	g_iPrio_J = Config_LoadInt("jihad_sort_prio", 0, "The sorting priority of the Jihad in the shop menu.");
	g_fJihadPreparingTime = Config_LoadFloat("jihad_preparing_time", 60.0, "The amount of time in seconds until the jihad bomb is ready after buying it.");
	g_bRemoveBomb = Config_LoadBool("remove_bomb_on_spawn", true, "Remove the bomb from the map to prevent interference. 1 = Remove, 0 = Don't Remove");
	g_iJihadDamageRadius = Config_LoadInt("jihad_damage_radius", 600, "The damage radius of the Jihad explosion.");
	
	g_iC4Magnitude = Config_LoadInt("c4_magnitude", 850, "The amount of damage done by the explosion. For C4");
	g_iJihadMagnitude = Config_LoadInt("jihad_magnitude", 1000, "The amount of damage done by the explosion. For Jihad");
	
	g_fC4KillRadius = Config_LoadFloat("c4_kill_radius", 275.0, "The kill radius of the C4 explosion.");
	
	Config_Done();
	
	AddCommandListener(Command_LAW, "+lookatweapon");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	LoadTranslations("ttt.phrases");
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

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME_C4, g_sLongName_C4, g_iPrice_C4, TTT_TEAM_TRAITOR, g_iPrio_C4);
	TTT_RegisterCustomItem(SHORT_NAME_J, g_sLongName_J, g_iPrice_J, TTT_TEAM_TRAITOR, g_iPrio_J);
}

public void ResetJihad(int client)
{
	g_bHasJ[client] = false;
	g_bDetonate[client] = false;
	ClearTimer(g_hJihadBomb[client]);
}

public void ResetGlobals(int client)
{
	g_bHasC4[client] = false;
	g_bHasJ[client] = false;
	g_bDetonate[client] = false;
	g_bHasActiveBomb[client] = false;
	g_iDefusePlayerIndex[client] = -1;
	g_iWire[client] = -1;
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
			if(g_iPCount_C4[client] >= g_iCount_C4)
			{			
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName_C4, g_iCount_C4);
				return Plugin_Stop;
			}
			
			g_bHasC4[client] = true;
			
			if (count)
			{
				g_iPCount_C4[client]++;
			}
			
			CPrintToChat(client, g_sPluginTag, "Right click to plant the C4", client);
		}
		else if (StrEqual(itemshort, SHORT_NAME_J, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_TRAITOR || g_bHasJ[client])
			{
				return Plugin_Stop;
			}
			
			
			ClearTimer(g_hJihadBomb[client]);
			g_hJihadBomb[client] = CreateTimer(g_fJihadPreparingTime, Timer_JihadPreparing, GetClientUserId(client));
			g_bHasJ[client] = true;
			
			CPrintToChat(client, g_sPluginTag, "bomb will arm in 60 seconds, double tab F to explode", client);
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
	
	CPrintToChat(client, g_sPluginTag, "Your bomb is now armed.", client);
	EmitAmbientSound(SND_BLIP, NULL_VECTOR, client);
	g_hJihadBomb[client] = null;
	return Plugin_Stop;
}

public Action Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bRemoveBomb)
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
	if (!g_bHasC4[client] && !g_bHasJ[client])
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
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", g_iJihadMagnitude);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", g_iJihadDamageRadius);
		
		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);
		
		float playerEyes[3];
		GetClientEyePosition(client, playerEyes);
		
		TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client);
		
		EmitAmbientSoundAny("ttt/jihad/explosion.mp3", NULL_VECTOR, client, SNDLEVEL_RAIDSIREN);
		
		
		AcceptEntityInput(ExplosionIndex, "Explode");
		
		AcceptEntityInput(ExplosionIndex, "Kill");
	}
	g_bHasJ[client] = false;
}

public Action Command_Detonate(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!g_bHasJ[client])
	{
		CPrintToChat(client, g_sPluginTag, "You dont have it!", client);
		return Plugin_Handled;
	}
	
	if (g_hJihadBomb[client] != null)
	{
		CPrintToChat(client, g_sPluginTag, "Your bomb is not armed.", client);
		return Plugin_Handled;
	}
	
	EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);
	
	CreateTimer(2.0, TimerCallback_Detonate, client);
	g_bHasJ[client] = false;
	
	return Plugin_Handled;
}

public Action TimerCallback_Detonate(Handle timer, any client)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	Detonate(client);
	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}
	
	if (IsPlayerAlive(client) && g_bHasJ[client] && g_hJihadBomb[client] == null && g_bDetonate[client])
	{
		EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client);
		
		CreateTimer(2.0, TimerCallback_Detonate, client);
		g_bHasJ[client] = false;
		
		return Plugin_Continue;
	}
	else
	{
		g_bDetonate[client] = true;
		CreateTimer(2.0, Reset, client);
	}
	return Plugin_Continue;
}

public Action Reset(Handle timer, any client)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	g_bDetonate[client] = false;
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
		CPrintToChat(client, g_sPluginTag, "Bomb Detonated", client);
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
		IntToString(g_iC4ShakeRadius, sShakeRadius, sizeof(sShakeRadius));
		
		DispatchKeyValue(shakeIndex, "amplitude", "4");
		DispatchKeyValue(shakeIndex, "duration", "1");
		DispatchKeyValue(shakeIndex, "frequency", "2.5");
		DispatchKeyValue(shakeIndex, "radius", sShakeRadius);
		DispatchKeyValue(particleIndex, "effect_name", "explosion_c4_500");
		SetEntProp(explosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(explosionIndex, Prop_Data, "m_iRadiusOverride", g_iC4DamageRadius);
		SetEntProp(explosionIndex, Prop_Data, "m_iMagnitude", g_iC4Magnitude);
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
			
			if (GetVectorDistance(clientOrigin, explosionOrigin) <= g_fC4KillRadius)
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
	
	char sTitle[128];
	char s10[64], s20[64], s30[64], s40[64], s50[64], s60[64];
	
	Format(sTitle, sizeof(sTitle), "%T", "Set C4 Timer", client);
	Format(s10, sizeof(s10), "%T", "Seconds", client, 10);
	Format(s20, sizeof(s20), "%T", "Seconds", client, 20);
	Format(s30, sizeof(s30), "%T", "Seconds", client, 30);
	Format(s40, sizeof(s40), "%T", "Seconds", client, 40);
	Format(s50, sizeof(s50), "%T", "Seconds", client, 50);
	Format(s60, sizeof(s60), "%T", "Seconds", client, 60);
	
	Handle menuHandle = CreateMenu(plantBombMenu);
	SetMenuTitle(menuHandle, sTitle);
	AddMenuItem(menuHandle, "10", s10);
	AddMenuItem(menuHandle, "20", s20);
	AddMenuItem(menuHandle, "30", s30);
	AddMenuItem(menuHandle, "40", s40);
	AddMenuItem(menuHandle, "50", s50);
	AddMenuItem(menuHandle, "60", s60);
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
	
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			GetMenuItem(menu, option, info, sizeof(info));
			if (StrEqual(info, "10"))
			{
				plantBomb(client, 10.0);
			}
			else if (StrEqual(info, "20"))
			{
				plantBomb(client, 20.0);
			}
			else if (StrEqual(info, "30"))
			{
				plantBomb(client, 30.0);
			}
			else if (StrEqual(info, "40"))
			{
				plantBomb(client, 40.0);
			}
			else if (StrEqual(info, "50"))
			{
				plantBomb(client, 50.0);
			}
			else if (StrEqual(info, "60"))
			{
				plantBomb(client, 60.0);
			}
			g_bHasC4[client] = false;
		}
		case MenuAction_End:
		{
			delete menu;
			g_bHasActiveBomb[client] = false;
			removeBomb(client);
		}
		case MenuAction_Cancel:
		{
			g_bHasActiveBomb[client] = false;
			removeBomb(client);
		}
	}
}

public int defuseBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	switch (action)
	{
		case MenuAction_Select:
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
					CPrintToChat(client, g_sPluginTag, "You Defused Bomb", client, planter);
					CPrintToChat(planter, g_sPluginTag, "Has Defused Bomb", planter, client);
					EmitAmbientSoundAny(SND_DISARM, bombPos);
					g_bHasActiveBomb[planter] = false;
					ClearTimer(g_hExplosionTimer[planter]);
					SetEntProp(planterBombIndex, Prop_Send, "m_hOwnerEntity", -1);
				}
			}
			else
			{
				CPrintToChat(client, g_sPluginTag, "Failed Defuse", client);
				ForcePlayerSuicide(client);
				g_iDefusePlayerIndex[client] = -1;
			}
		}
		case MenuAction_End:
		{
			delete menu;
			g_iDefusePlayerIndex[client] = -1;
		}
		case MenuAction_Cancel:
		{
			g_iDefusePlayerIndex[client] = -1;
		}
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
		CPrintToChat(client, g_sPluginTag, "Alive to Plant", client);
		return;
	}
	
	CPrintToChat(client, g_sPluginTag, "Will Explode In", client, time);
	
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
		if (g_hExplosionTimer[client] != null)
		{
			KillTimer(g_hExplosionTimer[client]);
		}
		g_hExplosionTimer[client] = CreateDataTimer(time, explodeC4, explosionPack);
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
		CPrintToChat(client, g_sPluginTag, "Bomb Was Not Found", client);
	}
	
	g_iWire[client] = GetRandomInt(1, 4);
	CPrintToChat(client, g_sPluginTag, "Wire Is", client, g_iWire[client]);
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