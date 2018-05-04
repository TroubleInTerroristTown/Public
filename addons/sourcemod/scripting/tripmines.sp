#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define TRACE_START 24.0
#define TRACE_END 64.0

#define MDL_LASER "sprites/laser.vmt"

#define SND_MINEPUT "npc/roller/blade_cut.wav"
#define SND_MINEACT "npc/roller/mine/rmine_blades_in2.wav"

#define COLOR_T "255 0 0"
#define COLOR_CT "0 0 255"
#define COLOR_DEF "0 255 255"

#define MAX_LINE_LEN 256
#define DEFAULT_MODEL "models/tripmine/tripmine.mdl"

// globals
int gRemaining[MAXPLAYERS+1];		// how many tripmines player has this spawn
int gCount = 1;
char mdlMine[256];

// convars
Handle cvNumMines = null;
Handle cvActTime = null;
Handle cvModel = null;

public Plugin myinfo = {
	name = "Tripmines 2016 Update",
	author = "404, Bara",
	description = "That old L. Duke Tripmines plugin, updated to actually fucking work.",
	version = PLUGIN_VERSION,
	url = "http://www.unfgaming.net"
};


public void OnPluginStart() 
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);

	cvNumMines = CreateConVar("sm_tripmines_allowed", "3");
	cvActTime = CreateConVar("sm_tripmines_activate_time", "2.0");
	cvModel = CreateConVar("sm_tripmines_model", DEFAULT_MODEL);

	// commands
	RegConsoleCmd("sm_tripmine", Command_TripMine);
}

public void OnMapStart()
{
	// set model based on cvar
	GetConVarString(cvModel, mdlMine, sizeof(mdlMine));
	
	// precache models
	PrecacheModel(mdlMine, true);
	PrecacheModel(MDL_LASER, true);
	
	// precache sounds
	PrecacheSound(SND_MINEPUT, true);
	PrecacheSound(SND_MINEACT, true);
}

// When a new client is put in the server we reset their mines count
public void OnClientPutInServer(int client)
{
	if(client && !IsFakeClient(client))
	{
		gRemaining[client] = 0;
	}
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	gRemaining[client] = GetConVarInt(cvNumMines);
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	gRemaining[client] = 0;
	
	return Plugin_Continue;
}

public Action Command_TripMine(int client, int args)
{	
	// make sure client is not spectating
	if (!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	// call SetMine if any remain in client's inventory
	if (gRemaining[client] > 0)
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
	
	Format(beam, sizeof(beam), "tmbeam%d", gCount);
	Format(beammdl, sizeof(beammdl), "tmbeammdl%d", gCount);
	
	gCount++;
	if (gCount > 10000)
	{
		gCount = 1;
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
		gRemaining[client]--;
		
		// Find angles for tripmine
		TR_GetEndPosition(end, null);
		TR_GetPlaneNormal(null, normal);
		GetVectorAngles(normal, normal);
		
		// Trace laser beam
		TR_TraceRayFilter(end, normal, CONTENTS_SOLID, RayType_Infinite, FilterAll, 0);
		TR_GetEndPosition(beamend, null);
		
		// Create tripmine model
		int ent = CreateEntityByName("prop_dynamic_override");
		SetEntityModel(ent, mdlMine);
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

		// Create a datapack
		DataPack hData = new DataPack();
		CreateTimer(GetConVarFloat(cvActTime), TurnBeamOn, hData);
		hData.WriteCell(client);
		hData.WriteCell(ent);
		hData.WriteCell(ent2);
		hData.WriteFloat(end[0]);
		hData.WriteFloat(end[1]);
		hData.WriteFloat(end[2]);
		
		// Play sound
		EmitSoundToAll(SND_MINEPUT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);
		
		// Update remaining tripmine count
		PrintHintText(client, "Tripmines remaining: %d", gRemaining[client]);
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

		EmitSoundToAll(SND_MINEACT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);
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


