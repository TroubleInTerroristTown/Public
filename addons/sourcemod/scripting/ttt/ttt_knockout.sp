#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <ttt_shop>

#undef REQUIRE_PLUGIN
#pragma newdecls optional
#include <basecomm>
#include <sourcecomms>
#pragma newdecls required
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Knockout"
#define SHORT_NAME "knockout"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;

int g_iCollisionGroup = -1;
int g_iFreeze = -1;
int g_iMyWeapons = -1;

int g_iRagdoll[MAXPLAYERS + 1] =  { -1, ... };
int g_iCamera[MAXPLAYERS + 1] =  { -1, ... };

RenderMode g_rmRenderMode[MAXPLAYERS + 1] =  { RENDER_NORMAL, ... };
int g_iCollision[MAXPLAYERS + 1] =  { -1, ... };

bool g_bHasKnockout[MAXPLAYERS + 1] =  { false, ... };
bool g_bKnockout[MAXPLAYERS + 1] =  { false, ... };

bool g_bSourceC = false;
bool g_bBaseC = false;

UserMsg g_uFade = view_as<UserMsg>(-1);

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_IsClientKnockout", Native_IsClientKnockout);
	
	RegPluginLibrary("ttt_knockout");

	return APLRes_Success;
}

public int Native_IsClientKnockout(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	return g_bKnockout[client];
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	g_iCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	if (g_iCollisionGroup == -1)
	{
		SetFailState("m_CollisionGroup not found...");
	}

	g_iFreeze = FindSendPropInfo("CBasePlayer", "m_fFlags");
	if (g_iFreeze == -1)
	{
		SetFailState("m_fFlags not found...");
	}

	g_iMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	if (g_iMyWeapons == -1)
	{
		SetFailState("m_hMyWeapons not found...");
	}

	g_uFade = GetUserMessageId("Fade");
	if (g_uFade == view_as<UserMsg>(-1))
	{
		SetFailState("Failure with UserMessage Fade...");
	}

	LoadTranslations("ttt.phrases");

	StartConfig("knockout");
	CreateConVar("ttt2_knockout_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("knockout_name", "Knockout", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("knockout_price", "9000", "The amount of credits a knockout costs as detective. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("knockout_sort_prio", "0", "The sorting priority of the knockout in the shop menu.");
	EndConfig();

	HookEvent("player_spawn", Event_PlayerSpawn);

	LoopValidClients(i)
	{
		OnClientPutInServer(i);
	}
	
	g_bSourceC = LibraryExists("sourcecomms");
	g_bBaseC = LibraryExists("basecomm");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "sourcecomms"))
	{
		g_bSourceC = true;
	}
	
	if (StrEqual(name, "basecomm"))
	{
		g_bBaseC = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "sourcecomms"))
	{
		g_bSourceC = false;
	}
	
	if (StrEqual(name, "basecomm"))
	{
		g_bBaseC = false;
	}
}

public void OnConfigsExecuted()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnClientDisconnect(int client)
{
	ResetKnockout(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetKnockout(client);
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role != TTT_TEAM_TRAITOR)
			{
				return Plugin_Stop;
			}

			g_bHasKnockout[client] = true;

			for(int offset = 0; offset < 128; offset += 4)
			{
				int weapon = GetEntDataEnt2(client, g_iMyWeapons + offset);

				if (IsValidEntity(weapon))
				{
					char sClass[32];
					GetEntityClassname(weapon, sClass, sizeof(sClass));

					if (StrEqual(sClass, "weapon_taser", false))
					{
						TTT_SafeRemoveWeapon(client, weapon);
					}
				}
			}
			GivePlayerItem(client, "weapon_taser");
		}
	}
	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if(!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}

	if(g_bKnockout[client])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!TTT_IsRoundActive())
	{
		return Plugin_Continue;
	}

	if (TTT_IsClientValid(attacker) && TTT_IsClientValid(victim))
	{
		if (g_bHasKnockout[attacker] && !g_bKnockout[victim])
		{
			char sWeapon[32];
			GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));

			if (StrContains(sWeapon, "taser", false) != -1)
			{
				KnockoutPlayer(victim);
				g_bHasKnockout[attacker] = false;

				return Plugin_Handled;
			}
		}
	}
	
	if(TTT_IsClientValid(victim) && g_bKnockout[victim])
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void KnockoutPlayer(int client)
{
	char sModel[256];
	GetClientModel(client, sModel, sizeof(sModel));

	float pos[3];
	GetClientEyePosition(client, pos);

	int iEntity = CreateEntityByName("prop_ragdoll");
	DispatchKeyValue(iEntity, "model", sModel);
	SetEntProp(iEntity, Prop_Data, "m_nSolidType", 6);
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 5);

	if (DispatchSpawn(iEntity))
	{
		pos[2] -= 16.0;
		TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);
		SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 2);

		g_iRagdoll[client] = iEntity;
		g_bKnockout[client] = true;

		g_rmRenderMode[client] = GetEntityRenderMode(client);
		CreateTimer(0.1, Timer_FixMode, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

		g_iCollision[client] = GetEntProp(client, Prop_Data, "m_CollisionGroup");
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		
		DropWeapons(client);
		SetEntData(client, g_iFreeze, FL_CLIENT|FL_ATCONTROLS, 4, true);
		
		SpawnCamAndAttach(client, iEntity);
		PerformBlind(client, 255);

		CreateTimer(5.0, Timer_Delete, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

		if (g_bSourceC)
		{
			SourceComms_SetClientMute(client, true, 1, false, "Knockout");
		}
		else if (g_bBaseC)
		{
			BaseComm_SetClientMute(client, true);
		}
		else
		{
			LogError("[%s] (KnockoutPlayer) Can't mute client.", PLUGIN_NAME);
		}
	}
	else
	{
		LogError("[%s] (KnockoutPlayer) Can't spawn prop_ragdoll.", PLUGIN_NAME);
	}
}

