#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <multicolors>
#include <config_loader>

#undef REQUIRE_PLUGIN
#include <ttt_knockout>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Grabber Mod"
#define GRAB_DISTANCE 150.0

bool g_LogWhitelist = false;
bool g_bColored = true;
bool g_bBlockJump = true;
bool g_bShowNames = false;
char g_sFlags[16];

int g_iSprite = -1;

int g_iObject[MAXPLAYERS + 1] =  { 0, ... };

float g_fDistance[MAXPLAYERS + 1] =  { 0.0, ... };
float g_fTime[MAXPLAYERS + 1] =  { 0.0, ... };

char g_cConfigFile[PLATFORM_MAX_PATH];

ArrayList g_aWhitelist = null;

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
	
	g_LogWhitelist = Config_LoadBool("gbm_log_whitelist", false, "Log whitelist?");
	g_bColored = Config_LoadBool("gbm_colored", true, "Colored laser beam for grab (new color every second)?");
	g_bBlockJump = Config_LoadBool("gbm_block_jump", true, "Block jump on \"grabbed\" entities to prevent abusing?");
	
	g_bShowNames = Config_LoadBool("gbm_show_name", false, "Show names of entities? Useful to add this on whitelist.");
	Config_LoadString("gbm_admin_flags", "z", "Admin flags to get access for gbm_show_name", g_sFlags, sizeof(g_sFlags));
	
	Config_Done();
	
	LoadWhitelist();

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
		char sName[128];
		GetEdictClassname(g_iObject[client], sName, 128);

		if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox") || StrEqual(sName, "prop_physics"))
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
	
	char sName[128];
	GetEdictClassname(ent, sName, sizeof(sName));
	
	if (g_bShowNames)
	{
		if (TTT_HasFlags(client, g_sFlags))
		{
			CPrintToChat(client, "Name of Entity: %s", sName);
		}
	}
	
	bool bFound = false;
	char sBuffer[32];
	
	if (g_aWhitelist.Length > 0)
	{
		for (int i = 0; i < g_aWhitelist.Length; i++)
		{
			g_aWhitelist.GetString(i, sBuffer, sizeof(sBuffer));
			
			if (strlen(sBuffer) > 1 && StrContains(sBuffer, sName, false) != -1)
			{
				bFound = true;
				break;
			}
		}
	}
	else
	{
		SetFailState("[GrabberMod] (GrabSomething) Whitelist is empty, we disable grabbermod to prevent bugs/crashes!");
		return;
	}
	
	if (!bFound)
	{
		return;
	}
	
	if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox"))
	{
		if (IsValidEdict(ent) && IsValidEntity(ent))
		{
			ent = ReplacePhysicsEntity(ent);

			SetEntPropEnt(ent, Prop_Data, "m_hPhysicsAttacker", client);
			SetEntPropFloat(ent, Prop_Data, "m_flLastPhysicsInfluenceTime", GetEngineTime());
		}
	}
	
	if (StrEqual(sName, "prop_ragdoll", false))
	{
		char sTargetname[32];
		GetEntPropString(ent, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
		
		if (StrContains(sTargetname, "fpd_ragdoll", false) != -1)
		{
			return;
		}
	}

	if (GetEntityMoveType(ent) == MOVETYPE_NONE)
	{
		if (strncmp("player", sName, 5, false) != 0)
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
			char sName[64];
			GetEdictClassname(ent, sName, 64);
			if (StrEqual(sName, "worldspawn"))
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
	GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));
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

void LoadWhitelist()
{
	if (g_aWhitelist != null)
	{
		g_aWhitelist.Clear();
	}
	else
	{
		g_aWhitelist = new ArrayList(32);
	}
	
	char sPath[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/whitelist_grabbermod.ini");

	Handle hFile = OpenFile(sPath, "rt");

	if (!FileExists(sPath))
	{
		SetFailState("Can't find the following file: \"configs/ttt/whitelist_grabbermod.ini\"");
		return;
	}
	
	char sBuffer[32];
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
	{
		if (strlen(sBuffer) > 2)
		{
			g_aWhitelist.PushString(sBuffer);
			
			if (g_LogWhitelist)
			{
				LogMessage("[GrabberMod] (LoadWhitelist) Add %s to array...", sBuffer);
			}
		}
	}
	
	delete hFile;
}
