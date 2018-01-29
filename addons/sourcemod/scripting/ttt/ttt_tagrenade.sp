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

#define SHORT_NAME_T "tagrenade_t"
#define SHORT_NAME_D "tagrenade_d"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - TA-Grenade"

ConVar g_cDebug = null;
ConVar g_cTPrice = null;
ConVar g_cTCount = null;
ConVar g_cTPrio = null;
ConVar g_cTagrenadeRange = null;
ConVar g_cTagrenadeTime = null;
ConVar g_cLongName = null;
ConVar g_cShowPlayersBehindWalls = null;
ConVar g_cDiscount = null;
ConVar g_cDPrice = null;
ConVar g_cDCount = null;
ConVar g_cDPrio = null;
ConVar g_cDTagrenadeRange = null;
ConVar g_cCountPlayersBehindWalls = null;
ConVar g_cDDiscount = null;
ConVar g_cCountInnocents = null;
ConVar g_cCountTraitors = null;
ConVar g_cCountDetectives = null;
ConVar g_cRequiredPlayers = null;

bool g_bCPS = false;
bool g_bGlow = false;

int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };

bool g_bPlayerIsTagged[MAXPLAYERS + 1] = { false, ... };
bool g_bSeePlayers[MAXPLAYERS + 1] =  { false, ... };
bool g_bHasGrenade[MAXPLAYERS + 1] =  { false, ... };

