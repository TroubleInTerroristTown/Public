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

#include <sdktools>
#include <sdkhooks>

// SOUNDS
char openCamSound[] = "weapons/movement3.wav";
char destroyCamSound[] = "physics/metal/metal_box_impact_bullet1.wav";
// MODELS
char InCamModel[] = "models/chicken/festive_egg.mdl"; // must have hitbox or it will use the default player one
char camModel[] = "models/weapons/w_eq_sensorgrenade_thrown.mdl";
char camPhysModel[] = "models/props/de_inferno/hr_i/ground_stone/ground_stone.mdl"; // Must surround cam
// LISTS
ArrayList camerasList;
ArrayList camerasModelList;
ArrayList camOwnersList;
int activeCam[MAXPLAYERS + 1][3]; // 0: phys, 1: model, 2: flash
int fakePlayersListCamera[MAXPLAYERS + 1];

int oldCollisionValue[MAXPLAYERS + 1];

public void AddCamera(int cam, int model, int client_index)
{
	camerasList.Push(cam);
	camerasModelList.Push(model);
	camOwnersList.Push(client_index);
}

public void RemoveCameraFromList(int cam)
{
	int i = camerasList.FindValue(cam);
	if (i < 0)
		return;
	camerasList.Erase(i);
	camerasModelList.Erase(i);
	camOwnersList.Erase(i);
}

public void CreateCamera(int client_index, float pos[3], float rot[3])
{
	int cam = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(cam)) {
		SetEntityModel(cam, camPhysModel);
		DispatchKeyValue(cam, "solid", "6");
		DispatchSpawn(cam);
		ActivateEntity(cam);
		
		TeleportEntity(cam, pos, rot, NULL_VECTOR);
		
		SDKHook(cam, SDKHook_OnTakeDamage, Hook_TakeDamageGear);
		SetEntityRenderMode(cam, RENDER_NONE);
		CreateCameraModel(client_index, cam);
	}
}

public void CreateCameraModel(int client_index, int cam)
{
	int model = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(model)) {
		SetEntityModel(model, camModel);
		DispatchKeyValue(model, "solid", "0");
		DispatchSpawn(model);
		ActivateEntity(model);
		
		SetVariantString("!activator"); AcceptEntityInput(model, "SetParent", cam, model, 0);
		float pos[3], rot[3];
		TeleportEntity(model, pos, rot, NULL_VECTOR);
		
		SDKHook(model, SDKHook_SetTransmit, Hook_SetTransmitGear);
		AddCamera(cam, model, client_index);
	}
}

public void CreateFlash(int client_index, int cam)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (activeCam[i][0] == cam && i != client_index)
		{
			activeCam[client_index][2] = activeCam[i][2];
			return; // Prevent from creating multiple red flashes
		}
	}
	int flash = CreateEntityByName("env_sprite");
	if (IsValidEntity(flash))
	{
		activeCam[client_index][2] = flash;
		DispatchKeyValue(flash, "spawnflags", "1");
		DispatchKeyValue(flash, "scale", "0.3");
		DispatchKeyValue(flash, "rendercolor", "255 0 0");
		DispatchKeyValue(flash, "rendermode", "5"); // Additive
		DispatchKeyValue(flash, "renderfx", "13"); // Fast Flicker
		DispatchKeyValue(flash, "model", "sprites/glow01.vmt");
		
		float pos[3], rot[3];
		GetEntPropVector(cam, Prop_Send, "m_vecOrigin", pos);
		TeleportEntity(flash, pos, rot, NULL_VECTOR);
		
		DispatchSpawn(flash);
		ActivateEntity(flash);
		
		SDKHook(flash, SDKHook_SetTransmit, Hook_SetTransmitGear);
	}
}

public void DestroyFlash(int client_index)
{
	if (!IsValidEntity(activeCam[client_index][2]))
		return;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (i != client_index && activeCam[i][2] == activeCam[client_index][2])
		{
			activeCam[client_index][2] = -1;
			return; // Prevent from deleting other player flash
		}
	}
	RemoveEdict(activeCam[client_index][2])
	activeCam[client_index][2] = -1;
}

public void Hook_PostThinkCam(int client_index)
{
	if (activeCam[client_index][0] < 0)
		return;
	
	HideHudGuns(client_index);
	SetViewModel(client_index, false);
	LowerCameraView(client_index);
}