public Action Timer_FixMode(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client) && g_bKnockout[client])
	{
		SetEntityRenderMode(client, RENDER_NONE);
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

stock void DropWeapons(int client)
{
	for(int offset = 0; offset < 128; offset += 4)
	{
		int weapon = GetEntDataEnt2(client, g_iMyWeapons + offset);

		if (IsValidEntity(weapon))
		{
			char sClass[32];
			GetEntityClassname(weapon, sClass, sizeof(sClass));

			if ((StrContains(sClass, "knife", false) != -1) || (StrContains(sClass, "bayonet", false) != -1))
			{
				TTT_SafeRemoveWeapon(client, weapon);
			}
			else
			{
				CS_DropWeapon(client, weapon, true, true);
			}
		}
	}
}

public Action Timer_Delete(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client))
	{
		int entity = g_iRagdoll[client];
	
		if (entity != -1 && IsValidEntity(entity))
			AcceptEntityInput(entity, "kill");
		
		int entity2 = EntRefToEntIndex(g_iCamera[client]);
		if(entity2 != -1)
			AcceptEntityInput(entity2, "kill");
		
		g_iCamera[client] = -1;
		g_iRagdoll[client] = -1;
		g_bKnockout[client] = false;
		
		if(IsClientInGame(client))
		{
			if (g_bSourceC)
			{
				SourceComms_SetClientMute(client, false);
			}
			else if (g_bBaseC)
			{
				BaseComm_SetClientMute(client, false);
			}
			
			SetEntData(client, g_iFreeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
			SetClientViewEntity(client, client);
			g_iCamera[client] = false;
			PerformBlind(client, 0);
			SetEntProp(client, Prop_Data, "m_CollisionGroup", g_iCollision[client]);
			SetEntityRenderMode(client, g_rmRenderMode[client]);
			GivePlayerItem(client, "weapon_knife");
		}
	}
}

void ResetKnockout(int client)
{
	g_bHasKnockout[client] = false;
}

stock bool SpawnCamAndAttach(int client, int ragdoll)
{
	char sModel[64];
	Format(sModel, sizeof(sModel), "models/blackout.mdl");
	PrecacheModel(sModel, true);

	char sModelName[64];
	Format(sModelName, sizeof(sModelName), "fpd_ragdoll%d", client);
	DispatchKeyValue(ragdoll, "targetname", sModelName);

	int entity = CreateEntityByName("prop_dynamic");
	if (entity == -1)
	{
		return false;
	}

	char sEntityName[64];
	Format(sEntityName, sizeof(sEntityName), "fpd_ragdollCam%d", entity);

	DispatchKeyValue(entity, "targetname", sEntityName);
	DispatchKeyValue(entity, "parentname", sModelName);
	DispatchKeyValue(entity, "model",	  sModel);
	DispatchKeyValue(entity, "solid",	  "0");
	DispatchKeyValue(entity, "rendermode", "10");
	DispatchKeyValue(entity, "disableshadows", "1");

	float angles[3]; GetClientEyeAngles(client, angles);
	char CamTargetAngles[64];
	Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);
	DispatchKeyValue(entity, "angles", CamTargetAngles);

	SetEntityModel(entity, sModel);
	
	DispatchSpawn(entity);
	SetVariantString(sModelName);
	AcceptEntityInput(entity, "SetParent", entity, entity, 0);

	SetVariantString("forward");
	AcceptEntityInput(entity, "SetParentAttachment", entity, entity, 0);

	AcceptEntityInput(entity, "TurnOn");

	SetClientViewEntity(client, entity);
	g_iCamera[client] = EntIndexToEntRef(entity);
	
	return true;
}

void PerformBlind(int client, int amount)
{
	int targets[2];
	targets[0] = client;

	int duration = 1536;
	int holdtime = 1536;
	int flags;
	if (amount == 0)
		flags = (0x0001 | 0x0010);
	else flags = (0x0002 | 0x0008);

	int color[4] = { 0, 0, 0, 0 };
	color[3] = amount;

	Handle message = StartMessageEx(g_uFade, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}

	EndMessage();
}