float g_fTaggingEndTime[MAXPLAYERS + 1] = { 0.0, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

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

	TTT_StartConfig("tagrenade");
	CreateConVar("ttt2_tagrenade_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("tagrenade_name", "TA-Grenade", "The name of the TA-Grenade in the Shop");
	g_cTPrice = AutoExecConfig_CreateConVar("tagrenade_traitor_price", "9000", "The amount of credits for tagrenade costs as traitor. 0 to disable.");
	g_cDPrice = AutoExecConfig_CreateConVar("tagrenade_detective_price", "9000", "The amount of credits for tagrenade costs as detective. 0 to disable.");
	g_cTCount = AutoExecConfig_CreateConVar("tagrenade_traitor_count", "1", "The amount of usages for tagrenade per round as traitor. 0 to disable.");
	g_cDCount = AutoExecConfig_CreateConVar("tagrenade_detective_count", "1", "The amount of usages for tagrenade per round as detective. 0 to disable.");
	g_cTPrio = AutoExecConfig_CreateConVar("tagrenade_traitor_sort_prio", "0", "The sorting priority of the tagrenade (Traitor) in the shop menu.");
	g_cDPrio = AutoExecConfig_CreateConVar("tagrenade_detective_sort_prio", "0", "The sorting priority of the tagrenade (Detective) in the shop menu.");
	g_cTagrenadeRange = AutoExecConfig_CreateConVar("tagrenade_distance", "1000.0", "Sets the proximity in which the tactical grenade will tag an opponent.");
	g_cDTagrenadeRange = AutoExecConfig_CreateConVar("tagrenade_distance_detective", "1000.0", "Sets the proximity in which the tactical grenade will count the players.");
	g_cTagrenadeTime = AutoExecConfig_CreateConVar("tagrenade_time", "3.5", "How long a player is tagged for in seconds.");
	g_cShowPlayersBehindWalls = AutoExecConfig_CreateConVar("tagrenade_players_behind_walls", "1", "Tag players behind a wall?", _, true, 0.0, true, 1.0);
	g_cCountPlayersBehindWalls = AutoExecConfig_CreateConVar("tagrenade_players_behind_walls_detective", "1", "Count players behind a wall?", _, true, 0.0, true, 1.0);
	g_cDiscount = AutoExecConfig_CreateConVar("tagrenade_discount", "0", "Should traitors tagrenade discountable?", _, true, 0.0, true, 1.0);
	g_cDDiscount = AutoExecConfig_CreateConVar("tagrenade_discount_detective", "0", "Should detectives tagrenade discountable?", _, true, 0.0, true, 1.0);
	g_cCountInnocents = AutoExecConfig_CreateConVar("tagrenade_detective_count_innocents", "1", "Count innocents for detectives tagrenade?", _, true, 0.0, true, 1.0);
	g_cCountTraitors = AutoExecConfig_CreateConVar("tagrenade_detective_count_traitors", "1", "Count traitors for detectives tagrenade?", _, true, 0.0, true, 1.0);
	g_cCountDetectives = AutoExecConfig_CreateConVar("tagrenade_detective_count_detectives", "1", "Count detectives for detectives tagrenade?", _, true, 0.0, true, 1.0);
	g_cRequiredPlayers = AutoExecConfig_CreateConVar("tagrenade_detective_required_players", "4", "How much (valid incl. count convars) players must be in the proximity?");
	TTT_EndConfig();

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
	g_cDebug = FindConVar("ttt_debug_mode");
	g_cPluginTag = FindConVar("ttt_plugin_tag");
	g_cPluginTag.AddChangeHook(OnConVarChanged);
	g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	ConVar UseTAGrenade = FindConVar("cd_usetagrenade");
	
	if (UseTAGrenade != null)
	{
		UseTAGrenade.SetBool(true);
	}
	
	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	char sBuffer[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sBuffer, sizeof(sBuffer));
	
	if (g_bCPS)
	{
		TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cDiscount.BoolValue);
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
	
	TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDDiscount.BoolValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cPluginTag)
	{
		g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
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
		if (StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
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
			else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
			{
				char sPluginTag[128];
				char sBuffer[MAX_ITEM_LENGTH];
				ConVar hTag = FindConVar("ttt_plugin_tag");
				
				hTag.GetString(sPluginTag, sizeof(sPluginTag));
				g_cLongName.GetString(sBuffer, sizeof(sBuffer));
				
				CPrintToChat(client, "%s %T", sPluginTag, "Bought All", client, sBuffer, g_cDCount.IntValue);
				return Plugin_Stop;
			}

			GivePlayerItem(client, "weapon_tagrenade");
			g_bHasGrenade[client] = true;

			if (count)
			{
				if (role == TTT_TEAM_TRAITOR)
				{
					g_iTPCount[client]++;
				}
				else if (role == TTT_TEAM_DETECTIVE)
				{
					g_iDPCount[client]++;
				}
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
	
	int client = GetClientOfUserId(userid);
	
	if (TTT_IsClientValid(client))
	{
		if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
		{
			CreateTimer(g_cTagrenadeTime.FloatValue, Timer_ResetTags, userid);
		}
	}
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
	
	int role = TTT_GetClientRole(client);

	int entity = ReadPackCell(pack);

	float position[3];
	float targetposition[3];
	float distance;

	position[0] = ReadPackFloat(pack);
	position[1] = ReadPackFloat(pack);
	position[2] = ReadPackFloat(pack);
	delete pack;

	if (role == TTT_TEAM_TRAITOR)
	{
		g_bSeePlayers[client] = true;
	}

	int iInno = 0;
	int iTraitor = 0;
	int iDete = 0;

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
		
		if (!g_cDebug.BoolValue && IsFakeClient(target))
		{
			continue;
		}

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

		if (role == TTT_TEAM_TRAITOR && distance > g_cTagrenadeRange.FloatValue)
		{
			continue;
		}
		else if (role == TTT_TEAM_DETECTIVE && distance > g_cDTagrenadeRange.FloatValue)
		{
			continue;
		}
		
		if (role == TTT_TEAM_TRAITOR)
		{
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
		else if (role == TTT_TEAM_DETECTIVE)
		{
			if (g_cCountPlayersBehindWalls.BoolValue)
			{
				int tRole = TTT_GetClientRole(target);
				
				if (tRole == TTT_TEAM_INNOCENT)
				{
					iInno++;
				}
				else if (tRole == TTT_TEAM_TRAITOR)
				{
					iTraitor++;
				}
				else if (tRole == TTT_TEAM_DETECTIVE)
				
				{
					iDete++;
				}
			}
		}
	}
	
	int iPlayers = 0;
	
	if (g_cCountInnocents.BoolValue)
	{
		iPlayers += iInno;
	}
	
	if (g_cCountTraitors.BoolValue)
	{
		iPlayers += iTraitor;
	}
	
	if (g_cCountDetectives.BoolValue)
	{
		iPlayers += iDete;
	}
	
	if (iPlayers >= g_cRequiredPlayers.IntValue && role == TTT_TEAM_DETECTIVE)
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade We Found", client);
		
		if (g_cCountInnocents.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Innocents", client, iInno);
		}
		
		if (g_cCountTraitors.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Traitors", client, iTraitor);
		}
		
		if (g_cCountDetectives.BoolValue)
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Detectives", client, iDete);
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

public Action TTT_OnGlowCheck(int client, int target, bool &seeTarget)
{
	if (g_bSeePlayers[client] && g_bHasGrenade[client])
	{
		if (target > 0 && GetGameTime() < g_fTaggingEndTime[target])
		{
			seeTarget = true;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Handled;
}
