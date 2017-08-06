/*
*   This file is part of Cameras and Drones.
*   Copyright (C) 2017  Keplyx
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <csgocolors>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <usermessages>
#include <csgocolors>
#include <camerasanddrones>

#pragma newdecls required;

#include "cameras-and-drones/cameramenus.sp"
#include "cameras-and-drones/dronemenus.sp"
#include "cameras-and-drones/init.sp"

/*  New in this version
*	First release!
*
*/

#define VERSION "1.0.0"
#define AUTHOR "Keplyx"
#define PLUGIN_NAME "Cameras and Drones"

#define HIDEHUD_WEAPONSELECTION ( 1<<0 ) // Hide ammo count & weapon selection
#define FFADE_STAYOUT       0x0008        // ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE         0x0010        // Purges all other fades, replacing them with this one

bool lateload;

int clientsViewmodels[MAXPLAYERS + 1];

char gearWeapon[] = "weapon_tagrenade";

bool canDisplayThrowWarning[MAXPLAYERS + 1];
bool canDroneJump[MAXPLAYERS + 1];
bool isDroneJumping[MAXPLAYERS + 1];

int collisionOffsets;

int boughtGear[MAXPLAYERS + 1];

int playerGearOverride[MAXPLAYERS + 1];

/************************************************************************************************************
 *											INIT
 ************************************************************************************************************/

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = AUTHOR,
	description = "CSGO plugin adding cameras and drones to the game.",
	version = VERSION,
	url = "https://github.com/Keplyx/cameras-and-drones"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("BuyPlayerGear", Native_BuyPlayerGear);
	CreateNative("OverridePlayerGear", Native_OverridePlayerGear);
	lateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	AddNormalSoundHook(NormalSoundHook);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	AddCommandListener(CommandDrop, "drop"); 
	AddCommandListener(CommandJoinTeam, "jointeam");
	
	CreateConVars(VERSION);
	RegisterCommands();
	
	collisionOffsets = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i))
			OnClientPostAdminCheck(i);
	}
	
	if (lateload)
		ServerCommand("mp_restartgame 1");
}

public int GetCollOffset()
{
	return collisionOffsets;
}

public void OnMapStart()
{
	PrecacheModel(InCamModel, true);
	PrecacheModel(dronePhysModel, true);
	PrecacheModel(camPhysModel, true);
	
	PrecacheSound(droneSound, true);
	PrecacheSound(droneJumpSound, true);
	PrecacheSound(openDroneSound, true);
	PrecacheSound(destroyDroneSound, true);
	PrecacheSound(openCamSound, true);
	PrecacheSound(destroyCamSound, true);
}

public void OnConfigsExecuted()
{
	// Nothing yet
}

public void OnClientPostAdminCheck(int client_index)
{
	SDKHook(client_index, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	int ref = EntIndexToEntRef(client_index);
	CreateTimer(3.0, Timer_WelcomeMessage, ref);
}

public void OnClientDisconnect(int client_index)
{
	ResetPlayer(client_index);
}

public void ResetPlayer(int client_index)
{
	if (dronesList != null)
	{
		for (int i = 0; i < dronesList.Length; i++)
		{
			if (dronesOwnerList.Get(i) == client_index)
				DestroyDrone(dronesList.Get(i), true);
		}
	}
	if (camerasList != null)
	{
		for (int i = 0; i < camerasList.Length; i++)
		{
			if (camOwnersList.Get(i) == client_index)
				DestroyCamera(camerasList.Get(i), true);
		}
	}
	
	boughtGear[client_index] = 0;
	canDisplayThrowWarning[client_index] = true;
	canDroneJump[client_index] = true;
	isDroneJumping[client_index] = false;
	playerGearOverride[client_index] = 0;
}

public void InitVars()
{
	camerasList = new ArrayList();
	camerasModelList = new ArrayList();
	camOwnersList = new ArrayList();
	dronesList = new ArrayList();
	dronesModelList = new ArrayList();
	dronesOwnerList = new ArrayList();
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		for (int j = 0; j < sizeof(activeCam[]); j++)
		{
			activeCam[i][j] = -1;
		}
		for (int j = 0; j < sizeof(activeDrone[]); j++)
		{
			activeDrone[i][j] = -1;
		}
		fakePlayersListCamera[i] = -1;
		fakePlayersListDrones[i] = -1;
		boughtGear[i] = 0;
		canDisplayThrowWarning[i] = true;
		canDroneJump[i] = true;
		isDroneJumping[i] = false;
		playerGearOverride[i] = 0;
	}
}

