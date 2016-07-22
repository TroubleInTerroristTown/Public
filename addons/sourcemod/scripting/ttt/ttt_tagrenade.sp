#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt_shop>
#include <ttt>
#include <config_loader>
#include <CustomPlayerSkins>
#include <multicolors>

#define SHORT_NAME "tag"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - TA-Grenade"

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

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

char g_sConfigFile[PLATFORM_MAX_PATH] = "";
char g_sPluginTag[PLATFORM_MAX_PATH] = "";
char g_sLongName[64];

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
}

public void OnClientDisconnect(int client)
{
	ResetTAG(client);
}

public void TTT_OnUpdate3(int i)
{
	if(IsPlayerAlive(i))
		SetupGlowSkin(i);
	else
		UnhookGlow(i);
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(TTT_IsClientValid(client))
	{
		UnhookGlow(client);
		ResetTAG(client);
	}
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
	LoopValidClients(client)
	{
		UnhookGlow(client);
		ResetTAG(client);
	}
}

public void TTT_OnClientGetRole(int client, int role)
{
	SetupGlowSkin(client);
}

void SetupGlowSkin(int client)
{
	if(!TTT_IsRoundActive())
		return;
	
	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));
	int iSkin = CPS_SetSkin(client, sModel, CPS_RENDER);
	
	if(iSkin == -1)
		return;
		
	if (SDKHookEx(iSkin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
		SetupGlow(client, iSkin);
}

void SetupGlow(int client, int iSkin)
{
	int iOffset;
	
	if (!iOffset && (iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow")) == -1)
		return;
	
	SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(iSkin, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(iSkin, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	
	int iRed = 255;
	int iGreen = 255;
	int iBlue = 255;
	
	if(TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		iRed = g_iColorDetective[0];
		iGreen = g_iColorDetective[1];
		iBlue = g_iColorDetective[2];
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		iRed = g_iColorTraitor[0];
		iGreen = g_iColorTraitor[1];
		iBlue = g_iColorTraitor[2];
	}
	else if(TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		iRed = g_iColorInnocent[0];
		iGreen = g_iColorInnocent[1];
		iBlue = g_iColorInnocent[2];
	}
	
	SetEntData(iSkin, iOffset, iRed, _, true);
	SetEntData(iSkin, iOffset + 1, iGreen, _, true);
	SetEntData(iSkin, iOffset + 2, iBlue, _, true);
	SetEntData(iSkin, iOffset + 3, 255, _, true);
}

public void OnAllPluginsLoaded()
{
	TTT_RegisterCustomItem(SHORT_NAME, g_sLongName, g_iTPrice, TTT_TEAM_TRAITOR, g_iTPrio);
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort)
{
	if(TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if(StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if(role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_iTCount)
			{
				CPrintToChat(client, g_sPluginTag, "Bought All", client, g_sLongName, g_iTCount);
				return Plugin_Stop;
			}
				
			GivePlayerItem(client, "weapon_tagrenade");
			
			g_iTPCount[client]++;
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
	
	if(TTT_IsClientValid(client))
	{
		g_bSeePlayers[client] = false;
	}
}

public Action OnGetTagrenadeTimes(Handle timer, any data)
{
	Handle pack = view_as<Handle>(data);
	ResetPack(pack);
	
	int client = GetClientOfUserId(ReadPackCell(pack));
	if (client == 0)
	{
		CloseHandle(pack);
		return Plugin_Continue;
	}
	
	int entity = ReadPackCell(pack);
	
	float position[3];
	float targetposition[3];
	float distance;
	
	position[0] = ReadPackFloat(pack);
	position[1] = ReadPackFloat(pack);
	position[2] = ReadPackFloat(pack);
	CloseHandle(pack);
	
	g_bSeePlayers[client] = true;
	
	LoopValidClients(target)
	{
		// Ignore bots
		if(IsFakeClient(client))
			continue;
		
		// Ignore death players
		if(!IsPlayerAlive(client))
			continue;
		
		// Don't hit self
		if (client == target)
			continue;
		
		// Ignore players without role
		if (TTT_GetClientRole(client) < TTT_TEAM_INNOCENT)
			continue;
			
		// Remove game tagging (not FFA compatible)
		SetEntPropFloat(target, Prop_Send, "m_flDetectedByEnemySensorTime", 0.0);
		
		// Check distance
		GetClientEyePosition(target, targetposition);
		distance = GetVectorDistance(position, targetposition);
		
		// Not in range
		if (distance > g_fTagrenadeRange)
			continue;
		
		// Visible?
		if(g_bShowPlayersBehindWalls)
		{
			Handle trace = TR_TraceRayFilterEx(position, targetposition, MASK_VISIBLE, RayType_EndPoint, OnTraceForTagrenade, entity);
			if (TR_DidHit(trace) && TR_GetEntityIndex(trace) == target)
				g_fTaggingEndTime[target] = GetGameTime() + g_fTagrenadeTime;
			CloseHandle(trace);
		}
		else
			g_fTaggingEndTime[target] = GetGameTime() + g_fTagrenadeTime;
	}
	return Plugin_Continue;
}

public bool OnTraceForTagrenade(int entity, int contentsMask, any tagrenade)
{
	if (entity == tagrenade)
		return false;
	return true;
}

float GetPlayerTagEndTime(int client)
{
	return g_fTaggingEndTime[client];
}

void ResetTAG(int client)
{
	g_iTPCount[client] = 0;
	g_fTaggingEndTime[client] = 0.0
	g_bPlayerIsTagged[client] = false;
	g_bSeePlayers[client] = false;
}

public Action OnSetTransmit_GlowSkin(int iSkin, int client)
{
	if(!TTT_IsRoundActive())
		return Plugin_Handled;
	
	if(!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(!g_bSeePlayers[client])
		return Plugin_Handled;
	
	LoopValidClients(target)
	{
		if(target < 1)
			continue;
			
		if(IsFakeClient(target))
			continue;
		
		if(!IsPlayerAlive(target))
			continue;
		
		if(!CPS_HasSkin(target))
			continue;
			
		if(EntRefToEntIndex(CPS_GetSkin(target)) != iSkin)
			continue;
			
		if(GetGameTime() < GetPlayerTagEndTime(target))
			return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

void UnhookGlow(int client)
{
	if(client < 1)
		return;
	
	if (HasEntProp(client, Prop_Send, "m_bShouldGlow"))
	{
		char sModel[PLATFORM_MAX_PATH];
		GetClientModel(client, sModel, sizeof(sModel));
		SetEntProp(client, Prop_Send, "m_bShouldGlow", false, true);
		SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
	}
}
