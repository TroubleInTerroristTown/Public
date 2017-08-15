#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <CustomPlayerSkins>
#include <multicolors>

#define SHORT_NAME "tagrenade"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - TA-Grenade"

int g_iTPrice = 0;
int g_iTCount = 0;
int g_iTPrio = 0;
int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bPlayerIsTagged[MAXPLAYERS + 1] = { false, ... };

float g_fTaggingEndTime[MAXPLAYERS + 1] = { 0.0, ... };

float g_fTagrenadeRange = 0.0;
float g_fTagrenadeTime = 0.0;

bool g_bShowPlayersBehindWalls = false;
bool g_bSeePlayers[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasGrenade[MAXPLAYERS + 1] =  { false, ... };

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

bool g_bCPS = false;
bool g_bGlow = false;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Bara, zipcore & Neuro Toxin",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("TTT_CheckTAGrenade", Native_CheckTAGrenade);
	
	RegPluginLibrary("ttt_tagrenade");

	return APLRes_Success;
}

public int Native_CheckTAGrenade(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int target = GetNativeCell(2);
	
	if (g_bSeePlayers[client] && g_bHasGrenade[client])
	{
		if (target > 0 && GetGameTime() < g_fTaggingEndTime[target])
		{
			return true;
		}
	}
	
	return false;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	LoadTranslations("ttt.phrases");

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	Config_Done();

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/tagrenade.cfg");
	Config_Setup("TTT-TAGrenade", g_sConfigFile);

	Config_LoadString("tag_name", "TA-Grenade", "The name of the TA-Grenade in the Shop", g_sLongName, sizeof(g_sLongName));
	g_iTPrice = Config_LoadInt("tag_traitor_price", 9000, "The amount of credits for tagrenade costs as traitor. 0 to disable.");
	g_iTCount = Config_LoadInt("tag_traitor_count", 1, "The amount of usages for tagrenade per round as innocent. 0 to disable.");
	g_iTPrio = Config_LoadInt("tag_traitor_sort_prio", 0, "The sorting priority of the tagrenade (Traitor) in the shop menu.");
	g_fTagrenadeRange = Config_LoadFloat("tag_tagrenade_distance", 1000.0, "Sets the proximity in which the tactical grenade will tag an opponent.");
	g_fTagrenadeTime = Config_LoadFloat("tag_tagrenade_time", 3.5, "How long a player is tagged for in seconds.");
	g_bShowPlayersBehindWalls = Config_LoadBool("tag_players_behind_walls", true, "Tag players behind a wall?");

	Config_Done();

	HookEvent("player_spawn", Event_PlayerReset);
	HookEvent("player_death", Event_PlayerReset);
	HookEvent("round_end", Event_RoundReset);
	HookEvent("tagrenade_detonate", OnTagrenadeDetonate);

	g_bCPS = LibraryExists("CustomPlayerSkins");
	g_bGlow = LibraryExists("ttt_glow");
}

public void OnConfigsExecuted()
{
	ConVar UseTAGrenade = FindConVar("cd_usetagrenade");
	
	if (UseTAGrenade != null)
	{
		UseTAGrenade.SetBool(true);
	}
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

public void OnAllPluginsLoaded()
{
	if (g_bCPS)
	{
		TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iTPrice, TTT_TEAM_TRAITOR, g_iTPrio);
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

			if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_iTCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iTCount);
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
	CreateTimer(g_fTagrenadeTime, Timer_ResetTags, userid);
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

		if (distance > g_fTagrenadeRange)
		{
			continue;
		}

		if (g_bShowPlayersBehindWalls)
		{
			Handle trace = TR_TraceRayFilterEx(position, targetposition, MASK_VISIBLE, RayType_EndPoint, OnTraceForTagrenade, entity);
			
			if (TR_DidHit(trace) && TR_GetEntityIndex(trace) == target)
			{
				g_fTaggingEndTime[target] = GetGameTime() + g_fTagrenadeTime;
			}
			
			delete trace;
		}
		else
		{
			g_fTaggingEndTime[target] = GetGameTime() + g_fTagrenadeTime;
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
