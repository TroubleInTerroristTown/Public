#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <ttt_knockout>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Grabber Mod"
#define GRAB_DISTANCE 150.0

ConVar g_cColored = null;
ConVar g_cBlockJump = null;
ConVar g_cShowNames = null;
ConVar g_cGrabAlive = null;
ConVar g_cGrabNonMoveAlive = null;
ConVar g_cLogBlacklist = null;
ConVar g_cLogWhitelist = null;
ConVar g_cFlags = null;

int g_iSprite = -1;

int g_iObject[MAXPLAYERS + 1] =  { 0, ... };

float g_fDistance[MAXPLAYERS + 1] =  { 0.0, ... };
float g_fTime[MAXPLAYERS + 1] =  { 0.0, ... };

ArrayList g_aWhitelist = null;
ArrayList g_aBlacklist = null;


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

	StartConfig("grabbermod");
	CreateConVar("ttt2_grabbermod_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLogWhitelist = AutoExecConfig_CreateConVar("gbm_log_whitelist", "1", "Log whitelist?", _, true, 0.0, true, 1.0);
	g_cLogBlacklist = AutoExecConfig_CreateConVar("gbm_log_blacklist", "1", "Log blacklist?", _, true, 0.0, true, 1.0);
	g_cColored = AutoExecConfig_CreateConVar("gbm_colored", "1", "Colored laser beam for grab (new color every second)?", _, true, 0.0, true, 1.0);
	g_cBlockJump = AutoExecConfig_CreateConVar("gbm_block_jump", "1", "Block jump on \"grabbed\" entities to prevent abusing?", _, true, 0.0, true, 1.0);
	g_cGrabAlive = AutoExecConfig_CreateConVar("gbm_grab_alive", "0", "Grab living players?", _, true, 0.0, true, 1.0);
	g_cGrabNonMoveAlive = AutoExecConfig_CreateConVar("gbm_grab_non_move_alive", "0", "Grab living non moveable players?", _, true, 0.0, true, 1.0);
	g_cShowNames = AutoExecConfig_CreateConVar("gbm_show_name", "0", "Show names of entities? Useful to add this on blacklist/whitelist.", _, true, 0.0, true, 1.0);
	g_cFlags = AutoExecConfig_CreateConVar("gbm_admin_flags", "z", "Admin flags to get access for gbm_show_name");
	EndConfig();
	
	LoadLists();

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
	
	if (g_cShowNames.BoolValue)
	{
		char sAccess[16];
		g_cFlags.GetString(sAccess, sizeof(sAccess));
		
		if (TTT_HasFlags(client, sAccess))
		{
			CPrintToChat(client, "Name of Entity: %s", sName);
		}
	}
	
	// true is a positive found on the blacklist or negative found on the whitelist 
	if (CheckLists(sName))
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
		
		// true is a positive found on the blacklist or negative found on the whitelist 
		if (CheckLists(sTargetname))
		{
			return;
		}
	}
	
	if (!g_cGrabAlive.BoolValue)
	{
		if (TTT_IsClientValid(ent) && IsPlayerAlive(ent))
		{
			if (!g_cGrabNonMoveAlive.BoolValue || (g_cGrabNonMoveAlive.BoolValue && GetEntityMoveType(ent) != MOVETYPE_NONE))
			{
				return;
			}
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
	int iObject = g_iObject[client];
	if (iObject != -1 && IsValidEntity(iObject) && IsValidEdict(iObject))
	{
		return (true);
	}
	return (false);
}

stock int GetObject(int client, bool hitSelf=true)
{
	int iEntity = -1;

	if (IsClientInGame(client))
	{
		if (ValidGrab(client))
		{
			iEntity = EntRefToEntIndex(g_iObject[client]);
			return (iEntity);
		}

		iEntity = TraceToEntity(client);

		if (IsValidEntity(iEntity) && IsValidEdict(iEntity))
		{
			char sName[64];
			GetEdictClassname(iEntity, sName, sizeof(sName));
			if (StrEqual(sName, "worldspawn"))
			{
				if (hitSelf)
				{
					iEntity = client;
				}
				else
				{
					iEntity = -1;
				}
			}
		}
		else
		{
			iEntity = -1;
		}
	}

	return iEntity;
}

public int TraceToEntity(int client)
{
	float fEyePos[3], fEyeAngle[3];
	GetClientEyePosition(client, fEyePos);
	GetClientEyeAngles(client, fEyeAngle);

	TR_TraceRayFilter(fEyePos, fEyeAngle, MASK_PLAYERSOLID, RayType_Infinite, TraceASDF, client);

	if (TR_DidHit(null))
	{
		return (TR_GetEntityIndex(null));
	}

	return -1;
}

public bool TraceASDF(int entity, int mask, any data)
{
	return (data != entity);
}

stock int ReplacePhysicsEntity(int iEntity)
{
	float fOrigin[3], fAngle[3];

	char model[128];
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", model, sizeof(model));
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngle);
	AcceptEntityInput(iEntity, "Wake");
	AcceptEntityInput(iEntity, "EnableMotion");
	AcceptEntityInput(iEntity, "EnableDamageForces");
	DispatchKeyValue(iEntity, "physdamagescale", "0.0");

	TeleportEntity(iEntity, fOrigin, fAngle, NULL_VECTOR);
	SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);

	return iEntity;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	if (buttons & IN_JUMP)
	{
		if (g_cBlockJump.BoolValue)
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

				if (g_cColored.BoolValue)
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

void LoadLists()
{
	LoadWhitelist();
	LoadBlacklist();
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
			
			if (g_cLogWhitelist.BoolValue)
			{
				LogMessage("[GrabberMod] (LoadWhitelist) Add %s to array...", sBuffer);
			}
		}
	}
	
	delete hFile;
}

void LoadBlacklist()
{
	if (g_aBlacklist != null)
	{
		g_aBlacklist.Clear();
	}
	else
	{
		g_aBlacklist = new ArrayList(32);
	}
	
	char sPath[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/blacklist_grabbermod.ini");

	Handle hFile = OpenFile(sPath, "rt");

	if (!FileExists(sPath))
	{
		SetFailState("Can't find the following file: \"configs/ttt/blacklist_grabbermod.ini\"");
		return;
	}
	
	char sBuffer[32];
	while(!IsEndOfFile(hFile) && ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
	{
		if (strlen(sBuffer) > 2)
		{
			g_aBlacklist.PushString(sBuffer);
			
			if (g_cLogBlacklist.BoolValue)
			{
				LogMessage("[GrabberMod] (LoadBlacklist) Add %s to array...", sBuffer);
			}
		}
	}
	
	delete hFile;
}

bool CheckBlacklist(const char[] name)
{
	char sBuffer[32];
	
	if (g_aBlacklist.Length > 0)
	{
		for (int i = 0; i < g_aBlacklist.Length; i++)
		{
			g_aBlacklist.GetString(i, sBuffer, sizeof(sBuffer));
			
			if (strlen(sBuffer) > 1 && StrContains(sBuffer, name, false) != -1)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool CheckWhitelist(const char[] name)
{
	char sBuffer[32];
	
	if (g_aWhitelist.Length > 0)
	{
		for (int i = 0; i < g_aWhitelist.Length; i++)
		{
			g_aWhitelist.GetString(i, sBuffer, sizeof(sBuffer));
			
			if (strlen(sBuffer) > 1 && StrContains(sBuffer, name, false) != -1)
			{
				return true;
			}
		}
	}
	
	return false;
}

bool CheckLists(const char[] name)
{
	if (CheckBlacklist(name) && !CheckWhitelist(name))
	{
		return true;
	}
	
	return false;
}