/************************************************************************************************************
 *											NATIVES
 ************************************************************************************************************/

public int Native_BuyPlayerGear(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	if (IsClientTeamCameras(client_index))
		BuyCamera(client_index, true);
	else if (IsClientTeamDrones(client_index))
		BuyDrone(client_index, true);
}

public int Native_OverridePlayerGear(Handle plugin, int numParams)
{
	int client_index = GetNativeCell(1);
	if (!IsValidClient(client_index))
	{
		PrintToServer("Invalid client (%d)", client_index)
		return;
	}
	int gearNum = GetNativeCell(2);
	
	if (gearNum > 2 || gearNum < -1)
		gearNum = 0;
	
	playerGearOverride[client_index] = gearNum;
	
	switch (gearNum)
	{
		case -1: PrintToConsole(client_index, "You can't use any gear");
		case 0: PrintToConsole(client_index, "You are now using your team gear");
		case 1: PrintToConsole(client_index, "You are now using cameras");
		case 2: PrintToConsole(client_index, "You are now using drones");
	}
}

/************************************************************************************************************
 *											EVENTS
 ************************************************************************************************************/

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	InitVars();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client_index = GetClientOfUserId(GetEventInt(event, "userid"));
	clientsViewmodels[client_index] = GetViewModelIndex(client_index);
}

/************************************************************************************************************
 *											Detect Gear
 ************************************************************************************************************/

public void OnEntityCreated(int entity_index, const char[] classname)
{
	if (StrEqual(classname, "tagrenade_projectile", false))
	{
		SDKHook(entity_index, SDKHook_Spawn, OnProjectileSpawned);
	}
}

public void OnProjectileSpawned (int entity_index)
{
	// Do not hook flash
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (activeCam[i][2] == entity_index)
			return;
	}
	SDKHook(entity_index, SDKHook_StartTouch, StartTouchGrenade);
}