public void LowerCameraView(int client_index)
{
	float viewPos[3];
	SetEntPropVector(client_index, Prop_Data, "m_vecViewOffset", viewPos);
}

public void TpToCam(int client_index, int cam)
{
	if (fakePlayersListCamera[client_index] < 1)
	{
		CreateFakePlayer(client_index, true);
		EmitSoundToClient(client_index, openCamSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
	}
	SetGearScreen(client_index, true);
	
	SetEntityModel(client_index, InCamModel); // Set to a small model to prevent collisions/shots
	SetEntityMoveType(client_index, MOVETYPE_NOCLIP);
	SetEntPropFloat(client_index, Prop_Data, "m_flLaggedMovementValue", 0.0);
	// Hooks
	SDKHook(client_index, SDKHook_SetTransmit, Hook_SetTransmitPlayer);
	SDKHook(client_index, SDKHook_PostThink, Hook_PostThinkCam);
	SDKHook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamagePlayer);
	// Set pos
	SetVariantString("!activator"); AcceptEntityInput(client_index, "SetParent", cam, client_index, 0);
	float pos[3], rot[3];
	TeleportEntity(client_index, pos, rot, NULL_VECTOR);
	// Set collisiosn
	oldCollisionValue[client_index] = GetEntData(client_index, GetCollOffset(), 1);
	SetEntData(client_index, GetCollOffset(), 2, 4, true);
	SetEntProp(client_index, Prop_Send, "m_nHitboxSet", 2);
	
	activeCam[client_index][0] = cam;
	activeCam[client_index][1] = camerasModelList.Get(camerasList.FindValue(cam));
	// Create flashing light
	DestroyFlash(client_index);
	CreateFlash(client_index, cam);
}

public void ExitCam(int client_index)
{
	SetGearScreen(client_index, false);
	
	char modelName[PLATFORM_MAX_PATH];
	GetEntPropString(fakePlayersListCamera[client_index], Prop_Data, "m_ModelName", modelName, sizeof(modelName));
	SetEntityModel(client_index, modelName); // Set back to original model
	
	SetViewModel(client_index, true);
	SetEntityMoveType(client_index, MOVETYPE_WALK);
	SetEntPropFloat(client_index, Prop_Data, "m_flLaggedMovementValue", 1.0);
	// Hooks
	SDKUnhook(client_index, SDKHook_SetTransmit, Hook_SetTransmitPlayer);
	SDKUnhook(client_index, SDKHook_PostThink, Hook_PostThinkCam);
	SDKUnhook(client_index, SDKHook_OnTakeDamage, Hook_TakeDamagePlayer);
	// Set pos
	AcceptEntityInput(client_index, "SetParent");
	float pos[3], rot[3];
	GetEntPropVector(fakePlayersListCamera[client_index], Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(fakePlayersListCamera[client_index], Prop_Send, "m_angRotation", rot);
	TeleportEntity(client_index, pos, rot, NULL_VECTOR);
	// Set collisions
	SetEntData(client_index, GetCollOffset(), oldCollisionValue[client_index], 1, true);
	SetEntProp(client_index, Prop_Send, "m_nHitboxSet", 0);
	// Remove props
	RemoveEdict(fakePlayersListCamera[client_index]);
	DestroyFlash(client_index);
	activeCam[client_index][0] = -1;
	activeCam[client_index][1] = -1;
	fakePlayersListCamera[client_index] = -1;
	// Sound!
	EmitSoundToClient(client_index, openCamSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL);
}

public void DestroyCamera(int cam, bool isSilent)
{
	if (!isSilent)
	{
		float pos[3];
		GetEntPropVector(cam, Prop_Send, "m_vecOrigin", pos);
		EmitSoundToAll(destroyCamSound, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,  SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);
	}
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (activeCam[i][0] == cam && IsValidClient(i))
		{
			CloseCamera(i);
		}
	}
	
	if (IsValidEdict(cam))
		RemoveEdict(cam);
	if (IsValidEdict(camerasModelList.Get(camerasList.FindValue(cam))))
		RemoveEdict(camerasModelList.Get(camerasList.FindValue(cam)));
	RemoveCameraFromList(cam);
}
