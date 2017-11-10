#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt_shop>
#include <ttt>
#include <ttt_glow>
#include <CustomPlayerSkins>
#include <multicolors>

#define SHORT_NAME "tagrenade"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - TA-Grenade"

ConVar g_cTPrice = null;
ConVar g_cTCount = null;
ConVar g_cTPrio = null;
ConVar g_cTagrenadeRange = null;
ConVar g_cTagrenadeTime = null;
ConVar g_cLongName = null;
ConVar g_cShowPlayersBehindWalls = null;

bool g_bCPS = false;
bool g_bGlow = false;

int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bPlayerIsTagged[MAXPLAYERS + 1] = { false, ... };
bool g_bSeePlayers[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasGrenade[MAXPLAYERS + 1] =  { false, ... };

float g_fTaggingEndTime[MAXPLAYERS + 1] = { 0.0, ... };



public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara, zipcore & Neuro Toxin",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");

	StartConfig("tagrenade");
	CreateConVar("ttt2_tagrenade_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("tag_name", "TA-Grenade", "The name of the TA-Grenade in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("tag_traitor_price", "9000", "The amount of credits for tagrenade costs as traitor. 0 to disable.");
	g_cTCount = AutoExecConfig_CreateConVar("tag_traitor_count", "1", "The amount of usages for tagrenade per round as innocent. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("tag_traitor_sort_prio", "0", "The sorting priority of the tagrenade (Traitor) in the shop menu.");
	g_cTagrenadeRange = AutoExecConfig_CreateConVar("tag_tagrenade_distance", "1000.0", "Sets the proximity in which the tactical grenade will tag an opponent.");
	g_cTagrenadeTime = AutoExecConfig_CreateConVar("tag_tagrenade_time", "3.5", "How long a player is tagged for in seconds.");
	g_cShowPlayersBehindWalls = AutoExecConfig_CreateConVar("tag_players_behind_walls", "1", "Tag players behind a wall?", _, true, 0.0, true, 1.0);
	EndConfig();

	HookEvent("player_spawn", Event_PlayerReset);
	HookEvent("player_death", Event_PlayerReset);
	HookEvent("round_end", Event_RoundReset);
	HookEvent("tagrenade_detonate", OnTagrenadeDetonate);

	g_bCPS = LibraryExists("CustomPlayerSkins");
	g_bGlow = LibraryExists("ttt_glow");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = true;
	}
	
	if (StrEqual(name, "ttt_glow"))
	{
		g_bGlow = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "CustomPlayerSkins"))
	{
		g_bCPS = false;
	}
	
	if (StrEqual(name, "ttt_glow"))
	{
		g_bGlow = false;
	}
}

public void OnConfigsExecuted()
{
	ConVar UseTAGrenade = FindConVar("cd_usetagrenade");
	
	if (UseTAGrenade != null)
	{
		UseTAGrenade.SetBool(true);
	}
	
	if (g_bCPS)
	{
		char sBuffer[MAX_ITEM_LENGTH];
		g_cLongName.GetString(sBuffer, sizeof(sBuffer));
		TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
	}
	else if (!g_bCPS)
	{
		SetFailState("CustomPlayerSkins not loaded!");
	}
	else if (!g_bGlow)
	{
		if (!LibraryExists("ttt_glow"))
		{
			SetFailState("TTT-Glow not loaded!");
		}
		else
		{
			g_bGlow = true;
		}
	}
}

public void OnClientDisconnect(int client)
{
	ResetTAG(client);
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		ResetTAG(client);
	}
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
	LoopValidClients(client)
	{
		ResetTAG(client);
	}
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);

			if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
			{
				char sPluginTag[128];
				char sBuffer[MAX_ITEM_LENGTH];
				ConVar hTag = FindConVar("ttt_plugin_tag");
				
				hTag.GetString(sPluginTag, sizeof(sPluginTag));
				g_cLongName.GetString(sBuffer, sizeof(sBuffer));
				
				CPrintToChat(client, "%s %T", sPluginTag, "Bought All", client, sBuffer, g_cTCount.IntValue);
				return Plugin_Stop;
			}

			GivePlayerItem(client, "weapon_tagrenade");
			g_bHasGrenade[client] = true;

			if (count)
			{
				g_iTPCount[client]++;
			}
		}
	}
	return Plugin_Continue;
}