public Action StartTouchGrenade(int entity1, int entity2)
{
	if (IsValidEdict(entity1))
	{
		float pos[3], rot[3];
		GetEntPropVector(entity1, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(entity1, Prop_Send, "m_angRotation", rot);
		int owner = GetEntPropEnt(entity1, Prop_Send, "m_hOwnerEntity");
		
		if (IsValidClient(entity2))
		{
			PreventGearActivation(owner, entity1);
			return;
		}
		for (int i = 1; i <= MAXPLAYERS; i++)
		{
			if (entity2 == fakePlayersListCamera[i] || entity2 == fakePlayersListDrones[i])
			{
				PreventGearActivation(owner, entity1);
				return;
			}
		}
		
		RemoveEdict(entity1);
		if (IsClientTeamCameras(owner))
			CreateCamera(owner, pos, rot);
		else if (IsClientTeamDrones(owner))
			CreateDrone(owner, pos, rot);
	}
}

public void PreventGearActivation(int client_index, int entity_index) // Prevent gear acivation if gear hits player
{
	float pos[3];
	GetEntPropVector(entity_index, Prop_Send, "m_vecOrigin", pos);
	RemoveEdict(entity_index);
	if (IsClientTeamCameras(client_index))
	{
		EmitSoundToAll(destroyDroneSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,  SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
		PrintHintText(client_index, "<font color='#ff0000' size='25'>Your camera touched a player and was destroyed</font>");
	}
	else if (IsClientTeamDrones(client_index))
	{
		EmitSoundToAll(destroyCamSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,  SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
		PrintHintText(client_index, "<font color='#ff0000' size='25'>Your drone touched a player and was destroyed</font>");
	}
}

/************************************************************************************************************
 *											COMMANDS
 ************************************************************************************************************/

public Action ShowHelp(int client_index, int args)
{
	PrintToConsole(client_index, "|-------------------------------------------------------|");
	PrintToConsole(client_index, "|----------- CAMERAS AND DRONES HELP -------------------|");
	PrintToConsole(client_index, "|---- CONSOLE ----|-- IN CHAT --|-- DESCRIPTION --------|");
	PrintToConsole(client_index, "|cd_buy           |             |Buy team gear          |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|cd_cam           |             |Open gear              |");
	PrintToConsole(client_index, "|-----------------|-------------|-----------------------|");
	PrintToConsole(client_index, "|cd_help          |!cd_help     |Display this help      |");
	PrintToConsole(client_index, "|-------------------------------------------------------|");
	PrintToConsole(client_index, "");
	PrintToConsole(client_index, "For a better experience, you should bind cd_buy and cd_cam to a key:");
	PrintToConsole(client_index, "bind 'KEY' 'COMMAND' | This will bind 'COMMAND to 'KEY'");
	PrintToConsole(client_index, "EXAMPLE:");
	PrintToConsole(client_index, "bind \"z\" \"cd_buy\" | This will bind the buy command to the <Z> key");
	PrintToConsole(client_index, "bind \"x\" \"cd_cam\" | This will bind the open command to the <X> key");
	
	CPrintToChat(client_index, "{green}----- CAMERAS AND DRONES HELP -----");
	CPrintToChat(client_index, "{lime}>>> START");
	CPrintToChat(client_index, "This plugin is used with the console:");
	CPrintToChat(client_index, "To enable the console, do the following:");
	CPrintToChat(client_index, "{yellow}Options -> Game Option -> Enable Developper Console");
	CPrintToChat(client_index, "To set the toggle key, do the following:");
	CPrintToChat(client_index, "{yellow}Options -> Keyboard/Mouse -> Toggle Console");
	CPrintToChat(client_index, "{lime}Open the console for more information");
	CPrintToChat(client_index, "{green}----- ---------- ---------- -----");
	return Plugin_Handled;
}

public Action OverrideGear(int client_index, int args)
{
	if (args == 0)
	{
		PrintToConsole(client_index, "Usage: cd_override <player> <gear_num>");
		PrintToConsole(client_index, "<gear_num> = 0 | no override");
		PrintToConsole(client_index, "<gear_num> = 1 | force camera");
		PrintToConsole(client_index, "<gear_num> = 1 | force drone");
		return Plugin_Handled;
	}
	
	char name[32];
	int target = -1;
	GetCmdArg(1, name, sizeof(name));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
		{
			continue;
		}
		char other[32];
		GetClientName(i, other, sizeof(other));
		if (StrEqual(name, other))
		{
			target = i;
		}
	}
	if (target == -1)
	{
		PrintToConsole(client_index, "Could not find any player with the name: \"%s\"", name);
		PrintToConsole(client_index, "Available players:");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i))
			{
				continue;
			}
			char player[32];
			GetClientName(i, player, sizeof(player));
			PrintToConsole(client_index, "\"%s\"", player);
		}
		return Plugin_Handled;
	}
	
	char gear[32];
	GetCmdArg(2, gear, sizeof(gear));
	int gearNum = StringToInt(gear);
	
	if (gearNum > 2 || gearNum < -1)
		gearNum = 0;
	
	playerGearOverride[target] = gearNum;
	
	switch (gearNum)
	{
		case -1:
		{
			PrintToConsole(client_index, "% now doesn't have gear", name);
			PrintToConsole(target, "You can't use any gear");
		}
		case 0:
		{
			PrintToConsole(client_index, "%s now doesn't have gear override", name);
			PrintToConsole(target, "You are now using your team gear");
		}
		case 1:
		{
			PrintToConsole(client_index, "%s now has cameras", name);
			PrintToConsole(target, "You are now using cameras");
		}
		case 2:
		{
			PrintToConsole(client_index, "%s now has drones", name);
			PrintToConsole(target, "You are now using drones");
		}
	}
	
	return Plugin_Handled;
}

public Action BuyGear(int client_index, int args)
{
	if (IsClientTeamCameras(client_index))
		BuyCamera(client_index, false);
	else if (IsClientTeamDrones(client_index))
		BuyDrone(client_index, false);
	
	return Plugin_Handled;
}

