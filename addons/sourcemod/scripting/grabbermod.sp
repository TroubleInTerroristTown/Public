#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

#define GRAB_DISTANCE 150.0

new g_sprite;
new	EngineVersion:CurrentVersion;
	
public Plugin:myinfo =
{
	name = "SM Grabber mod",
	author = "Franc1sco Steam: franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};


new gObj[MAXPLAYERS+1];
new Float:gDistance[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateTimer(0.1, Adjust, _, TIMER_REPEAT);
	
	CurrentVersion = GetEngineVersion();
}

public OnMapStart()
{
	if(CurrentVersion == Engine_CSGO) g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	else g_sprite = PrecacheModel("materials/sprites/laser.vmt");
}

Command_Grab(client)
{
	GrabSomething(client);
}

Command_UnGrab(client)
{
	if (ValidGrab(client))
	{
		new String:edictname[128];
		GetEdictClassname(gObj[client], edictname, 128);
		
		if (StrEqual(edictname, "prop_physics") || StrEqual(edictname, "prop_physics_multiplayer") || StrEqual(edictname, "func_physbox") || StrEqual(edictname, "prop_physics"))
			SetEntPropEnt(gObj[client], Prop_Data, "m_hPhysicsAttacker", 0);
	}
	
	gObj[client] = -1;
}

stock GrabSomething(client)
{

		new ent;
		new Float:VecPos_Ent[3], Float:VecPos_Client[3];
		
		ent = GetObject(client, false);
		
		if (ent == -1)
			return;
		
		ent = EntRefToEntIndex(ent);
		
		if (ent == INVALID_ENT_REFERENCE)
			return;

			
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", VecPos_Ent);
		GetClientEyePosition(client, VecPos_Client);
		if(GetVectorDistance(VecPos_Ent, VecPos_Client, false) > 150.0) return;
		
		// only grab physics entities
		new String:edictname[128];
		GetEdictClassname(ent, edictname, 128);

		if (StrContains(edictname, "prop_", false) == -1 || StrContains(edictname, "door", false) != -1)
		{
			return;
		}
		else
		{
			if (StrEqual(edictname, "prop_physics") || StrEqual(edictname, "prop_physics_multiplayer") || StrEqual(edictname, "func_physbox") || StrEqual(edictname, "prop_physics"))
			{
				// Convert to prop_physics_override
				if (IsValidEdict(ent) && IsValidEntity(ent)) 
				{
					ent = ReplacePhysicsEntity(ent);
					
					SetEntPropEnt(ent, Prop_Data, "m_hPhysicsAttacker", client);
					SetEntPropFloat(ent, Prop_Data, "m_flLastPhysicsInfluenceTime", GetEngineTime());
				}
			}
		}

		if (GetEntityMoveType(ent) == MOVETYPE_NONE)
		{
			if (strncmp("player", edictname, 5, false)!=0)
			{
				SetEntityMoveType(ent, MOVETYPE_VPHYSICS);

				PrintHintText(client, "Object ist now Unfreezed");
			}
			else
			{
				SetEntityMoveType(ent, MOVETYPE_WALK);
				return;
			}
		}

		gObj[client] = EntIndexToEntRef(ent);

		gDistance[client] = GetVectorDistance(VecPos_Ent, VecPos_Client, false);

		new Float:position[3];
		TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, position);
		
		//EmitSoundToClient(client, "buttons/combine_button5.wav");

}

stock bool:ValidGrab(client)
{
	new obj = gObj[client];
	if (obj != -1 && IsValidEntity(obj) && IsValidEdict(obj))
		return (true);


	return (false);
}

stock GetObject(client, bool:hitSelf=true)
{
	new ent = -1;
	
	if (IsClientInGame(client))
	{
		if (ValidGrab(client))
		{
			ent = EntRefToEntIndex(gObj[client]);
			return (ent);
		}

		ent = TraceToEntity(client); // GetClientAimTarget(client);
		
		if (IsValidEntity(ent) && IsValidEdict(ent))
		{
			new String:edictname[64];
			GetEdictClassname(ent, edictname, 64);
			if (StrEqual(edictname, "worldspawn"))
			{
				if (hitSelf)
					ent = client;
				else
					ent = -1;
			}
		}
		else
		{
			ent = -1;
		}
	}
	
	return (ent);
}

public TraceToEntity(client)
{
	new Float:vecClientEyePos[3], Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);
	GetClientEyeAngles(client, vecClientEyeAng);    

	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceASDF, client);

	if (TR_DidHit(INVALID_HANDLE))
		return (TR_GetEntityIndex(INVALID_HANDLE));

	return (-1);
}

public bool:TraceASDF(entity, mask, any:data)
{
	return (data != entity);
}

stock ReplacePhysicsEntity(ent)
{
	new Float:VecPos_Ent[3], Float:VecAng_Ent[3];

	// Copy Entity
	new String:model[128];
	GetEntPropString(ent, Prop_Data, "m_ModelName", model, 128);
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", VecPos_Ent);
	GetEntPropVector(ent, Prop_Send, "m_angRotation", VecAng_Ent);
	AcceptEntityInput(ent, "Wake");
	AcceptEntityInput(ent, "EnableMotion");
	AcceptEntityInput(ent, "EnableDamageForces");
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	
/*
	RemoveEdict(ent);

	//decl Ent;
	PrecacheModel(model, true);
	ent = CreateEntityByName("prop_physics_override"); 
	
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	DispatchKeyValue(ent, "model", model);
	DispatchSpawn(ent);
*/
	TeleportEntity(ent, VecPos_Ent, VecAng_Ent, NULL_VECTOR);
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);

	return (ent);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3])
{
	if(!IsClientInGame(client)) return;
	
	if(buttons & IN_USE)
	{
		if(IsPlayerAlive(client) && !ValidGrab(client)) Command_Grab(client);
	}
	else if(ValidGrab(client))
	{
		Command_UnGrab(client);
	}
}

public Action:Adjust(Handle:timer)
{	
	
	new Float:vecDir[3], Float:vecPos[3], Float:vecPos2[3], Float:vecVel[3];
	new Float:viewang[3];

	for(new i = 1; i <=MaxClients; ++i)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (ValidGrab(i))
			{
				// get client info
				GetClientEyeAngles(i, viewang);
				GetAngleVectors(viewang, vecDir, NULL_VECTOR, NULL_VECTOR);
				GetClientEyePosition(i, vecPos);
				
				new color[4];
				color[0] = 255; 
				color[1] = 0;
				color[2] = 0;
				color[3] = 255;
				vecPos2 = vecPos;
				// update object
				vecPos[0]+=vecDir[0]*gDistance[i];
				vecPos[1]+=vecDir[1]*gDistance[i];
				vecPos[2]+=vecDir[2]*gDistance[i];
			
				GetEntPropVector(gObj[i], Prop_Send, "m_vecOrigin", vecDir);
				
				
				TE_SetupBeamPoints(vecPos2, vecDir, g_sprite, 0, 0, 0, 0.1, 3.0, 3.0, 10, 0.0, color, 0);
				TE_SendToAll();
			
				SubtractVectors(vecPos, vecDir, vecVel);
				ScaleVector(vecVel, 10.0);
			
				TeleportEntity(gObj[i], NULL_VECTOR, NULL_VECTOR, vecVel);
			}
		}
}

public OnClientDisconnect(client)
{
	gObj[client] = -1;
}