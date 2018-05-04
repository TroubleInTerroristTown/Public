#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <emitsoundany>

#pragma semicolon 1
#pragma newdecls required

#define TRACE_START 24.0
#define TRACE_END 64.0

#define MDL_LASER "materials/sprites/purplelaser1.vmt"

#define SND_MINEPUT "weapons/g3sg1/g3sg1_slideback.wav"
#define SND_MINEACT "items/nvg_on.wav"

#define COLOR_T "255 0 0"
#define COLOR_CT "0 0 255"
#define COLOR_DEF "0 255 255"

#define DEFAULT_MODEL "models/tripmine/tripmine.mdl"

// globals
int g_iRemaining[MAXPLAYERS+1];		// how many tripmines player has this spawn
int g_iCount = 1;
char g_sModel[PLATFORM_MAX_PATH + 1];

// convars
ConVar g_cActTime = null;
ConVar g_cModel = null;

Handle g_hOnPlant = null;
Handle g_hPlanted = null;
Handle g_hReady = null;

public Plugin myinfo = {
	name = "Tripmines 2016 Update",
	author = "404, Bara",
	description = "That old L. Duke Tripmines plugin, updated to actually fucking work.",
	version = "1.0 ( will be never updated :) )",
	url = "unfgaming.net, csgottt.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnPlant = CreateGlobalForward("Tripmine_OnPlant", ET_Event, Param_Cell);
	g_hPlanted = CreateGlobalForward("Tripmine_Planted", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hReady = CreateGlobalForward("Tripmine_Ready", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	CreateNative("Tripmine_GetClientMines", Native_GetClientMines);
	CreateNative("Tripmine_AddClientMines", Native_AddClientMines);
	CreateNative("Tripmine_SetClientMines", Native_SetClientMines);

	RegPluginLibrary("tripmines");

	return APLRes_Success;
}

public void OnPluginStart() 
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

	g_cActTime = CreateConVar("sm_tripmines_activate_time", "3.0");
	g_cModel = CreateConVar("sm_tripmines_model", DEFAULT_MODEL);

	// commands
	RegConsoleCmd("sm_tripmine", Command_TripMine);
}

public void OnMapStart()
{
	// set model based on cvar
	g_cModel.GetString(g_sModel, sizeof(g_sModel));
	
	// precache models
	int iIndex1 = PrecacheModel(g_sModel);
	AddFileToDownloadsTable("models/tripmine/tripmine.dx90.vtx");
	AddFileToDownloadsTable("models/tripmine/tripmine.mdl");
	AddFileToDownloadsTable("models/tripmine/tripmine.phy");
	AddFileToDownloadsTable("models/tripmine/tripmine.vvd");
	AddFileToDownloadsTable("materials/models/tripmine/minetexture.vmt");
	AddFileToDownloadsTable("materials/models/tripmine/minetexture.vtf");

	int iIndex2 = PrecacheModel(MDL_LASER, true);
	
	// precache sounds
	int iIndex3 = PrecacheSound(SND_MINEPUT, true);
	int iIndex4 = PrecacheSound(SND_MINEACT, true);

	LogMessage("(OnMapStart) %s: %d, %s: %d, %s: %d, %s: %d", g_sModel, iIndex1, MDL_LASER, iIndex2, SND_MINEPUT, iIndex3, SND_MINEACT, iIndex4);
}

// When a new client is put in the server we reset their mines count
public void OnClientPutInServer(int client)
{
	if(client && !IsFakeClient(client))
	{
		g_iRemaining[client] = 0;
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_iRemaining[client] = 0;
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_iRemaining[client] = 0;
	
	return Plugin_Continue;
}

public Action Command_TripMine(int client, int args)
{	
	// make sure client is not spectating
	if (client < 0 || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	// call SetMine if any remain in client's inventory
	if (g_iRemaining[client] > 0)
	{
		SetMine(client);
	}
	else
	{
		PrintHintText(client, "You do not have any tripmines.");
	}
	return Plugin_Handled;
}

void SetMine(int client)
{
	// setup unique target names for entities to be created with
	char beam[64];
	char beammdl[64];
	char tmp[128];
	
	Format(beam, sizeof(beam), "tmbeam%d", g_iCount);
	Format(beammdl, sizeof(beammdl), "tmbeammdl%d", g_iCount);
	
	g_iCount++;
	if (g_iCount > 10000)
	{
		g_iCount = 1;
	}

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnPlant);
	Call_PushCell(client);
	Call_Finish(res);

	if (res == Plugin_Handled || res == Plugin_Stop)
	{
		return;
	}
	
	// trace client view to get position and angles for tripmine
	
	float start[3];
	float angle[3];
	float end[3];
	float normal[3];
	float beamend[3];
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angle);
	GetAngleVectors(angle, end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(end, end);

	start[0]=start[0]+end[0]*TRACE_START;
	start[1]=start[1]+end[1]*TRACE_START;
	start[2]=start[2]+end[2]*TRACE_START;
	
	end[0]=start[0]+end[0]*TRACE_END;
	end[1]=start[1]+end[1]*TRACE_END;
	end[2]=start[2]+end[2]*TRACE_END;
	
	TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, FilterAll, 0);
	
	if (TR_DidHit(null))
	{
		// update client's inventory
		g_iRemaining[client]--;
		
		// Find angles for tripmine
		TR_GetEndPosition(end, null);
		TR_GetPlaneNormal(null, normal);
		GetVectorAngles(normal, normal);
		
		// Trace laser beam
		TR_TraceRayFilter(end, normal, CONTENTS_SOLID, RayType_Infinite, FilterAll, 0);
		TR_GetEndPosition(beamend, null);
		
		// Create tripmine model
		int ent = CreateEntityByName("prop_dynamic_override");
		SetEntityModel(ent, g_sModel);
		DispatchKeyValue(ent, "StartDisabled", "false");
		DispatchSpawn(ent);
		TeleportEntity(ent, end, normal, NULL_VECTOR);
		SetEntProp(ent, Prop_Data, "m_usSolidFlags", 152);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 1);
		SetEntityMoveType(ent, MOVETYPE_NONE);
		SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
		SetEntPropEnt(ent, Prop_Data, "m_hLastAttacker", client);
		DispatchKeyValue(ent, "targetname", beammdl);
		DispatchKeyValue(ent, "ExplodeRadius", "256");
		DispatchKeyValue(ent, "ExplodeDamage", "400");
		Format(tmp, sizeof(tmp), "%s,Break,,0,-1", beammdl);
		DispatchKeyValue(ent, "OnHealthChanged", tmp);
		Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", beam);
		DispatchKeyValue(ent, "OnBreak", tmp);
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		AcceptEntityInput(ent, "Enable");
		HookSingleEntityOutput(ent, "OnBreak", mineBreak, true);

		
		// Create laser beam
		int ent2 = CreateEntityByName("env_beam");
		TeleportEntity(ent2, beamend, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(ent2, MDL_LASER);
		DispatchKeyValue(ent2, "texture", MDL_LASER);
		DispatchKeyValue(ent2, "targetname", beam);
		DispatchKeyValue(ent2, "TouchType", "4");
		DispatchKeyValue(ent2, "LightningStart", beam);
		DispatchKeyValue(ent2, "BoltWidth", "4.0");
		DispatchKeyValue(ent2, "life", "0");
		DispatchKeyValue(ent2, "rendercolor", "0 0 0");
		DispatchKeyValue(ent2, "renderamt", "0");
		DispatchKeyValue(ent2, "HDRColorScale", "1.0");
		DispatchKeyValue(ent2, "decalname", "Bigshot");
		DispatchKeyValue(ent2, "StrikeTime", "0");
		DispatchKeyValue(ent2, "TextureScroll", "35");
		Format(tmp, sizeof(tmp), "%s,Break,,0,-1", beammdl);
		DispatchKeyValue(ent2, "OnTouchedByEntity", tmp);	 
		SetEntPropVector(ent2, Prop_Data, "m_vecEndPos", end);
		SetEntPropFloat(ent2, Prop_Data, "m_fWidth", 4.0);
		AcceptEntityInput(ent2, "TurnOff");

		Call_StartForward(g_hPlanted);
		Call_PushCell(client);
		Call_PushCell(ent);
		Call_PushCell(ent2);
		Call_Finish();

		// Create a datapack
		DataPack hData = new DataPack();
		CreateTimer(g_cActTime.FloatValue, TurnBeamOn, hData);
		hData.WriteCell(client);
		hData.WriteCell(ent);
		hData.WriteCell(ent2);
		hData.WriteFloat(end[0]);
		hData.WriteFloat(end[1]);
		hData.WriteFloat(end[2]);
		
		// Play sound
		EmitSoundToAllAny(SND_MINEPUT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);
		
		// Update remaining tripmine count
		PrintHintText(client, "Tripmines remaining: %d", g_iRemaining[client]);
	}
	else
	{
		PrintHintText(client, "Invalid location for Tripmine");
	}
}

public Action TurnBeamOn(Handle timer, DataPack hData)
{
	char color[26];

	hData.Reset();
	int client = hData.ReadCell();
	int ent = hData.ReadCell();
	int ent2 = hData.ReadCell();

	if (IsValidEntity(ent))
	{
		// To Do: Game-based team checks and handling.
		// To Do: Replace teams check with ttt roles
		int team = GetClientTeam(client);
		if(team == CS_TEAM_T)
		{
			color = COLOR_T;
		}
		else if(team == CS_TEAM_CT)
		{
			color = COLOR_CT;
		}
		else
		{
			color = COLOR_DEF;
		}

		DispatchKeyValue(ent2, "rendercolor", color);
		AcceptEntityInput(ent2, "TurnOn");

		float end[3];
		end[0] = hData.ReadFloat();
		end[1] = hData.ReadFloat();
		end[2] = hData.ReadFloat();

		EmitSoundToAllAny(SND_MINEACT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);

		Call_StartForward(g_hReady);
		Call_PushCell(client);
		Call_PushCell(ent);
		Call_PushCell(ent2);
		Call_Finish();
	}

	delete hData;
}

public void mineBreak(const char[] output, int caller, int activator, float delay)
{
	UnhookSingleEntityOutput(caller, "OnBreak", mineBreak);
	AcceptEntityInput(caller,"kill");
}

public bool FilterAll(int entity, int contentsMask)
{
	return false;
}

public int Native_GetClientMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_iRemaining[client];
}

public int Native_AddClientMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	g_iRemaining[client] += amount;

	return g_iRemaining[client];
}

public int Native_SetClientMines(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	g_iRemaining[client] = amount;

	return g_iRemaining[client];
}

