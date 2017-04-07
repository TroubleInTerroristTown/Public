#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <config_loader>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Grabber Mod"
#define GRAB_DISTANCE 150.0

bool g_bColored = true;
bool g_bBlockJump = true;

int g_iSprite = -1;

int g_iObject[MAXPLAYERS + 1] =  { 0, ... };

float g_fDistance[MAXPLAYERS + 1] =  { 0.0, ... };
float g_fTime[MAXPLAYERS + 1] =  { 0.0, ... };

char g_cConfigFile[PLATFORM_MAX_PATH];

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
	
	BuildPath(Path_SM, g_cConfigFile, sizeof(g_cConfigFile), "configs/ttt/grabbermod.cfg");
	Config_Setup("TTT", g_cConfigFile);
	g_bColored = Config_LoadBool("gbm_colored", true, "Colored laser beam for grab (new color every second)?");
	g_bBlockJump = Config_LoadBool("gbm_block_jump", true, "Block jump on \"grabbed\" entities to prevent abusing?");
	Config_Done();
	
	CreateTimer(0.1, Adjust, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	g_iSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

stock void Command_Grab(int client)
{
	GrabSomething(client);
}

stock void Command_UnGrab(int client)
{
	if (ValidGrab(client))
	{
		char edictname[128];
		GetEdictClassname(g_iObject[client], edictname, 128);
		
		if (StrEqual(edictname, "prop_physics") || StrEqual(edictname, "prop_physics_multiplayer") || StrEqual(edictname, "func_physbox") || StrEqual(edictname, "prop_physics"))
		{
			SetEntPropEnt(g_iObject[client], Prop_Data, "m_hPhysicsAttacker", 0);
		}
	}
	
	g_iObject[client] = -1;
	g_fTime[client] = 0.0;
}

stock void GrabSomething(int client)
{

		int ent;
		float VecPos_Ent[3], VecPos_Client[3];
		
		ent = GetObject(client, false);
		
		if (ent == -1)
		{
			return;
		}
		
		ent = EntRefToEntIndex(ent);
		
		if (ent == INVALID_ENT_REFERENCE)
		{
			return;
		}
			
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", VecPos_Ent);
		GetClientEyePosition(client, VecPos_Client);
		if (GetVectorDistance(VecPos_Ent, VecPos_Client, false) > 150.0)
		{
			return;
		}
		
		char edictname[128];
		GetEdictClassname(ent, edictname, sizeof(edictname));

		if (StrContains(edictname, "prop_", false) == -1 || StrContains(edictname, "door", false) != -1)
		{
			return;
		}
		else
		{
			if (StrEqual(edictname, "prop_physics") || StrEqual(edictname, "prop_physics_multiplayer") || StrEqual(edictname, "func_physbox"))
			{
				
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
			if (strncmp("player", edictname, 5, false) != 0)
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

		g_iObject[client] = EntIndexToEntRef(ent);

		g_fDistance[client] = GetVectorDistance(VecPos_Ent, VecPos_Client, false);

		float position[3];
		TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, position);

}

stock bool ValidGrab(int client)
{
	int obj = g_iObject[client];
	if (obj != -1 && IsValidEntity(obj) && IsValidEdict(obj))
	{
		return (true);
	}
	return (false);
}

stock int GetObject(int client, bool hitSelf=true)
{
	int ent = -1;
	
	if (IsClientInGame(client))
	{
		if (ValidGrab(client))
		{
			ent = EntRefToEntIndex(g_iObject[client]);
			return (ent);
		}

		ent = TraceToEntity(client);
		
		if (IsValidEntity(ent) && IsValidEdict(ent))
		{
			char edictname[64];
			GetEdictClassname(ent, edictname, 64);
			if (StrEqual(edictname, "worldspawn"))
			{
				if (hitSelf)
				{
					ent = client;
				}
				else
				{
					ent = -1;
				}
			}
		}
		else
		{
			ent = -1;
		}
	}
	
	return (ent);
}

public int TraceToEntity(int client)
{
	float vecClientEyePos[3], vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);
	GetClientEyeAngles(client, vecClientEyeAng);    

	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceASDF, client);

	if (TR_DidHit(null))
	{
		return (TR_GetEntityIndex(null));
	}

	return (-1);
}