public void BuyCamera(int client_index, bool isFree)
{
	if (boughtGear[client_index] >= 1)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You already bought a camera</font>");
		return;
	}
	if (!isFree)
	{
		int money = GetEntProp(client_index, Prop_Send, "m_iAccount");
		if (cvar_camprice.IntValue > money)
		{
			PrintHintText(client_index, "<font color='#ff0000' size='30'>Not enough money</font>");
			return;
		}
		SetEntProp(client_index, Prop_Send, "m_iAccount", money - cvar_camprice.IntValue);
	}
	GivePlayerItem(client_index, gearWeapon);
	PrintHintText(client_index, "<font color='#0fff00' size='25'>You just bought a camera</font>");
	boughtGear[client_index]++;
}

public void BuyDrone(int client_index, bool isFree)
{
	if (boughtGear[client_index] >= 1)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>You already bought a drone</font>");
		return;
	}
	if (!isFree)
	{
		int money = GetEntProp(client_index, Prop_Send, "m_iAccount");
		if (cvar_droneprice.IntValue > money)
		{
			PrintHintText(client_index, "<font color='#ff0000' size='30'>Not enough money</font>");
			return;
		}
		SetEntProp(client_index, Prop_Send, "m_iAccount", money - cvar_droneprice.IntValue);
	}
	GivePlayerItem(client_index, gearWeapon);
	PrintHintText(client_index, "<font color='#0fff00' size='25'>You just bought a drone</font>");
	boughtGear[client_index]++;
}

public Action OpenGear(int client_index, int args) //Set player skin if authorized
{
	if (IsClientTeamCameras(client_index))
		OpenCamera(client_index);
	else if (IsClientTeamDrones(client_index))
		OpenDrone(client_index);
	
	return Plugin_Handled;
}

public void OpenCamera(int client_index)
{
	if (IsClientInCam(client_index))
	{
		CloseGear(client_index);
		return;
	}
	if (!(GetEntityFlags(client_index) & FL_ONGROUND))
	{
		PrintHintText(client_index, "<font color='#ff0000' size='25'>Cannot use cameras while jumping</font>");
		return;
	}
	if (camerasList.Length == 0)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>No cameras available</font>");
		return;
	}
	int owner;
	int target = -1;
	for (int i = 0; i < camerasList.Length; i++)
	{
		if (IsValidEntity(i) && IsValidClient(client_index))
		{
			owner = camOwnersList.Get(i);
			if (owner == client_index)
			{
				target = camerasList.Get(i);
				break;
			}
		}
	}
	if (target == -1)
		target = camerasList.Get(0);
	
	Menu_Cameras(client_index, camerasList.FindValue(target));
	TpToCam(client_index, target);
}

public void OpenDrone(int client_index)
{
	if (IsClientInDrone(client_index))
	{
		CloseGear(client_index);
		return;
	}
	if (!(GetEntityFlags(client_index) & FL_ONGROUND))
	{
		PrintHintText(client_index, "<font color='#ff0000' size='25'>Cannot use drones while jumping</font>");
		return;
	}
	if (dronesList.Length == 0)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>No drones available</font>");
		return;
	}
	int owner;
	int target = -1;
	for (int i = 0; i < dronesList.Length; i++)
	{
		if (IsValidEntity(i) && IsValidClient(client_index))
		{
			owner = dronesOwnerList.Get(i);
			if (owner == client_index)
			{
				target = dronesList.Get(i);
				break;
			}
		}
	}
	if (target == -1)
	{
		PrintHintText(client_index, "<font color='#ff0000' size='30'>No drones available</font>");
		return;
	}
	
	Menu_Drones(client_index, dronesList.FindValue(target));
	TpToDrone(client_index, target);
}

/************************************************************************************************************
 *											GEAR SPECIFIC METHODS
 ************************************************************************************************************/

public bool CanThrowGear(int client_index)
{
	if (IsClientTeamCameras(client_index))
		return CanThrowCamera(client_index);
	else if (IsClientTeamDrones(client_index))
		return CanThrowDrone(client_index);
	else
		return false;
}