public void OnTagrenadeDetonate(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	
	Handle pack = CreateDataPack();
	WritePackCell(pack, userid);
	WritePackCell(pack, GetEventInt(event, "entityid"));
	WritePackFloat(pack, GetEventFloat(event, "x"));
	WritePackFloat(pack, GetEventFloat(event, "y"));
	WritePackFloat(pack, GetEventFloat(event, "z"));
	
	CreateTimer(0.0, OnGetTagrenadeTimes, pack);
	CreateTimer(g_cTagrenadeTime.FloatValue, Timer_ResetTags, userid);
}

public Action Timer_ResetTags(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		g_bSeePlayers[client] = false;
		g_bHasGrenade[client] = false;
	}
}

public Action OnGetTagrenadeTimes(Handle timer, any data)
{
	Handle pack = view_as<Handle>(data);
	ResetPack(pack);

	int client = GetClientOfUserId(ReadPackCell(pack));
	if (client == 0)
	{
		delete pack;
		return Plugin_Continue;
	}

	int entity = ReadPackCell(pack);

	float position[3];
	float targetposition[3];
	float distance;

	position[0] = ReadPackFloat(pack);
	position[1] = ReadPackFloat(pack);
	position[2] = ReadPackFloat(pack);
	delete pack;

	g_bSeePlayers[client] = true;

	LoopValidClients(target)
	{
		if (target < 1)
		{
			continue;
		}

		if (client == target)
		{
			continue;
		}
		
		/* if (IsFakeClient(target))
		{
			continue;
		} */

		if (!IsPlayerAlive(target))
		{
			continue;
		}

		if (TTT_GetClientRole(target) < TTT_TEAM_INNOCENT)
		{
			continue;
		}

		SetEntPropFloat(target, Prop_Send, "m_flDetectedByEnemySensorTime", 0.0);
		
		if (!g_bHasGrenade[client])
		{
			continue;
		}

		GetClientEyePosition(target, targetposition);
		distance = GetVectorDistance(position, targetposition);

		if (distance > g_cTagrenadeRange.FloatValue)
		{
			continue;
		}

		if (g_cShowPlayersBehindWalls.BoolValue)
		{
			Handle trace = TR_TraceRayFilterEx(position, targetposition, MASK_VISIBLE, RayType_EndPoint, OnTraceForTagrenade, entity);
			
			if (TR_DidHit(trace) && TR_GetEntityIndex(trace) == target)
			{
				g_fTaggingEndTime[target] = GetGameTime() + g_cTagrenadeTime.FloatValue;
			}
			
			delete trace;
		}
		else
		{
			g_fTaggingEndTime[target] = GetGameTime() + g_cTagrenadeTime.FloatValue;
		}
	}
	return Plugin_Continue;
}

public bool OnTraceForTagrenade(int entity, int contentsMask, any tagrenade)
{
	if (entity == tagrenade)
	{
		return false;
	}
	return true;
}

void ResetTAG(int client)
{
	g_iTPCount[client] = 0;
	g_fTaggingEndTime[client] = 0.0;
	g_bPlayerIsTagged[client] = false;
	g_bSeePlayers[client] = false;
	g_bHasGrenade[client] = false;
}

public Action TTT_OnGlowCheck(int client, int target)
{
	if (g_bSeePlayers[client] && g_bHasGrenade[client])
	{
		if (target > 0 && GetGameTime() < g_fTaggingEndTime[target])
		{
			return Plugin_Continue;
		}
	}
	
	return Plugin_Handled;
}