public bool TraceASDF(int entity, int mask, any data)
{
	return (data != entity);
}

stock int ReplacePhysicsEntity(int ent)
{
	float VecPos_Ent[3], VecAng_Ent[3];

	char model[128];
	GetEntPropString(ent, Prop_Data, "m_ModelName", model, 128);
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", VecPos_Ent);
	GetEntPropVector(ent, Prop_Send, "m_angRotation", VecAng_Ent);
	AcceptEntityInput(ent, "Wake");
	AcceptEntityInput(ent, "EnableMotion");
	AcceptEntityInput(ent, "EnableDamageForces");
	DispatchKeyValue(ent, "physdamagescale", "0.0");
	
	TeleportEntity(ent, VecPos_Ent, VecAng_Ent, NULL_VECTOR);
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);

	return (ent);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if (buttons & IN_JUMP)
	{
		if (g_bBlockJump)
		{
			int iEnt = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
			
			if (iEnt > 0)
			{
				char sName[128];
				GetEdictClassname(iEnt, sName, sizeof(sName));
				
				if (StrContains(sName, "prop_", false) == -1 || StrContains(sName, "door", false) != -1)
				{
					return Plugin_Continue;
				}
				else
				{
					if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox") || StrEqual(sName, "prop_physics"))
					{
						if (IsValidEdict(iEnt) && IsValidEntity(iEnt)) 
						{
							buttons &= ~IN_JUMP;
							return Plugin_Changed;
						}
					}
				}
			}
		}
	}
	
	if (buttons & IN_USE)
	{
		if (IsPlayerAlive(client) && !ValidGrab(client))
		{
			Command_Grab(client);
		}
	}
	else if (ValidGrab(client))
	{
		Command_UnGrab(client);
	}
	
	return Plugin_Continue;
}

public Action Adjust(Handle timer)
{	
	
	float vecDir[3];
	float vecPos[3];
	float vecPos2[3];
	float vecVel[3];
	float viewang[3];

	LoopValidClients(i)
	{
		if (IsPlayerAlive(i))
		{
			if (ValidGrab(i))
			{
				GetClientEyeAngles(i, viewang);
				GetAngleVectors(viewang, vecDir, NULL_VECTOR, NULL_VECTOR);
				GetClientEyePosition(i, vecPos);
				
				int color[4];
				
				if (g_bColored)
				{
					if (g_fTime[i] == 0.0 || GetGameTime() < g_fTime[i])
					{
						color[0] = GetRandomInt(0, 255); 
						color[1] = GetRandomInt(0, 255); 
						color[2] = GetRandomInt(0, 255); 
						color[3] = 255;
					}
				}
				else
				{
					color[0] = 255; 
					color[1] = 0; 
					color[2] = 0;
					color[3] = 255;
				}
				
				vecPos2 = vecPos;
				vecPos[0] += vecDir[0] * g_fDistance[i];
				vecPos[1] += vecDir[1] * g_fDistance[i];
				vecPos[2] += vecDir[2] * g_fDistance[i];
			
				GetEntPropVector(g_iObject[i], Prop_Send, "m_vecOrigin", vecDir);
				
				TE_SetupBeamPoints(vecPos2, vecDir, g_iSprite, 0, 0, 0, 0.1, 3.0, 3.0, 10, 0.0, color, 0);
				TE_SendToAll();
				
				g_fTime[i] = GetGameTime() + 1.0;
			
				SubtractVectors(vecPos, vecDir, vecVel);
				ScaleVector(vecVel, 10.0);
			
				TeleportEntity(g_iObject[i], NULL_VECTOR, NULL_VECTOR, vecVel);
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_iObject[client] = -1;
	g_fTime[client] = 0.0;
}