public bool CanThrowCamera(int client_index)
{
	int counter;
	for (int i = 0; i < camOwnersList.Length; i++)
	{
		if (camOwnersList.Get(i) == client_index)
		counter++;
	}
	if (cvar_totalmax_cam.IntValue > counter)
		return true;
	else
	{
		if (canDisplayThrowWarning[client_index])
		{
			canDisplayThrowWarning[client_index] = false;
			PrintHintText(client_index, "<font color='#ff0000' size='25'>You cannot place any more cameras</font>");
			int ref = EntIndexToEntRef(client_index);
			CreateTimer(1.0, Timer_DisplayThrowWarning, ref);
		}
		return false;
	}
}

public bool CanThrowDrone(int client_index)
{
	int counter;
	for (int i = 0; i < dronesOwnerList.Length; i++)
	{
		if (dronesOwnerList.Get(i) == client_index)
		counter++;
	}
	if (cvar_totalmax_drone.IntValue > counter)
		return true;
	else
	{
		if (canDisplayThrowWarning[client_index])
		{
			canDisplayThrowWarning[client_index] = false;
			PrintHintText(client_index, "<font color='#ff0000' size='25'>You cannot place any more drones</font>");
			int ref = EntIndexToEntRef(client_index);
			CreateTimer(1.0, Timer_DisplayThrowWarning, ref);
		}
		return false;
	}
}

public void PickupGear(int client_index, int i)
{
	float pos[3], gearPos[3];
	GetClientEyePosition(client_index, pos);
	
	if (IsClientTeamCameras(client_index))
	{
		int cam = camerasList.Get(i);
		GetEntPropVector(cam, Prop_Send, "m_vecOrigin", gearPos);
		if (GetVectorDistance(pos, gearPos, false) < cvar_pickuprange.FloatValue)
			PickupCamera(client_index, cam);
	}
	else if (IsClientTeamDrones(client_index))
	{
		int drone = dronesList.Get(i);
		GetEntPropVector(drone, Prop_Send, "m_vecOrigin", gearPos);
		if (GetVectorDistance(pos, gearPos, false) < cvar_pickuprange.FloatValue)
			PickupDrone(client_index, drone);
	}
}

public void PickupCamera(int client_index, int cam)
{
	DestroyCamera(cam, true);
	GivePlayerItem(client_index, gearWeapon);
	PrintHintText(client_index, "<font color='#0fff00' size='25'>Camera recovered</font>");
}

public void PickupDrone(int client_index, int cam)
{
	DestroyDrone(cam, true);
	GivePlayerItem(client_index, gearWeapon);
	PrintHintText(client_index, "<font color='#0fff00' size='25'>Drone recovered</font>");
}

public void CloseGear(int client_index)
{
	if (IsClientTeamCameras(client_index))
		CloseCamera(client_index);
	else if (IsClientTeamDrones(client_index))
		CloseDrone(client_index);
}
public void CloseCamera(int client_index)
{
	ExitCam(client_index);
	if (playerCamMenus[client_index] != null)
	{
		delete playerCamMenus[client_index];
	}
}

public void CloseDrone(int client_index)
{
	ExitDrone(client_index);
	if (playerDroneMenus[client_index] != null)
	{
		delete playerDroneMenus[client_index];
	}
}

/************************************************************************************************************
 *											INPUT
 ************************************************************************************************************/

public Action OnPlayerRunCmd(int client_index, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerAlive(client_index))
		return Plugin_Continue;
	
	if (IsClientInGear(client_index)) // in gear input
	{
		//Disable weapons
		float fUnlockTime = GetGameTime() + 1.0;
		SetEntPropFloat(client_index, Prop_Send, "m_flNextAttack", fUnlockTime);
		
		if (buttons & IN_DUCK) // Prevent crouching camera bugs
		{
			buttons &= ~IN_DUCK;
			CloseGear(client_index);
		}
		if (buttons & IN_USE) // Prevent interaction with the world
		{
			buttons &= ~IN_USE;
		}
	}
	else // normal player input
	{
		if (buttons & IN_USE) // pickup
		{
			int target = GetClientAimTarget(client_index, false);
			int cam = camerasList.FindValue(target);
			int drone = dronesList.FindValue(target);
			if (cam != -1 && camOwnersList.Length > 0 && camOwnersList.Get(cam) == client_index)
				PickupGear(client_index, cam);
			else if (drone  != -1 && dronesOwnerList.Length > 0 && dronesOwnerList.Get(drone) == client_index)
				PickupGear(client_index, drone);
		}
		if (buttons & IN_ATTACK) // Stop player from throwing the gear too far
		{
			int weapon_index = GetEntPropEnt(client_index, Prop_Send, "m_hActiveWeapon");
			char weapon_name[64];
			GetEntityClassname(weapon_index, weapon_name, sizeof(weapon_name))
			if (StrEqual(weapon_name, gearWeapon, false))
			{
				buttons &= ~IN_ATTACK;
				buttons |= IN_ATTACK2;
			}
		}
		if ((buttons & IN_ATTACK2)) // Prevent player from throwing too many gear
		{
			int weapon_index = GetEntPropEnt(client_index, Prop_Send, "m_hActiveWeapon");
			char weapon_name[64];
			GetEntityClassname(weapon_index, weapon_name, sizeof(weapon_name))
			if (StrEqual(weapon_name, gearWeapon, false) && !CanThrowGear(client_index))
			{
				float fUnlockTime = GetGameTime() + 1.0;
				SetEntPropFloat(client_index, Prop_Send, "m_flNextAttack", fUnlockTime);
			}
		}
	}
	
	if (IsClientInDrone(client_index)) // Drone specific input
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;
		if (buttons & IN_FORWARD)
		{
			isDroneMoving[client_index] = true;
			if (!isDroneJumping[client_index]) // Prevent moving reset vel while trying to jump
				MoveDrone(client_index, activeDrone[client_index][0]);
		}
		if ((buttons & IN_JUMP) && canDroneJump[client_index])
		{
			canDroneJump[client_index] = false;
			isDroneJumping[client_index] = true;
			JumpDrone(client_index, activeDrone[client_index][0]);
			CreateTimer(0.1, Timer_IsJumping, client_index);
			CreateTimer(cvar_jumpcooldown.FloatValue, Timer_CanJump, client_index);
		}
		if (buttons & IN_SPEED)
			isDroneMoving[client_index] = true;
		else if (!(buttons & IN_FORWARD))
			isDroneMoving[client_index] = false;
	}
	return Plugin_Changed;
}

/************************************************************************************************************
 *											TIMERS
 ************************************************************************************************************/
 
public Action Timer_WelcomeMessage(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (cvar_welcome_message.BoolValue && IsValidClient(client_index))
	{
		//Welcome message (white text in red box)
		CPrintToChat(client_index, "{darkred}********************************");
		CPrintToChat(client_index, "{darkred}* {default}This server uses {lime}%s", PLUGIN_NAME);
		CPrintToChat(client_index, "{darkred}*            {default}Made by {lime}%s", AUTHOR);
		CPrintToChat(client_index, "{darkred}* {default}Use {lime}!cd_help{default} in chat to learn");
		CPrintToChat(client_index, "{darkred}*                  {default}how to play");
		CPrintToChat(client_index, "{darkred}********************************");
	}
}

public Action Timer_DisplayThrowWarning(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (IsValidClient(client_index))
	{
		canDisplayThrowWarning[client_index] = true;
	}
}

public Action Timer_CanJump(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (IsValidClient(client_index))
	{
		canDroneJump[client_index] = true;
	}
}

public Action Timer_IsJumping(Handle timer, any ref)
{
	int client_index = EntRefToEntIndex(ref);
	if (IsValidClient(client_index))
	{
		isDroneJumping[client_index] = false;
	}
}

/************************************************************************************************************
 *											HOOKS
 ************************************************************************************************************/
 
public Action NormalSoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (IsValidEntity(entity))
	{
		if (StrContains(sample, "sensor") != -1)
			return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Hook_SetTransmitPlayer(int entity_index, int client_index) // hide player only if using cam/drone
{
	if (client_index != entity_index && IsValidClient(entity_index) && IsClientInGear(entity_index))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Hook_SetTransmitGear(int entity_index, int client_index) // Hide cam/drone only to the one using it
{
	if (IsValidClient(client_index) && ((activeCam[client_index][1] == entity_index || activeCam[client_index][2] == entity_index) || activeDrone[client_index][1] == entity_index))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Hook_TakeDamageFakePlayer(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int owner = GetEntPropEnt(victim, Prop_Send, "m_hOwnerEntity");
	char weapon[64];
	GetClientWeapon(attacker, weapon, sizeof(weapon))
	RemoveHealth(owner, damage, attacker, damagetype, weapon);
}

public Action Hook_WeaponCanUse(int client_index, int weapon_index)  
{
	if (IsClientInGear(client_index))
		return Plugin_Handled;
	
	
	return Plugin_Continue;
}

public Action Hook_TakeDamageGear(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int client_index = -1;
	if (camerasList.FindValue(victim) != -1)
		client_index = camOwnersList.Get(camerasList.FindValue(victim));
	else if (dronesList.FindValue(victim) != -1)
		client_index = dronesOwnerList.Get(dronesList.FindValue(victim));
	if (!IsValidClient(client_index))
		return Plugin_Handled;
	if (cvar_tkprotect.BoolValue && GetClientTeam(client_index) == GetClientTeam(inflictor) && client_index != inflictor)
		return Plugin_Handled;
	
	if (IsClientTeamCameras(client_index))
		DestroyCamera(victim, false);
	else if (IsClientTeamDrones(client_index))
		DestroyDrone(victim, false);
	
	return Plugin_Continue;
}

public Action Hook_TakeDamagePlayer(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	return Plugin_Handled;
}

public Action CommandDrop(int client_index, const char[] command, int argc)
{
	if (IsClientInGear(client_index))
		return Plugin_Handled;
	
	int weapon_index = GetEntPropEnt(client_index, Prop_Send, "m_hActiveWeapon");
	if (IsWeaponGear(weapon_index))
	{
		PrintHintText(client_index, "You cannot drop your gear");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action CommandJoinTeam(int client_index, const char[] command, int argc)
{
	if (IsClientInGear(client_index))
		ResetPlayer(client_index)
	return Plugin_Continue;
}

/************************************************************************************************************
 *											FAKE PLAYER RELATED
 ************************************************************************************************************/

public void RemoveHealth(int client_index, float damage, int attacker, int damagetype, char[] weapon)
{
	
	int health = GetClientHealth(client_index);
	int dmg = RoundToNearest(damage);
	if (health > dmg)
		SetEntityHealth(client_index, health - dmg);
	else
	{
		CloseGear(client_index);
		SetEntityHealth(client_index, 1);// Make sure he dies from the dealdamage
		DealDamage(client_index, dmg, attacker, damagetype, weapon);
	}
}

public void DealDamage(int victim, int damage, int attacker, int dmgType, char[] weapon)
{
	if(victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage > 0)
	{
		char c_dmg[16];
		IntToString(damage, c_dmg, sizeof(c_dmg));
		char c_dmgType[32];
		IntToString(dmgType, c_dmgType, sizeof(c_dmgType));
		char c_victim[16];
		IntToString(victim, c_victim, sizeof(c_victim));
		int pointHurt = CreateEntityByName("point_hurt");
		if(IsValidEntity(pointHurt))
		{
			DispatchKeyValue(victim, "targetname", c_victim);
			DispatchKeyValue(pointHurt, "DamageTarget", c_victim);
			DispatchKeyValue(pointHurt, "Damage", c_dmg);
			DispatchKeyValue(pointHurt, "DamageType", c_dmgType);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt, "classname", weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt, "Hurt", (attacker > 0) ? attacker : -1);
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

public void CreateFakePlayer(int client_index, bool isCam)
{
	int fake = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(fake)) {
		char modelName[PLATFORM_MAX_PATH];
		GetEntPropString(client_index, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
		SetEntityModel(fake, modelName);
		SetEntPropEnt(fake, Prop_Send, "m_hOwnerEntity", client_index);
		
		float pos[3], rot[3];
		GetClientEyeAngles(client_index, rot);
		rot[0] = 0.0;
		GetEntPropVector(client_index, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(fake, pos, rot, NULL_VECTOR);
		DispatchKeyValue(fake, "Solid", "6");
		DispatchSpawn(fake);
		ActivateEntity(fake);
		
		
		SDKHook(fake, SDKHook_OnTakeDamage, Hook_TakeDamageFakePlayer);
		
		//SetVariantString("ACT_IDLE"); AcceptEntityInput(fake, "SetAnimation"); // Can't find sequence ?!
		
		if (isCam)
			fakePlayersListCamera[client_index] = fake;
		else
			fakePlayersListDrones[client_index] = fake;
	}
}

/************************************************************************************************************
 *											TESTS
 ************************************************************************************************************/

public bool IsWeaponGear(int weapon_index)
{
	char weapon_name[64];
	GetEntityClassname(weapon_index, weapon_name, sizeof(weapon_name))
	return StrEqual(weapon_name, gearWeapon, false);
}

public bool IsClientInGear(int client_index)
{
	return IsClientInCam(client_index) || IsClientInDrone(client_index);
}

public bool IsClientInCam(int client_index)
{
	return activeCam[client_index][0] > MAXPLAYERS;
}

public bool IsClientInDrone(int client_index)
{
	return activeDrone[client_index][0] > MAXPLAYERS;
}

public bool IsClientTeamCameras(int client_index)
{
	return playerGearOverride[client_index] != -1 && GetClientTeam(client_index) > 1 && (((GetClientTeam(client_index) == cvar_gearteam.IntValue || cvar_gearteam.IntValue == 1) && playerGearOverride[client_index] == 0) || playerGearOverride[client_index] == 1);
}

public bool IsClientTeamDrones(int client_index)
{
	return playerGearOverride[client_index] != -1 && GetClientTeam(client_index) > 1 && (((GetClientTeam(client_index) != cvar_gearteam.IntValue || cvar_gearteam.IntValue == 0) && playerGearOverride[client_index] == 0) || playerGearOverride[client_index] == 2);
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}

/************************************************************************************************************
 *											PLAYER VIEW
 ************************************************************************************************************/

public int GetViewModelIndex(int client_index)
{
	int index = MAXPLAYERS;
	while ((index = FindEntityByClassname(index, "predicted_viewmodel")) != -1)
	{
		int owner = GetEntPropEnt(index, Prop_Send, "m_hOwner");
		
		if (owner != client_index)
			continue;
		
		return index;
	}
	return -1;
}

public void SetViewModel(int client_index, bool enabled)
{
	int EntEffects = GetEntProp(clientsViewmodels[client_index], Prop_Send, "m_fEffects");
	if (enabled)
		EntEffects |= ~32;
	else
		EntEffects |= 32; // Set to Nodraw
	SetEntProp(clientsViewmodels[client_index], Prop_Send, "m_fEffects", EntEffects);
}

public void SetGearScreen(int client, bool isActive)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	int duration = 255;
	int holdtime = 255;
	int color[4];
	if (isActive)
		 color[3] = 128
	else
		color[3] = 0;
	color[0] = 120;
	color[1] = 120;
	color[2] = 120;
	
	Handle message = StartMessageOne("Fade",client);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration); //fade
		PbSetInt(message, "hold_time", holdtime); //blind
		PbSetInt(message, "flags", FFADE_STAYOUT|FFADE_PURGE);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message,duration);
		BfWriteShort(message,holdtime);
		BfWriteShort(message, FFADE_STAYOUT|FFADE_PURGE);
		BfWriteByte(message,color[0]);
		BfWriteByte(message,color[1]);
		BfWriteByte(message,color[2]);
		BfWriteByte(message,color[3]);
	}
	
	EndMessage();
}

public void HideHudGuns(int client_index)
{
	SetEntProp(client_index, Prop_Send, "m_iHideHUD", HIDEHUD_WEAPONSELECTION);
}

/************************************************************************************************************
 *											CONVARS
 ************************************************************************************************************/

public void OnDroneSpeedChange(ConVar convar, char[] oldValue, char[] newValue)
{
	droneSpeed = convar.FloatValue;
}

public void OnDroneJumpChange(ConVar convar, char[] oldValue, char[] newValue)
{
	droneJumpForce = convar.FloatValue;
}