#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <multicolors>
#include <emitsoundany>
#include <clientprefs>
#include <convar_append>

#undef REQUIRE_PLUGIN
#tryinclude <sourcebans>

#pragma newdecls required

#define PLUGIN_NAME "TTT - Trouble in Terrorist Town"
#define PLUGIN_AUTHOR "Bara/Darkness/Zipcore"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_VERSION "2.0.2"
#define PLUGIN_URL "git.tf/Bara/TTT"

#define PF " {purple}[{green}T{darkred}T{blue}T{purple}]{default} %T"

#define TRAITORS_AMOUNT 0.25
#define DETECTIVES_AMOUNT 0.13

#define LoopValidClients(%1) for(int %1=1;%1<=MaxClients;++%1)\
if(IsClientValid(%1))

#define U 0
#define I 1
#define T 2
#define D 3
#define MONEYHIDE 16000


// Add karma points and credits to eCvars (for 2.0.2 release)
enum eCvars
{
	ConVar:c_shopKEVLAR,
	ConVar:c_shop1KNIFE,
	ConVar:c_shopDNA,
	ConVar:c_shopID,
	ConVar:c_shopFAKEID,
	ConVar:c_shopT,
	ConVar:c_shopD,
	ConVar:c_shopTASER,
	ConVar:c_shopUSP,
	ConVar:c_shopM4A1,
	ConVar:c_shopJIHADBOMB,
	ConVar:c_shopC4,
	ConVar:c_shopHEALTH,
	ConVar:c_requiredPlayersD,
	ConVar:c_requiredPlayers,
	ConVar:c_startKarma,
	ConVar:c_karmaBan,
	ConVar:c_karmaBanLength,
	ConVar:c_maxKarma,
	ConVar:c_spawnHPT,
	ConVar:c_spawnHPD,
	ConVar:c_spawnHPI,
	ConVar:c_karmaII,
	ConVar:c_karmaIT,
	ConVar:c_karmaID,
	ConVar:c_karmaTI,
	ConVar:c_karmaTT,
	ConVar:c_karmaTD,
	ConVar:c_karmaDI,
	ConVar:c_karmaDT,
	ConVar:c_karmaDD,
	ConVar:c_creditsII,
	ConVar:c_creditsIT,
	ConVar:c_creditsID,
	ConVar:c_creditsTI,
	ConVar:c_creditsTT,
	ConVar:c_creditsTD,
	ConVar:c_creditsDI,
	ConVar:c_creditsDT,
	ConVar:c_creditsDD,
	ConVar:c_creditsFoundBody,
	ConVar:c_creditsTaserHurtTraitor,
	ConVar:c_traitorloseAliveNonTraitors,
	ConVar:c_traitorloseDeadNonTraitors,
	ConVar:c_traitorwinAliveTraitors,
	ConVar:c_traitorwinDeadTraitors
};

int g_iCvar[eCvars];

int g_iCredits[MAXPLAYERS+1] = {800, ...};

bool g_bHasC4[MAXPLAYERS+1] = {false, ...};

int g_iRDMAttacker[MAXPLAYERS+1] = {-1, ...};
Handle g_hRDMTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
bool g_bImmuneRDMManager[MAXPLAYERS+1] = {false, ...};
bool g_bHoldingProp[MAXPLAYERS+1] = {false, ...};
bool g_bHoldingSilencedWep[MAXPLAYERS+1] = {false, ...};

char g_sDetectiveNames[][] = { "detective", "detectlve" };

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

int g_iAccount;

//C4 MOD
Handle g_hExplosionTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
bool g_bHasActiveBomb[MAXPLAYERS+1] = {false, ...};
int g_iWire[MAXPLAYERS+1] = {-1, ...};
int g_iDefusePlayerIndex[MAXPLAYERS+1] = {-1, ...};
//

//health station
int g_iHealthStationCharges[MAXPLAYERS+1] = {0, ...};
int g_iHealthStationHealth[MAXPLAYERS+1] = {0, ...};
bool g_bHasActiveHealthStation[MAXPLAYERS+1] = {false, ...};
bool g_bOnHealingCoolDown[MAXPLAYERS+1] = {false, ...};
Handle g_hRemoveCoolDownTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
//

bool g_b1Knife[MAXPLAYERS+1] = {false, ...};
bool g_bScan[MAXPLAYERS+1] = {false, ...};
bool g_bJihadBomb[MAXPLAYERS+1] = {false, ...};
bool g_bID[MAXPLAYERS+1] = {false, ...};
Handle g_hJihadBomb[MAXPLAYERS+1] = {null, ...};
int g_iRole[MAXPLAYERS+1] = {0, ...};

int g_iInnoKills[MAXPLAYERS + 1];

Handle g_hGraceTime = null;

Handle g_hStartTimer = null;
Handle g_hPlayerArray = null;

int g_iIcon[MAXPLAYERS+1] = {0, ...};

bool g_bRoundStarted = false;

Handle g_hRoundTimer = null;

bool g_bInactive = false;

int g_iCollisionGroup = -1;

bool g_bKarma[MAXPLAYERS + 1] =  { false, ... };
int g_iKarma[MAXPLAYERS + 1] =  { 0, ... };
Handle g_hKarmaCookie = INVALID_HANDLE;

Handle g_hRagdollArray = null;

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

bool g_bFound[MAXPLAYERS + 1] = {false, ...};
bool g_bDetonate[MAXPLAYERS + 1] = {false, ...};

int g_iAlive = -1;

enum Ragdolls
{
	ent,
	victim,
	attacker,
	String:victimName[32],
	String:attackerName[32],
	bool:scanned,
	Float:gameTime,
	String:weaponused[32],
	bool:found
}

bool g_bReceivingLogs[MAXPLAYERS+1];

Handle g_hLogsArray;

public void OnPluginStart()
{
	LoadTranslations("ttt.phrases");
	LoadTranslations("common.phrases");
	
	g_hKarmaCookie = RegClientCookie("ttt_karma", "Stores Karma.", CookieAccess_Private);
	
	// Lateload support
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (!AreClientCookiesCached(i))
		{
			AddStartKarma(i);
			continue;
		}
		
		OnClientCookiesCached(i);
		OnClientPutInServer(i);
	}
	
	g_hRagdollArray = CreateArray(102);
	g_hPlayerArray = CreateArray();
	g_hLogsArray = CreateArray(512);
	
	g_iCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	g_iAccount = FindSendPropOffs("CCSPlayer", "m_iAccount");
	

	CreateTimer(0.1, Timer_Adjust, _, TIMER_REPEAT);
	CreateTimer(1.0, healthStationDistanceCheck, INVALID_HANDLE, TIMER_REPEAT);
	CreateTimer(5.0, Timer_5, _, TIMER_REPEAT);
	
	RegAdminCmd("sm_role", Command_Role, ADMFLAG_ROOT);
	RegAdminCmd("sm_karmareset", Command_KarmaReset, ADMFLAG_ROOT);
	
	RegConsoleCmd("sm_status", Command_Status);
	RegConsoleCmd("sm_karma", Showkarma);
	RegConsoleCmd("sm_money", ShowMoney);
	RegConsoleCmd("sm_credits", ShowMoney);
	RegConsoleCmd("sm_boom", Command_Detonate); 
	RegConsoleCmd("sm_jihad_detonate", Command_Detonate); 
	RegConsoleCmd("sm_logs", Logs);
	RegConsoleCmd("sm_log", Logs);
	RegConsoleCmd("say_team", SayTeam);
	RegConsoleCmd("sm_menu", ShowMenu);
	RegConsoleCmd("sm_shop", ShowMenu);
	RegConsoleCmd("sm_id", ShowID);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStartPre, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
	HookEvent("player_changename", Event_ChangeName);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	g_hGraceTime = FindConVar("mp_join_grace_time");
	
	AddCommandListener(Command_LAW, "+lookatweapon");
	
/* 	AddCommandListener(Command_InterceptSuicide, "kill");
	AddCommandListener(Command_InterceptSuicide, "explode");
	AddCommandListener(Command_InterceptSuicide, "spectate");
	AddCommandListener(Command_InterceptSuicide, "jointeam");
	AddCommandListener(Command_InterceptSuicide, "joinclass"); */

	g_iCvar[c_shopKEVLAR] = CreateConVar("ttt_shop_kevlar", "2500");
	g_iCvar[c_shop1KNIFE] = CreateConVar("ttt_shop_1knife", "5000");
	g_iCvar[c_shopDNA] = CreateConVar("ttt_shop_dna_scanner", "5000");
	g_iCvar[c_shopID] = CreateConVar("ttt_shop_id_card", "500");
	g_iCvar[c_shopFAKEID] = CreateConVar("ttt_shop_fake_id_card", "5000");
	g_iCvar[c_shopT] = CreateConVar("ttt_shop_t", "100000");
	g_iCvar[c_shopD] = CreateConVar("ttt_shop_d", "5000");
	g_iCvar[c_shopTASER] = CreateConVar("ttt_shop_taser", "3000");
	g_iCvar[c_shopUSP] = CreateConVar("ttt_shop_usp", "3000");
	g_iCvar[c_shopM4A1] = CreateConVar("ttt_shop_m4a1", "6000");
	g_iCvar[c_shopJIHADBOMB] = CreateConVar("ttt_shop_jihad_bomb", "6000");
	g_iCvar[c_shopC4] = CreateConVar("ttt_shop_c4", "10000");
	g_iCvar[c_shopHEALTH] = CreateConVar("ttt_shop_health_station", "3000");
	
	g_iCvar[c_requiredPlayersD] = CreateConVar("ttt_required_players_detective", "6");
	g_iCvar[c_requiredPlayers] = CreateConVar("ttt_required_player", "3");
	
	g_iCvar[c_startKarma] = CreateConVar("ttt_start_karma", "100");
	g_iCvar[c_karmaBan] = CreateConVar("ttt_with_karma_ban", "50"); // 0 = disabled
	g_iCvar[c_karmaBanLength] = CreateConVar("ttt_with_karma_ban_length", "10080"); // one week = 10080 minutes
	g_iCvar[c_maxKarma] = CreateConVar("ttt_max_karma", "200");
	
	g_iCvar[c_spawnHPT] = CreateConVar("ttt_spawn_t", "100");
	g_iCvar[c_spawnHPD] = CreateConVar("ttt_spawn_d", "100");
	g_iCvar[c_spawnHPI] = CreateConVar("ttt_spawn_i", "100");
	
	g_iCvar[c_karmaII] = CreateConVar("ttt_karma_killer_innocent_victim_innocent_subtract", "5");
	g_iCvar[c_karmaIT] = CreateConVar("ttt_karma_killer_innocent_victim_traitor_add", "5");
	g_iCvar[c_karmaID] = CreateConVar("ttt_karma_killer_innocent_victim_detective_subtract", "7");
	g_iCvar[c_karmaTI] = CreateConVar("ttt_karma_killer_traitor_victim_innocent_add", "2");
	g_iCvar[c_karmaTT] = CreateConVar("ttt_karma_killer_traitor_victim_traitor_subtract", "5");
	g_iCvar[c_karmaTD] = CreateConVar("ttt_karma_killer_traitor_victim_detective_add", "3");
	g_iCvar[c_karmaDD] = CreateConVar("ttt_karma_killer_detective_victim_innocent_subtract", "3");
	g_iCvar[c_karmaDD] = CreateConVar("ttt_karma_killer_detective_victim_traitor_add", "7");
	g_iCvar[c_karmaDD] = CreateConVar("ttt_karma_killer_detective_victim_detective_subtract", "7");
	
	g_iCvar[c_creditsII] = CreateConVar("ttt_credits_killer_innocent_victim_innocent_subtract", "1500");
	g_iCvar[c_creditsIT] = CreateConVar("ttt_credits_killer_innocent_victim_traitor_add", "3000");
	g_iCvar[c_creditsID] = CreateConVar("ttt_credits_killer_innocent_victim_detective_subtract", "4200");
	g_iCvar[c_creditsTI] = CreateConVar("ttt_credits_killer_traitor_victim_innocent_add", "600");
	g_iCvar[c_creditsTT] = CreateConVar("ttt_credits_killer_traitor_victim_traitor_subtract", "3000");
	g_iCvar[c_creditsTD] = CreateConVar("ttt_credits_killer_traitor_victim_detective_add", "4200");
	g_iCvar[c_creditsDD] = CreateConVar("ttt_credits_killer_detective_victim_innocent_subtract", "300");
	g_iCvar[c_creditsDD] = CreateConVar("ttt_credits_killer_detective_victim_traitor_add", "2100");
	g_iCvar[c_creditsDD] = CreateConVar("ttt_credits_killer_detective_victim_detective_subtract", "300");
	
	g_iCvar[c_traitorloseAliveNonTraitors] = CreateConVar("ttt_credits_roundend_traitorlose_alive_nontraitors", "4800");
	g_iCvar[c_traitorloseDeadNonTraitors] = CreateConVar("ttt_credits_roundend_traitorlose_dead_nontraitors", "1200");
	g_iCvar[c_traitorwinAliveTraitors] = CreateConVar("ttt_credits_roundend_traitorwin_alive_traitors", "4800");
	g_iCvar[c_traitorwinDeadTraitors] = CreateConVar("ttt_credits_roundend_traitorwin_dead_traitors", "1200");
	
	g_iCvar[c_creditsFoundBody] = CreateConVar("ttt_credits_found_body_add", "1200");
	g_iCvar[c_creditsTaserHurtTraitor] = CreateConVar("ttt_hurt_traitor_with_taser", "2000");

	AutoExecConfigAppend("ttt", "sourcemod");
}

public Action Logs(int client, int args)
{
	if(!IsPlayerAlive(client) || !g_bRoundStarted)
		ShowLogs(client);
	else
		CPrintToChat(client, PF, "you cant see logs", client);
	return Plugin_Handled;
}

stock void ShowLogs(int client)
{
	int sizearray = GetArraySize(g_hLogsArray);
	if(sizearray == 0)
	{
		CPrintToChat(client, PF, "Aun no items", client);
		return;
	}
	if(g_bReceivingLogs[client]) return;
	g_bReceivingLogs[client] = true;
	CPrintToChat(client, PF, "Receiving logs", client);
	PrintToConsole(client, "--------------------------------------");
	PrintToConsole(client, "-------------TTT LOGS---------------");
	char item[512];
	int index = 5;
	bool end = false;
	if(index >= sizearray)
	{
		end = true;
		index = (sizearray -1);
	}
		
	for(int i = 0; i <= index; i++)
	{
		GetArrayString(g_hLogsArray, i, item, sizeof(item));
		PrintToConsole(client, item);
	}
	
	if(end)
	{
		CPrintToChat(client, PF, "See your console", client);
		g_bReceivingLogs[client] = false;
		PrintToConsole(client, "--------------------------------------");
		PrintToConsole(client, "--------------------------------------");
		return;
	}
	Handle pack = CreateDataPack();
	RequestFrame(OnCreate, pack);
	WritePackCell(pack, client);
	WritePackCell(pack, index);
}

public void OnCreate(any pack)
{
	//unpack into
	int client;
	int index;
	
	
	ResetPack(pack);
	client = ReadPackCell(pack);
	index = ReadPackCell(pack);
	
	if (IsClientInGame(client))
	{
		int sizearray = GetArraySize(g_hLogsArray);
		int old = (index + 1);
		index += 5;
		bool end = false;
		if(index >= sizearray)
		{
			end = true;
			index = (sizearray -1);
		}
		char item[512];
		
		for(int i = old; i <= index; i++)
		{
			GetArrayString(g_hLogsArray, i, item, sizeof(item));
			PrintToConsole(client, item);
		}
		if(end)
		{
			CPrintToChat(client, PF, "See your console", client);
			g_bReceivingLogs[client] = false;
			PrintToConsole(client, "--------------------------------------");
			PrintToConsole(client, "--------------------------------------");
			return;
		}
		Handle pack2;
		RequestFrame(OnCreate, pack2);
		WritePackCell(pack2, client);
		WritePackCell(pack2, index);
	}
}

/* public Action Command_InterceptSuicide(client, const char[] command, args)
{
	if(IsPlayerAlive(client))
	{
		CPrintToChat(client, " {default}[{green}T{RED}T{blue}T{default}]{PURPLE} Suicide blocked");
		return Plugin_Handled;
	}
	return Plugin_Continue;
} */

public void OnMapStart()
{
	g_iBeamSprite = PrecacheModel("materials/sprites/bomb_planted_ring.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo.vtf");
	
	PrecacheModel("props/cs_office/microwave.mdl", true);
	PrecacheModel("weapons/w_c4_planted.mdl", true);
	PrecacheModel("weapons/w_c4_planted.mdl", true);
	
	PrecacheSound("buttons/blip2.wav", true); 
	PrecacheSound("buttons/button11.wav", true);
	PrecacheSound("buttons/button18.wav", true);
	
	PrecacheSoundAny("training/firewerks_burst_02.wav", true);
	PrecacheSoundAny("weapons/c4/c4_beep1.wav", true);
	PrecacheSoundAny("weapons/c4/c4_disarm.wav", true);
	PrecacheSoundAny("ttt/jihad/explosion.mp3", true);
	PrecacheSoundAny("ttt/jihad/jihad.mp3", true);
	PrecacheSoundAny("resource/warning.wav", true);
	PrecacheSoundAny("training/firewerks_burst_02.wav", true);
	PrecacheSoundAny("weapons/c4/c4_beep1.wav", true);
	PrecacheSoundAny("weapons/c4/c4_disarm.wav", true);

	AddFileToDownloadsTable("sound/ttt/jihad/explosion.mp3"); 
	AddFileToDownloadsTable("sound/ttt/jihad/jihad.mp3");
	
	ClearArray(g_hLogsArray);

	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_detective_icon.vtf");
	PrecacheModel("materials/sprites/sg_detective_icon.vmt");
	
	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vmt");
	AddFileToDownloadsTable("materials/sprites/sg_traitor_icon.vtf");
	PrecacheModel("materials/sprites/sg_traitor_icon.vmt");
	
	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/innocents_win.vtf");
	PrecacheDecal("overlays/ttt/innocents_win", true);
	
	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/traitors_win.vtf");
	PrecacheDecal("overlays/ttt/traitors_win", true);
	
	AddFileToDownloadsTable("materials/darkness/ttt/overlayDetective.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayDetective.vtf");
	PrecacheDecal("darkness/ttt/overlayDetective", true);
	
	AddFileToDownloadsTable("materials/darkness/ttt/overlayTraitor.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayTraitor.vtf");
	PrecacheDecal("darkness/ttt/overlayTraitor", true);
	
	AddFileToDownloadsTable("materials/darkness/ttt/overlayInnocent.vmt");
	AddFileToDownloadsTable("materials/darkness/ttt/overlayInnocent.vtf");
	PrecacheDecal("darkness/ttt/overlayInnocent", true);
	
/* 	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vmt");
	AddFileToDownloadsTable("materials/overlays/ttt/detectives_win.vtf");
	PrecacheDecal("overlays/ttt/detectives_win", true); */
	
	g_iAlive = FindSendPropOffs("CCSPlayerResource", "m_bAlive");
	if (g_iAlive == -1)
		SetFailState("CCSPlayerResource.m_bAlive offset is invalid");
    
	int iPlayerManagerPost = FindEntityByClassname(0, "cs_player_manager"); 
	SDKHook(iPlayerManagerPost, SDKHook_ThinkPost, OnThinkPost); // TODO: Better way?
	
	resetPlayers();
}

public void OnThinkPost(int entity) 
{
    int isAlive[65];
	
    GetEntDataArray(entity, g_iAlive, isAlive, 65);
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
		{
			if(IsPlayerAlive(i) || !g_bFound[i])
				isAlive[i] = true;
			else
				isAlive[i] = false;
		}
    }
    SetEntDataArray(entity, g_iAlive, isAlive, 65);
}

public Action Showkarma(int client, int args)
{
	CPrintToChat(client, PF, "Your karma is", client, g_iKarma[client]);
	
	return Plugin_Handled;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	ClearArray(g_hRagdollArray);
	
	g_bInactive = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iRole[i] = U;
		g_bFound[i] = true;
		
		if(IsClientInGame(i)) 
		{
			CS_SetClientClanTag(i, "");
			g_iInnoKills[i] = 0;
			g_bHasC4[i] = false;
			g_bImmuneRDMManager[i] = false;
		}
	}

	if(g_hStartTimer != INVALID_HANDLE)
		KillTimer(g_hStartTimer);
		
	g_hStartTimer = CreateTimer(GetConVarFloat(g_hGraceTime) + 5.0, Timer_Selection);
	
	g_bRoundStarted = false;
	
	if (g_hRoundTimer != INVALID_HANDLE) 
		CloseHandle(g_hRoundTimer);
		
	g_hRoundTimer = CreateTimer(GetConVarFloat(FindConVar("mp_roundtime")) * 60.0, Timer_OnRoundEnd);
	
	ShowOverlayToAll("");
	resetPlayers();
	healthStation_cleanUp();
}

public Action Event_RoundEndPre(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <=MaxClients; ++i)
	{
		g_bFound[i] = true;
		if(IsClientInGame(i))
		{
			ShowLogs(i);
			
			TeamTag(i);
			g_iInnoKills[i] = 0;
			g_bImmuneRDMManager[i] = false;
		}
	}
		
		
	if (g_hRoundTimer != INVALID_HANDLE) {
		CloseHandle(g_hRoundTimer);
		g_hRoundTimer = INVALID_HANDLE;
	}
	resetPlayers();
	healthStation_cleanUp();
}

public Action Timer_Selection(Handle hTimer)
{
	g_hStartTimer = INVALID_HANDLE;
	
	LoopValidClients(i)
		CPrintToChat(i, PF, "TEAMS HAS BEEN SELECTED", i);
	
	ClearArray(g_hPlayerArray);
	
	int iCount = 0;
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			iCount++;
			PushArrayCell(g_hPlayerArray, i);
		}
		
	if(iCount < g_iCvar[c_requiredPlayers].IntValue) 
	{
		g_bInactive = true;
		LoopValidClients(i)
			CPrintToChat(i, PF, "MIN PLAYERS REQUIRED FOR PLAY", i, g_iCvar[c_requiredPlayers].IntValue);
		return;
	}
	int detectives = RoundToNearest(iCount * DETECTIVES_AMOUNT);
	int Traitores = RoundToNearest(iCount * TRAITORS_AMOUNT);
	
	if(detectives == 0)
		detectives = 1;
	if(Traitores == 0)
		Traitores = 1;
	
	if(iCount < g_iCvar[c_requiredPlayersD].IntValue)
		detectives = 0;
	
	int index;
	int player;
	while((index = GetRandomArray()) != -1)
	{
		player = GetArrayCell(g_hPlayerArray, index);
		
		if(detectives > 0)
		{
			g_iRole[player] = D;
			detectives--;
		}
		else if(Traitores > 0)
		{
			g_iRole[player] = T;
			Traitores--;
		}
		else
			g_iRole[player] = I;
		
		
/* 		int knife = GetPlayerWeaponSlot(player, 2);
		if (knife != -1)
		{
			RemovePlayerItem(player, knife);
			AcceptEntityInput(player, "Kill");
		} */
		while (GetPlayerWeaponSlot(player, CS_SLOT_KNIFE) == -1)
			GivePlayerItem(player, "weapon_knife");
		
		if (GetPlayerWeaponSlot(player, CS_SLOT_SECONDARY) == -1)
			GivePlayerItem(player, "weapon_glock");
		
		TeamInitialize(player);
		
		g_bFound[player] = false;
		
		RemoveFromArray(g_hPlayerArray, index);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_iRole[i] != T)
			continue;
		listTraitors(i);
	}
	
	ClearArray(g_hLogsArray);
	g_bRoundStarted = true;
	ApplyIcons();
}

stock int GetRandomArray()
{
	int size = GetArraySize(g_hPlayerArray);
	if(size == 0)
		return -1;
	return Math_GetRandomInt(0, size-1);
}

stock void TeamInitialize(int client)
{
	if(g_iRole[client] == D)
	{
		g_iIcon[client] = CreateIcon(client);
		CS_SetClientClanTag(client, "DETECTIVE");

		if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == -1)
			GivePlayerItem(client, "weapon_m4a1_silencer");
			
		GivePlayerItem(client, "weapon_taser");
		CPrintToChat(client, PF, "Your Team is DETECTIVES", client);
		SetEntityHealth(client, g_iCvar[c_spawnHPD].IntValue);
	}
	else if(g_iRole[client] == T)
	{
		g_iIcon[client] = CreateIcon(client);
		CPrintToChat(client, PF, "Your Team is TRAITORS", client);
		SetEntityHealth(client, g_iCvar[c_spawnHPT].IntValue);
	}
	else if(g_iRole[client] == I)
	{
		CPrintToChat(client, PF, "Your Team is INNOCENTS", client);
		SetEntityHealth(client, g_iCvar[c_spawnHPI].IntValue);
	}
}

stock void TeamTag(int client)
{
	if (!IsClientInGame(client) || client < 0 || client > MaxClients)
		return;
		
	if(g_iRole[client] == D)
		CS_SetClientClanTag(client, "DETECTIVE");
	else if(g_iRole[client] == T)
		CS_SetClientClanTag(client, "TRAITOR");
	else if(g_iRole[client] == I)
		CS_SetClientClanTag(client, "INNOCENT");
}

stock void ApplyIcons()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && IsPlayerAlive(i))
			g_iIcon[i] = CreateIcon(i);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientValid(client))
	{
		CS_SetClientClanTag(client, "");
		
		g_iInnoKills[client] = 0;
		CPrintToChat(client, PF, "Your REAL money is", client, g_iCredits[client]);
		CPrintToChat(client, PF, "Your karma is", client, g_iKarma[client]);
		
		StripAllWeapons(client);
		
		ClearTimer(g_hJihadBomb[client]);
		g_bDetonate[client] = false;
		
		if(g_bInactive)
		{
			int iCount = 0;
			
			for(int i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i) && IsPlayerAlive(i))
					iCount++;
			
			if(iCount >= 3)
				ServerCommand("mp_restartgame 2");
		}
		
		g_b1Knife[client] = false;
		g_bScan[client] = false;
		g_bID[client] = false;
		g_bJihadBomb[client] = false;
	}
}

public void OnClientPutInServer(int client)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	


	//g_bFound[client] = true;
	
	//g_iRole[client] = U;
	
	g_bImmuneRDMManager[client] = false;
	
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponPostSwitch);
	SDKHook(client, SDKHook_ThinkPost, ThinkPost);
	
	SetEntData(client, g_iAccount, MONEYHIDE);
		
	g_iCredits[client] = 800;
}

public Action ThinkPost(int client)
{
	if(IsClientValid(client))
	{
		if(g_bKarma[client] && g_iCvar[c_karmaBan].IntValue != 0 && g_iKarma[client] <= g_iCvar[c_karmaBan].IntValue)
		{
			BanBadPlayerKarma(client);
		}
		
		CS_SetClientContributionScore(client, g_iKarma[client]);
	}
}

public void OnClientCookiesCached(int client) {
	char sValue[32];
	GetClientCookie(client, g_hKarmaCookie, sValue, sizeof(sValue));
	int karma = (sValue[0] != '\0' && StringToInt(sValue));
	
	if (karma == 0)
	{
		g_iKarma[client] = g_iCvar[c_startKarma].IntValue;
		
		char sKarma[32];
		IntToString(g_iKarma[client], sKarma, sizeof(sKarma));
		SetClientCookie(client, g_hKarmaCookie, sKarma);
	}
	else if (karma > 0 && karma <= g_iCvar[c_karmaBan].IntValue)
		BanBadPlayerKarma(client);
	else
	{
		g_iKarma[client] = karma;
		SetClientCookie(client, g_hKarmaCookie, sValue);
	}
	
	g_bKarma[client] = true;
}

stock void AddStartKarma(int client)
{
	g_iKarma[client] = g_iCvar[c_startKarma].IntValue;
	
	char sKarma[32];
	IntToString(g_iKarma[client], sKarma, sizeof(sKarma));
	SetClientCookie(client, g_hKarmaCookie, sKarma);
}

stock void BanBadPlayerKarma(int client)
{
	char sReason[512];
	Format(sReason, sizeof(sReason), "%T", "Your Karma is too low", client);
	
	char sKarma[32];
	g_iCvar[c_startKarma].GetString(sKarma, sizeof(sKarma));
	SetClientCookie(client, g_hKarmaCookie, sKarma);
	
	ServerCommand("sm_ban #%d %d \"%s\"", GetClientUserId(client), g_iCvar[c_karmaBanLength].IntValue, sReason);
}

stock bool IsClientValid(int client) 
{ 
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
	return false;
}

public Action OnTakeDamage(int client, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if(!g_bRoundStarted)
		return Plugin_Handled;
	
	if(!IsClientValid(iAttacker))
		return Plugin_Continue;
	
	char classname[64];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	char item[512];
	if(StrContains(classname, "_projectile") == -1)
	{
		GetClientWeapon(iAttacker, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_taser"))
		{
			if(g_iRole[client] == T)
			{
				Format(item, sizeof(item), "-> [%N tased %N (Traitor)] - TRAITOR DETECTED", iAttacker, client);
				PushArrayString(g_hLogsArray, item);
				CPrintToChat(iAttacker, PF, "You hurt a Traitor", client, client);
				addCredits(iAttacker, g_iCvar[c_creditsTaserHurtTraitor].IntValue);
			}
			else if(g_iRole[client] == D) {
				Format(item, sizeof(item), "-> [%N tased %N (Detective)]", client, iAttacker, client);
				PushArrayString(g_hLogsArray, item);
				CPrintToChat(iAttacker, PF, "You hurt a Detective", client, client);
			}
			else if(g_iRole[client] == I) {
				Format(item, sizeof(item), "-> [%N tased %N (Innocent)]", client, iAttacker, client);
				PushArrayString(g_hLogsArray, item);
				CPrintToChat(iAttacker, PF, "You hurt an Innocent", client, client);
			}
			damage = 0.0;
			return Plugin_Changed;
		}
		else if(g_b1Knife[iAttacker] && (StrContains(classname, "knife", false) != -1) || (StrContains(classname, "bayonet", false) != -1))
		{
			Remove1Knife(iAttacker);
			damage = 1000.0;
			return Plugin_Changed;
		}
	}
	
	if(g_iKarma[iAttacker] == 100)
		return Plugin_Continue;
	
	damage = (damage * (g_iKarma[iAttacker] * 0.01));
	
	if(damage < 1.0)
		damage = 1.0;
	
	return Plugin_Changed;
}


public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iInnoKills[client] = 0;
	ClearIcon(client);
	
	ClearTimer(g_hJihadBomb[client]);
	if(g_iRole[client] > U)
	{
		char playermodel[128];
		GetClientModel(client, playermodel, 128);
	
		float origin[3], angles[3], velocity[3];
	
		GetClientAbsOrigin(client, origin);
		GetClientAbsAngles(client, angles);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
	
		int iEntity = CreateEntityByName("prop_ragdoll");
		//int iEntity = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(iEntity, "model", playermodel);
		DispatchSpawn(iEntity);
		//AcceptEntityInput(iEntity, "BecomeRagdoll");
	
		float speed = GetVectorLength(velocity);
		if(speed >= 500) TeleportEntity(iEntity, origin, angles, NULL_VECTOR); 
		else TeleportEntity(iEntity, origin, angles, velocity); 
	
		SetEntData(iEntity, g_iCollisionGroup, 2, 4, true);
	

		int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		char name[32];
		GetClientName(client, name, sizeof(name));
		int Items[Ragdolls];
		Items[ent] = EntIndexToEntRef(iEntity);
		Items[victim] = client;
		Format(Items[victimName], 32, name);
		Items[scanned] = false;
		GetClientName(iAttacker, name, sizeof(name));
		Items[attacker] = iAttacker;
		Format(Items[attackerName], 32, name);
		Items[gameTime] = GetGameTime();
		GetEventString(event, "weapon", Items[weaponused], sizeof(Items[weaponused]));
	
		PushArrayArray(g_hRagdollArray, Items[0]);
		
		//int addition
		if (client != iAttacker && iAttacker != 0 && !g_bImmuneRDMManager[iAttacker] && !g_bHoldingProp[client] && !g_bHoldingSilencedWep[client]) {
			if (g_iRole[iAttacker] == T && g_iRole[client] == T) {
				if (g_hRDMTimer[client] != INVALID_HANDLE)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			} else if (g_iRole[iAttacker] == D && g_iRole[client] == D) {
				if (g_hRDMTimer[client] != INVALID_HANDLE)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			} else if (g_iRole[iAttacker] == I && g_iRole[client] == D) {
				if (g_hRDMTimer[client] != INVALID_HANDLE)
					KillTimer(g_hRDMTimer[client]);
				g_hRDMTimer[client] = CreateTimer(3.0, Timer_RDMTimer, GetClientUserId(client));
				g_iRDMAttacker[client] = iAttacker;
			} else if ((g_iRole[iAttacker] == I && g_iRole[client] == I) || (g_iRole[iAttacker] == D && g_iRole[client] == I)) {
				g_iInnoKills[iAttacker]++;
			}

			if (g_iInnoKills[iAttacker] >= 3) {
				ServerCommand("sm_slay #%i 5", GetClientUserId(iAttacker));
			}
		}
		
		//int addition ^
	}
	if(!dontBroadcast)
	{	
		dontBroadcast = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	nameCheck(client, name);
}

public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client))
	{
		char sKarma[12];
		IntToString(g_iKarma[client], sKarma, sizeof(sKarma));
		SetClientCookie(client, g_hKarmaCookie, sKarma);
		g_bKarma[client] = false;
	}
	if (g_hRDMTimer[client] != INVALID_HANDLE) {
		KillTimer(g_hRDMTimer[client]);
		g_hRDMTimer[client] = INVALID_HANDLE;
	}
	if (g_hRemoveCoolDownTimer[client] != INVALID_HANDLE) {
		KillTimer(g_hRemoveCoolDownTimer[client]);
		g_hRemoveCoolDownTimer[client] = INVALID_HANDLE;
	}
	ClearIcon(client);
	
	ClearTimer(g_hJihadBomb[client]);
	
	g_bReceivingLogs[client] = false;
	g_bImmuneRDMManager[client] = false;
/* 	int thesize = GetArraySize(g_hRagdollArray);
	
	if(thesize == 0) return;
	
	int Items[Ragdolls];
			
	for(int i = 0;i < GetArraySize(g_hRagdollArray);i++)
	{
		GetArrayArray(g_hRagdollArray, i, Items[0]);
				
		if(client == Items[attacker] || client == Items[victim])
		{
			int entity = EntRefToEntIndex(Items[index]);
			if(entity != INVALID_ENT_REFERENCE) AcceptEntityInput(entity, "kill");
					
			RemoveFromArray(g_hRagdollArray, i);
			break;
		}
	}  */
	
	if (g_hExplosionTimer[client] != INVALID_HANDLE) {
		KillTimer(g_hExplosionTimer[client]);
		g_hExplosionTimer[client] = INVALID_HANDLE;
	}
}

public Action Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientInGame(client)) return;
		
	char userName[32];
	GetEventString(event, "newname", userName, sizeof(userName));
	nameCheck(client, userName);
	
 	int thesize = GetArraySize(g_hRagdollArray);
	
	if(thesize == 0) return;
	
	int Items[Ragdolls];
			
	for(int i = 0;i < GetArraySize(g_hRagdollArray);i++)
	{
		GetArrayArray(g_hRagdollArray, i, Items[0]);
				
		if(client == Items[attacker])
		{
			Format(Items[attackerName], 32, userName);
			SetArrayArray(g_hRagdollArray, i, Items[0]);
		}
		else if(client == Items[victim])
		{
			Format(Items[victimName], 32, userName);
			SetArrayArray(g_hRagdollArray, i, Items[0]);
		}
	} 
}

public Action Timer_Adjust(Handle timer)
{
	int I_lives = 0;
	int T_lives = 0;
	float vec[3];
	for(int i = 1; i <=MaxClients; ++i)
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(CS_GetClientAssists(i) != 0)
				CS_SetClientAssists(i, 0);
			if(CS_GetClientContributionScore(i) != 0)
				CS_SetClientContributionScore(i, 0);
				
			if(g_iRole[i] == T)
			{
				GetClientAbsOrigin(i, vec);
		
				vec[2] += 10;
				T_lives++;
				//TE_SetupBeamRingPoint(vec, 10.0, 190.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 1.0, 5.0, 0.0, {0, 0, 255, 255}, 10, 0);
				int[] clients = new int[MaxClients];
				int index = 0;
				for(int i2 = 1; i2 <=MaxClients; ++i2)
					if(IsClientInGame(i2) && IsPlayerAlive(i2) && i2 != i && (g_iRole[i2] == T))
					{
						clients[ent] = i2;
						index++;
					}
				
				TE_SetupBeamRingPoint(vec, 50.0, 60.0, g_iBeamSprite, g_iHaloSprite, 0, 15, 0.1, 10.0, 0.0, {0, 0, 255, 255}, 10, 0);
				TE_Send(clients, index);
			}
			else if(g_iRole[i] == I)
			{
				I_lives++;
			}

			int money = GetEntData(i, g_iAccount);
			if(money != MONEYHIDE)
			{
				SetEntData(i, g_iAccount, MONEYHIDE);
				//g_iCredits[i] += RoundToNearest((money-MONEYHIDE) * (g_iKarma[i] * 0.01));
			}
		}
		
	if(g_bRoundStarted)
	{
		if(I_lives == 0)
		{
			g_bRoundStarted = false;
			CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
		}
		else if(T_lives == 0)
		{		
			g_bRoundStarted = false;
			CS_TerminateRound(7.0, CSRoundEnd_CTWin);
		}
	}
	
/* 	int thesize = GetArraySize(g_hRagdollArray);
	
	if(thesize == 0) return;
	
	int Items[Ragdolls];
			
	for(int i = 0;i < GetArraySize(g_hRagdollArray);i++)
	{
		GetArrayArray(g_hRagdollArray, i, Items[0]);
				
		int entity = EntRefToEntIndex(Items[index]);
		if(entity != INVALID_ENT_REFERENCE)
		{
			float fVelocity[3];
			GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
			float speed = GetVectorLength(fVelocity);
			if(speed >= 4000)
			{
				AcceptEntityInput(entity, "kill");
				RemoveFromArray(g_hRagdollArray, i);
			}
			else if(speed >= 500)
			{
				if(!(GetEntityFlags(entity) & FL_FROZEN))
				{
					int flags = GetEntityFlags(entity);
					SetEntityFlags(entity, flags|FL_FROZEN);
					CreateTimer(3.0, Des, EntIndexToEntRef(entity));
				}
			}
		}
					
	}  */
}

/* public Action Des(Handle timer, any ref2)
{
	int entity = EntRefToEntIndex(ref2);
	if(entity != INVALID_ENT_REFERENCE)
	{
		if(GetEntityFlags(entity) & FL_FROZEN)
		{
			int flags = GetEntityFlags(entity);
			SetEntityFlags(entity, flags&~FL_FROZEN);
		}
	}
} */

public Action ShowMoney(int client, int args)
{
	CPrintToChat(client, PF, "Your REAL money is", client, g_iCredits[client]);
	
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
	if (!IsValidEntity(client))
		return;
    
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll<0)
		return;

	AcceptEntityInput(ragdoll, "Kill");
	
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!iAttacker || iAttacker == client)
		return;
	
	int assister = GetClientOfUserId(GetEventInt(event, "assister"));
	if(!assister || assister == client)
		return;
	
 	if(CS_GetClientAssists(assister) != 0) 
 		CS_SetClientAssists(assister, 0);
	if(GetEntProp(client, Prop_Data, "m_iDeaths") != 0)
		SetEntProp(client, Prop_Data, "m_iDeaths", 0);
	if(GetEntProp(iAttacker, Prop_Data, "m_iFrags") != 0)
		SetEntProp(iAttacker, Prop_Data, "m_iFrags", 0);
	
	if(g_iRole[iAttacker] == T)
		CPrintToChat(client, PF, "Your killer is a Traitor", client);
	else if(g_iRole[iAttacker] == D)
		CPrintToChat(client, PF, "Your killer is a Detective", client);
	else if(g_iRole[iAttacker] == I)
		CPrintToChat(client, PF, "Your killer is an Innocent", client);
	
	if(g_iRole[client] == T)
		CPrintToChat(iAttacker, PF, "You killed a Traitor", client);
	else if(g_iRole[client] == D)
		CPrintToChat(iAttacker, PF, "You killed a Detective", client);
	else if(g_iRole[client] == I)
		CPrintToChat(iAttacker, PF, "You killed an Innocent", client);
	char item[512];
	
	if(g_iRole[iAttacker] == I && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Traitor)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		g_iKarma[iAttacker] += g_iCvar[c_karmaIT].IntValue;
		addCredits(iAttacker, g_iCvar[c_creditsIT].IntValue);
	}
	else if(g_iRole[iAttacker] == I && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Detective)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		g_iKarma[iAttacker] -= g_iCvar[c_karmaID].IntValue;
		subtractCredits(iAttacker, g_iCvar[c_creditsID].IntValue);
		//RDM(iAttacker);
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Detective)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		
		g_iKarma[iAttacker] += g_iCvar[c_karmaTD].IntValue;
		addCredits(iAttacker, g_iCvar[c_creditsTD].IntValue);
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Innocent)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		
		g_iKarma[iAttacker] += g_iCvar[c_karmaTI].IntValue;
		addCredits(iAttacker, g_iCvar[c_creditsTI].IntValue);
	}
	else if(g_iRole[iAttacker] == D && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Traitor)]", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		g_iKarma[iAttacker] += g_iCvar[c_karmaDT].IntValue;
		addCredits(iAttacker, g_iCvar[c_creditsDT].IntValue);
	}
	else if(g_iRole[iAttacker] == D && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Innocent)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		
		g_iKarma[iAttacker] -= g_iCvar[c_karmaDI].IntValue;
		//RDM(iAttacker);
		subtractCredits(iAttacker, g_iCvar[c_creditsDI].IntValue);
	}
	else if(g_iRole[iAttacker] == I && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) killed %N (Innocent)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		
		g_iKarma[iAttacker] -= g_iCvar[c_karmaII].IntValue;
		//RDM(iAttacker);
		subtractCredits(iAttacker, g_iCvar[c_creditsII].IntValue);
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) killed %N (Traitor)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		g_iKarma[iAttacker] -= g_iCvar[c_karmaTT].IntValue;
		//RDM(iAttacker);
		subtractCredits(iAttacker, g_iCvar[c_creditsTT].IntValue);
	}
	
	else if(g_iRole[iAttacker] == D && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Detective) killed %N (Detective)] - BAD ACTION", iAttacker, client);
		PushArrayString(g_hLogsArray, item);
		g_iKarma[iAttacker] -= g_iCvar[c_karmaDD].IntValue;
		//RDM(iAttacker);
		subtractCredits(iAttacker, g_iCvar[c_creditsDD].IntValue);
	}
	
	if(g_iKarma[iAttacker] > g_iCvar[c_maxKarma].IntValue)
		g_iKarma[iAttacker] = g_iCvar[c_maxKarma].IntValue;

	char result[32];
	IntToString(g_iKarma[iAttacker], result, sizeof(result));
	SetClientCookie(iAttacker, g_hKarmaCookie, result);
	
	CheckTeams();
}

stock int CreateIcon(int client) {
  
	ClearIcon(client);
	if(g_iRole[client] < T || !g_bRoundStarted)
		return 0;
	
	char iTarget[16];
	Format(iTarget, 16, "client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float origin[3];
  
	GetClientAbsOrigin(client, origin);				
	origin[2] = origin[2] + 80.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	if(g_iRole[client] == D) DispatchKeyValue(Ent, "model", "sprites/sg_detective_icon.vmt");
	else if(g_iRole[client] == T) DispatchKeyValue(Ent, "model", "sprites/sg_traitor_icon.vmt");
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.08");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);
 
	if(g_iRole[client] == T)
		SDKHook(Ent, SDKHook_SetTransmit, Hook_SetTransmitT); 
	return Ent;
}

public Action Hook_SetTransmitT(int entity, int client) 
{ 
    if (entity != client && g_iRole[client] != T && IsPlayerAlive(client)) 
        return Plugin_Handled;
     
    return Plugin_Continue; 
}  

public void OnMapEnd() {
	if (g_hRoundTimer != INVALID_HANDLE) {
		CloseHandle(g_hRoundTimer);
		g_hRoundTimer = INVALID_HANDLE;
	}
	resetPlayers();
}

public Action Timer_OnRoundEnd(Handle timer) 
{
	g_hRoundTimer = INVALID_HANDLE;
	
	//CS_TerminateRound(7.0, CSRoundEnd_Draw);
	
	g_bRoundStarted = false;
	CS_TerminateRound(7.0, CSRoundEnd_CTWin);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if(g_bRoundStarted)
		return Plugin_Handled;
	
	for(int client = 1; client <=MaxClients; ++client)
		if(IsClientInGame(client) && IsPlayerAlive(client))
			ClearIcon(client);
	
	if(reason == CSRoundEnd_CTWin)
	{
		for(int client = 1; client <=MaxClients; ++client)
			if(IsClientInGame(client))
			{
				if(g_iRole[client] != T && g_iRole[client] != U)
				{
					if(IsPlayerAlive(client))
						addCredits(client, g_iCvar[c_traitorloseAliveNonTraitors].IntValue);
					else
						addCredits(client, g_iCvar[c_traitorloseDeadNonTraitors].IntValue);
				}
			}
			
		ShowOverlayToAll("overlays/ttt/innocents_win");
	}
	else if(reason == CSRoundEnd_TerroristWin)
	{
		for(int client = 1; client <=MaxClients; ++client)
			if(IsClientInGame(client))
			{
				if(g_iRole[client] == T)
				{
					if(IsPlayerAlive(client))
						addCredits(client, g_iCvar[c_traitorwinAliveTraitors].IntValue);
					else
						addCredits(client, g_iCvar[c_traitorwinDeadTraitors].IntValue);
				}
			}
			
			
		ShowOverlayToAll("overlays/ttt/traitors_win");
	}
	//if(reason == CSRoundEnd_CTWin) ShowOverlayToAll("overlays/ttt/detectives_win");
	
	//ShowLog();
	healthStation_cleanUp();
	return Plugin_Continue;
}

stock void ShowOverlayToClient(int client, const char[] overlaypath)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock void ShowOverlayToAll(const char[] overlaypath)
{
	// x = client index.
	for (int x = 1; x <= MaxClients; x++)
	{
		// If client isn't in-game, then stop.
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

stock void StripAllWeapons(int client)
{
    int iEnt;
    for (int i = 0; i <= 4; i++)
    {
		while ((iEnt = GetPlayerWeaponSlot(client, i)) != -1)
		{
            RemovePlayerItem(client, iEnt);
            AcceptEntityInput(iEnt, "Kill");
		}
    }
}  

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{	
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!iAttacker)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	
	int damage = GetEventInt(event, "dmg_health");
	char item[512];
	if(g_iRole[iAttacker] == I && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Innocent) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == I && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Traitor) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == I && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Innocent) damaged %N (Detective) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Innocent) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
		
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Innocent) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
		
	}
	else if(g_iRole[iAttacker] == T && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Traitor) damaged %N (Detective) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == D && g_iRole[client] == I)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Innocent) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
		
	}
	else if(g_iRole[iAttacker] == D && g_iRole[client] == T)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Traitor) for %i damage]", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
	else if(g_iRole[iAttacker] == D && g_iRole[client] == D)
	{
		Format(item, sizeof(item), "-> [%N (Detective) damaged %N (Detective) for %i damage] - BAD ACTION", iAttacker, client, damage);
		PushArrayString(g_hLogsArray, item);
	}
}

/* RDM(client)
{
	for(int i = 1; i <=MaxClients; ++i)
		if(IsClientInGame(i) && (GetUserFlagBits(i) & ADMFLAG_BAN)) CPrintToChat(i, PF, "is possibly RDMing", client);
} */

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsClientInGame(client)) return Plugin_Continue;
	
	if(buttons & IN_USE)
	{
		g_bHoldingProp[client] = true;
		
		int entidad = GetClientAimTarget(client, false);
		if(entidad > 0)
		{
			float OriginG[3], TargetOriginG[3];
			GetClientEyePosition(client, TargetOriginG);
			GetEntPropVector(entidad, Prop_Data, "m_vecOrigin", OriginG);
			if(GetVectorDistance(TargetOriginG,OriginG, false) > 90.0) return Plugin_Continue;
			
			
		 	int thesize = GetArraySize(g_hRagdollArray);
	
			if(thesize == 0) return Plugin_Continue;
	
			int Items[Ragdolls];
			int entity;
			
			for(int i = 0;i < thesize;i++)
			{
				GetArrayArray(g_hRagdollArray, i, Items[0]);
				entity = EntRefToEntIndex(Items[ent]);
				
				if(entity == entidad)
				{
					//if(!IsClientValid(Items[victim])) return;
					
					MostrarMenu(client, Items[victim], Items[attacker], RoundToNearest(GetGameTime()-Items[gameTime]), Items[weaponused], Items[victimName], Items[attackerName]);
					
					if(!Items[found] && IsPlayerAlive(client))
					{
						Items[found] = true;
						if(IsClientInGame(Items[victim])) g_bFound[Items[victim]] = true;
						
						if(g_iRole[Items[victim]] == I) 
						{
							LoopValidClients(j)
								CPrintToChat(j, PF, "Found Innocent", j, client, Items[victimName]);
							SetEntityRenderColor(entidad, 0, 255, 0, 255);
						}
						else if(g_iRole[Items[victim]] == D)
						{
							LoopValidClients(j)
								CPrintToChat(j, PF, "Found Detective", j, client, Items[victimName]);
							SetEntityRenderColor(entidad, 0, 0, 255, 255);
						}
						else if(g_iRole[Items[victim]] == T) 
						{
							LoopValidClients(j)
								CPrintToChat(j, PF, "Found Traitor", j, client,Items[victimName]);
							SetEntityRenderColor(entidad, 255, 0, 0, 255);
						}
						
						TeamTag(Items[victim]);
						
						
						
						addCredits(client, g_iCvar[c_creditsFoundBody].IntValue);
					}
					
					if(g_bScan[client] && !Items[scanned] && IsPlayerAlive(client))
					{
						Items[scanned] = true;
						if(Items[attacker] > 0 && Items[attacker] != Items[victim])
						{
							LoopValidClients(j)
								CPrintToChat(j, PF, "Detective scan found body", j, client, Items[attackerName], Items[weaponused]);
						}
						else
						{
							LoopValidClients(j)
								CPrintToChat(j, PF, "Detective scan found body suicide", j, client);
						}
						
						
					}
					SetArrayArray(g_hRagdollArray, i, Items[0]);
					
					break;
				}
			} 
		}
	} else {
		g_bHoldingProp[client] = false;
	}
	//C4 MOD
	if (buttons & IN_RELOAD && g_iDefusePlayerIndex[client] == -1) {
		int target = GetClientAimTarget(client, false);
		if (target > 0) {
			float clientEyes[3], targetOrigin[3];
			GetClientEyePosition(client, clientEyes);
			GetEntPropVector(target, Prop_Data, "m_vecOrigin", targetOrigin);
			if (GetVectorDistance(clientEyes, targetOrigin) > 100.0) return Plugin_Continue;
			int iEnt;
			while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1) {
				int planter = GetEntProp(target, Prop_Send, "m_hOwnerEntity");
				if (planter < 1 || planter > MaxClients || !IsClientInGame(planter)) return Plugin_Continue;
				if (target == iEnt) {
					g_iDefusePlayerIndex[client] = planter;
					showDefuseMenu(client);
				}
			}
		}
	}
	if (buttons & IN_ATTACK2 && !g_bHasActiveBomb[client] && g_bHasC4[client]) {
		g_bHasActiveBomb[client] = true;
		int bombEnt = CreateEntityByName("prop_physics");
		if (bombEnt != -1) {
			float clientPos[3];
			GetClientAbsOrigin(client, clientPos);
			SetEntProp(bombEnt, Prop_Data, "m_CollisionGroup", 1);
			SetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity", client);
			DispatchKeyValue(bombEnt, "model", "models/weapons/w_c4_planted.mdl");
			DispatchSpawn(bombEnt);
			TeleportEntity(bombEnt, clientPos, NULL_VECTOR, NULL_VECTOR);
			showPlantMenu(client);
		}
	}
	return Plugin_Continue;
	//
}

public Action ShowID(int client, int args)
{
	if(g_bID[client] && IsPlayerAlive(client))
	{
		LoopValidClients(i)
			CPrintToChat(i, PF, "Player Is an Innocent", i, client);
	}
	else
		CPrintToChat(client, PF, "You dont have it!", client);
	
	return Plugin_Handled;

}

public Action SayTeam(int client, int args)
{
	if(!client || !IsPlayerAlive(client)) return Plugin_Continue;
	
	char SayText[512];
	GetCmdArgString(SayText,sizeof(SayText));
	
	StripQuotes(SayText);
	
	if(strlen(SayText) < 2) return Plugin_Continue;
		
	if (SayText[0] == '@') return Plugin_Continue;
	
	if(g_iRole[client] == T)
	{
		for(int i = 1; i <=MaxClients; ++i)
			if(IsClientInGame(i) && (g_iRole[i] == T || !IsPlayerAlive(i))) 
			{
				EmitSoundToClient(i, "buttons/button18.wav");
				CPrintToChat(i, " %T", "T channel", i, client, SayText);
			}
			
		return Plugin_Handled;
	}
	else if(g_iRole[client] == D)
	{
		for(int i = 1; i <=MaxClients; ++i)
			if(IsClientInGame(i) && (g_iRole[i] == D || !IsPlayerAlive(i))) 
			{
				EmitSoundToClient(i, "buttons/button18.wav");
				CPrintToChat(i, " %T", "D channel", i, client, SayText);
			}
			
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action ShowMenu(int client, int args)
{
	int team = g_iRole[client];
	if(team != U)
	{
		char MenuItem[128];
		Handle menu = CreateMenu(DIDMenuHandler);
		SetMenuTitle(menu, "%T", "TTT Shop", client);
	
		if(team == T)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "Buy c4", client, g_iCvar[c_shopC4].IntValue);
			AddMenuItem(menu, "C4", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "Buy jihadbomb", client, g_iCvar[c_shopJIHADBOMB].IntValue);
			AddMenuItem(menu, "jbomb", MenuItem);
			
			
			Format(MenuItem, sizeof(MenuItem),"%T", "1 hit kill knife (only good for 1 shot)", client, g_iCvar[c_shop1KNIFE].IntValue);
			AddMenuItem(menu, "1knife", MenuItem);

			Format(MenuItem, sizeof(MenuItem),"%T", "FAKE ID card (type !id for show your innocence)", client, g_iCvar[c_shopFAKEID].IntValue);
			AddMenuItem(menu, "fakeID", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "M4S", client, g_iCvar[c_shopM4A1].IntValue);
			AddMenuItem(menu, "m4s", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "USPS", client, g_iCvar[c_shopUSP].IntValue);
			AddMenuItem(menu, "usps", MenuItem);
			
		}
		if(team == D)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "Health Station", client, g_iCvar[c_shopHEALTH].IntValue);
			AddMenuItem(menu, "HealthStation", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "DNA scanner (scan a dead body and show who the killer is)", client, g_iCvar[c_shopDNA].IntValue);
			AddMenuItem(menu, "scan13", MenuItem);
		}
		if(team != I)
		{
			Format(MenuItem, sizeof(MenuItem),"%T", "Kevlar", client, g_iCvar[c_shopKEVLAR].IntValue);
			AddMenuItem(menu, "kevlar", MenuItem);
		}
		if(team == I)
		{
/*    		Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Traitor", client, g_iCvar[c_shopT].IntValue);
			AddMenuItem(menu, "buyT", MenuItem);
			
			Format(MenuItem, sizeof(MenuItem),"%T", "Buy rol Detective", client, g_iCvar[c_shopD].IntValue);
			AddMenuItem(menu, "buyD", MenuItem); */
			
			Format(MenuItem, sizeof(MenuItem),"%T", "ID card (type !id for show your innocence)", client, g_iCvar[c_shopID].IntValue);
			AddMenuItem(menu, "ID", MenuItem);
		}
		Format(MenuItem, sizeof(MenuItem),"%T", "Taser", client, g_iCvar[c_shopTASER].IntValue);
		AddMenuItem(menu, "taser", MenuItem);
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 15);
	
	}
	else
		CPrintToChat(client, PF, "Please wait till your team is assigned", client);
	
	return Plugin_Handled;

}

public int DIDMenuHandler(Menu menu, MenuAction action, int client, int itemNum) 
{
	if ( action == MenuAction_Select ) 
	{
		if(!IsPlayerAlive(client)) return;
		char info[32];
		
		GetMenuItem(menu, itemNum, info, sizeof(info));
		if ( strcmp(info,"kevlar") == 0 ) 
		{
			if(g_iCredits[client] >= g_iCvar[c_shopKEVLAR].IntValue)
			{
				GivePlayerItem( client, "item_assaultsuit");
				g_iCredits[client] -= g_iCvar[c_shopKEVLAR].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"1knife") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shop1KNIFE].IntValue)
			{
				if (g_iRole[client] != T)
					return;
				Set1Knife(client);
				g_iCredits[client] -= g_iCvar[c_shop1KNIFE].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"scan13") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopDNA].IntValue)
			{
				g_bScan[client] = true;
				g_iCredits[client] -= g_iCvar[c_shopDNA].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"ID") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopID].IntValue)
			{
				g_bID[client] = true;
				g_iCredits[client] -= g_iCvar[c_shopID].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"fakeID") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopFAKEID].IntValue)
			{
				g_bID[client] = true;
				g_iCredits[client] -= g_iCvar[c_shopFAKEID].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"buyT") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopT].IntValue)
			{
				g_iRole[client] = T;
				TeamInitialize(client);
				g_iCredits[client] -= g_iCvar[c_shopT].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"buyD") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopD].IntValue)
			{
				g_iRole[client] = D;
				TeamInitialize(client);
				g_iCredits[client] -= g_iCvar[c_shopD].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"taser") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopTASER].IntValue)
			{
				GivePlayerItem(client, "weapon_taser");
				g_iCredits[client] -= g_iCvar[c_shopTASER].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"usps") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopUSP].IntValue)
			{
				if (g_iRole[client] != T)
					return;
				if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
					SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
				
				GivePlayerItem(client, "weapon_usp_silencer");
				g_iCredits[client] -= g_iCvar[c_shopUSP].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"m4s") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopM4A1].IntValue)
			{
				if (g_iRole[client] != T)
					return;
				
				if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
					SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
				
				GivePlayerItem(client, "weapon_m4a1_silencer");
				g_iCredits[client] -= g_iCvar[c_shopM4A1].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if ( strcmp(info,"jbomb") == 0 )
		{
			if(g_iCredits[client] >= g_iCvar[c_shopJIHADBOMB].IntValue)
			{
				if (g_iRole[client] != T)
					return;
				g_bJihadBomb[client] = true;
				ClearTimer(g_hJihadBomb[client]);
				g_hJihadBomb[client] = CreateTimer(60.0, BombaArmada, client);
				g_iCredits[client] -= g_iCvar[c_shopJIHADBOMB].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
				CPrintToChat(client, PF, "bomb will arm in 60 seconds, double tab F to explode", client);
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if (strcmp(info, "C4") == 0) {
			if (g_iCredits[client] >= g_iCvar[c_shopC4].IntValue) {
				if (g_iRole[client] != T)
					return;
				g_bHasC4[client] = true;
				g_iCredits[client] -= g_iCvar[c_shopC4].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
				PrintToChat(client, "[\x04T\x02T\x0BT\x01] Right click to plant the C4!"); // TODO: Translations
			}
			else CPrintToChat(client, PF, "You don't have enough money", client);
		}
		else if (strcmp(info, "HealthStation") == 0) {
			if (g_iCredits[client] >= g_iCvar[c_shopHEALTH].IntValue) {
				if (g_iRole[client] != D)
					return;
				if (g_bHasActiveHealthStation[client]) {
					PrintToChat(client, "[\x04T\x02T\x0BT\x01]You already have an active Health Station!"); // TODO: Translations
					return;
				}
				spawnHealthStation(client);
				g_iCredits[client] -= g_iCvar[c_shopHEALTH].IntValue;
				CPrintToChat(client, PF, "Item bought! Your REAL money is", client, g_iCredits[client]);
			}
		}
	}
		
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action BombaArmada(Handle timer, any client) 
{ 
	CPrintToChat(client, PF, "Your bomb is now armed.", client);
	EmitAmbientSound("buttons/blip2.wav", NULL_VECTOR, client);
	g_hJihadBomb[client] = INVALID_HANDLE;	
} 

stock void MostrarMenu(int client, int victima2, int atacante2, int tiempo2, const char[] weapon, const char[] victimaname2, const char[] atacantename2)
{
	//if(!IsClientValid(victima2)) return;
	
	char team[32];
	if(g_iRole[victima2] == T)
	{
		Format(team, sizeof(team), "%T", "Traitors", client);
	}
	else if(g_iRole[victima2] == D)
	{
		Format(team, sizeof(team), "%T", "Detectives", client);
	}
	else if(g_iRole[victima2] == I) 
	{
		Format(team, sizeof(team), "%T", "Innocents", client);
	}

	Handle menu = CreateMenu(BodyMenuHandler);
	char Item[128];
	
	SetMenuTitle(menu, "%T", "Inspected body. The extracted data are the following", client);
	
	Format(Item, sizeof(Item), "%T", "Victim name", client, victimaname2);
	AddMenuItem(menu, "", Item);
	
	Format(Item, sizeof(Item), "%T", "Team victim", client, team);
	AddMenuItem(menu, "", Item);
	
	if(g_iRole[client] == D)
	{
		Format(Item, sizeof(Item), "%T", "Elapsed since his death", client, tiempo2);
		AddMenuItem(menu, "", Item);
		
		if(atacante2 > 0 && atacante2 != victima2)
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been", client, weapon);
			AddMenuItem(menu, "", Item);
		}
		else
		{
			Format(Item, sizeof(Item), "%T", "The weapon used has been: himself (suicide)", client);
			AddMenuItem(menu, "", Item);
		}
	}
	
	if(g_bScan[client])
	{
		if(atacante2 > 0 && atacante2 != victima2) Format(Item, sizeof(Item), "%T", "Killer is Player",client, atacantename2);
		else Format(Item, sizeof(Item), "%T", "Player committed suicide", client);
		
		AddMenuItem(menu, "", Item);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 15);
	
}

public int BodyMenuHandler(Menu menu, MenuAction action, int client, int itemNum) 
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

stock void Set1Knife(int client)
{
	g_b1Knife[client] = true;
	int iWeapon = GetPlayerWeaponSlot(client, 2);
	if (iWeapon != INVALID_ENT_REFERENCE) 
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
	} 
	GivePlayerItem(client, "weapon_knife");
}

stock void Remove1Knife(int client)
{
	g_b1Knife[client] = false;
	int iWeapon = GetPlayerWeaponSlot(client, 2);
	if (iWeapon != INVALID_ENT_REFERENCE) 
	{
		RemovePlayerItem(client, iWeapon);
		AcceptEntityInput(iWeapon, "Kill");
	} 
	GivePlayerItem(client, "weapon_knife");
}

stock void ClearIcon(int client)
{
	if(g_iIcon[client] > 0 && IsValidEdict(g_iIcon[client]))
	{
		if(g_iRole[client] == T) SDKUnhook(g_iIcon[client], SDKHook_SetTransmit, Hook_SetTransmitT);
		AcceptEntityInput(g_iIcon[client], "Kill");
	}
	g_iIcon[client] = 0;
	
}

stock void addCredits(int client, int credits)
{
	credits = RoundToNearest((credits) * (g_iKarma[client] * 0.01));
	g_iCredits[client] += credits;
	
	PrintHintText(client, "%T", "credits earned", client, credits, g_iCredits[client]);
}

stock void subtractCredits(int client, int credits)
{
	g_iCredits[client] -= credits;
	if(g_iCredits[client] < 0) g_iCredits[client] = 0;
	PrintHintText(client, "%T", "lost credits", client, credits, g_iCredits[client]);
}

stock void ClearTimer(Handle &timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }     
} 

stock void Detonate(int client) 
{ 
    // Explosion! 
    int ExplosionIndex = CreateEntityByName("env_explosion"); 
    if (ExplosionIndex != -1) 
    { 
        SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 16384); 
        SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 1000); 
        SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 600); 

        DispatchSpawn(ExplosionIndex); 
        ActivateEntity(ExplosionIndex); 
         
        float playerEyes[3]; 
        GetClientEyePosition(client, playerEyes); 
        //int clientTeam = GetEntProp(client, Prop_Send, "m_iTeamNum"); 

        TeleportEntity(ExplosionIndex, playerEyes, NULL_VECTOR, NULL_VECTOR); 
        SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", client); 
        //SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", clientTeam); 
         
        EmitAmbientSoundAny("ttt/jihad/explosion.mp3", NULL_VECTOR, client, SNDLEVEL_RAIDSIREN); 
         
         
        AcceptEntityInput(ExplosionIndex, "Explode"); 
         
        AcceptEntityInput(ExplosionIndex, "Kill"); 
    } 
    g_bJihadBomb[client] = false;
} 

public Action Command_Detonate(int client, int args) 
{ 
    if (!g_bJihadBomb[client]) 
    { 
		CPrintToChat(client, PF, "You dont have it!", client);
		return Plugin_Handled; 
    } 
	
    if (g_hJihadBomb[client] != INVALID_HANDLE) 
    { 
		CPrintToChat(client, PF, "Your bomb is not armed.", client);
		return Plugin_Handled; 
    } 
     
    EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client); 
         
    CreateTimer(2.0, TimerCallback_Detonate, client); 
    g_bJihadBomb[client] = false;
    //SetEntityRenderColor(client, 255, 0, 0, 255);

    return Plugin_Handled; 
} 

public Action TimerCallback_Detonate(Handle timer, any client) 
{ 
    if(!client || !IsClientInGame(client) || !IsPlayerAlive(client)) 
        return Plugin_Handled;
    
    Detonate(client); 
    return Plugin_Handled; 
} 

public Action Command_LAW(int client, const char[] command, int argc)
{

	if(!IsClientInGame(client))
		return;

	if(!IsPlayerAlive(client) || !g_bJihadBomb[client] || g_hJihadBomb[client] != INVALID_HANDLE)
		return;	

	if(g_bDetonate[client])
	{
		EmitAmbientSoundAny("ttt/jihad/jihad.mp3", NULL_VECTOR, client); 
         
		CreateTimer(2.0, TimerCallback_Detonate, client); 
		g_bJihadBomb[client] = false;
	}
	else
	{
		g_bDetonate[client] = true;
		CreateTimer(2.0, PasarJ, client);
	}

}

public Action PasarJ(Handle timer, any client) 
{ 
	if(!client || !IsClientInGame(client)) 
		return Plugin_Handled;
	
	g_bDetonate[client] = false;
	return Plugin_Handled; 
} 


//RDM Manager
stock void manageRDM(int client)
{
	if (!IsClientInGame(client))
		return;
		
	int iAttacker = g_iRDMAttacker[client];
	if (!IsClientInGame(iAttacker) || iAttacker < 0 || iAttacker > MaxClients)
	{
		PrintToChat(client, "[RDM Manager] The player who RDM'd you is no longer available!"); // TODO: Translations
		return;
	}
	char sAttackerName[MAX_NAME_LENGTH];
	GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));
	char display[256];
	Format(display, sizeof(display), "You were RDM'd by %s!", sAttackerName);
	
	Handle menuHandle = CreateMenu(manageRDMHandle);
	SetMenuTitle(menuHandle, display);
	AddMenuItem(menuHandle, "Forgive", "Forgive");
	AddMenuItem(menuHandle, "Punish", "Punish");
	DisplayMenu(menuHandle, client, 10);
}

public int manageRDMHandle(Menu menu, MenuAction action, int client, int option)
{
	if (1 > client || client > MaxClients || !IsClientInGame(client))
		return;
		
	int iAttacker = g_iRDMAttacker[client];
	if (1 > iAttacker || iAttacker > MaxClients || !IsClientInGame(iAttacker))
		return;
		
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			GetMenuItem(menu, option, info, sizeof(info));
			if (StrEqual(info, "Forgive", false))
			{
				PrintToChat(client, "[RDM Manager] You have chosen to forgive %N for RDMing you!", iAttacker); // TODO: Translations
				PrintToChat(iAttacker, "[RDM Manager] %N has chosen to forgive you for RDMing them!", client); // TODO: Translations
				g_iRDMAttacker[client] = -1;
			}
			if (StrEqual(info, "Punish", false))
			{
				PrintToChatAll("[RDM Manager] %N has chosen to punish %N for RDMing them!", client, iAttacker); // TODO: Translations
				ServerCommand("sm_slay #%i 2", GetClientUserId(iAttacker));
				g_iRDMAttacker[client] = -1;
			}
		}
		case MenuAction_Cancel:
		{
			PrintToChat(client, "[RDM Manager] You have chosen to forgive %N for RDMing you!", iAttacker); // TODO: Translations
			PrintToChat(iAttacker, "[RDM Manager] %N has chosen to forgive you for RDMing them!", client); // TODO: Translations
			g_iRDMAttacker[client] = -1;
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			PrintToChat(client, "[RDM Manager] You have chosen to forgive %N for RDMing you!", iAttacker); // TODO: Translations
			PrintToChat(iAttacker, "[RDM Manager] %N has chosen to forgive you for RDMing them!", client); // TODO: Translations
			g_iRDMAttacker[client] = -1;
		}
	}
}

public Action Timer_RDMTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_hRDMTimer[client] = INVALID_HANDLE;
	manageRDM(client);
	return Plugin_Stop;
}

//Force Role
public Action Command_Role(int client, int args)
{
	if (args < 2 || args > 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_role <#userid|name> <role>");
		ReplyToCommand(client, "[SM] Roles: 1 - Innocent | 2 - Traitor | 3 - Detective");
		return Plugin_Handled;
	}
	char arg1[32];
	char arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = FindTarget(client, arg1);
	
	if (target == -1)
		return Plugin_Handled;

	if (!IsPlayerAlive(target))
	{
		ReplyToCommand(client, "[SM] This command can only be used to alive players!");
		return Plugin_Handled;
	}
	
	int role = StringToInt(arg2);
	if (role < 1 || role > 3)
	{
		ReplyToCommand(client, "[SM] Roles: 1 - Innocent | 2 - Traitor | 3 - Detective");
		return Plugin_Handled;
	}
	else if (role == 1)
	{
		g_iRole[target] = I;
		TeamInitialize(target);
		ClearIcon(target);
		CS_SetClientClanTag(target, "");
		ReplyToCommand(client, "[SM] %N is now an Innocent!", target);
		return Plugin_Handled;
	}
	else if (role == 2)
	{
		g_iRole[target] = T;
		TeamInitialize(target);
		ClearIcon(target);
		ApplyIcons();
		CS_SetClientClanTag(target, "");
		ReplyToCommand(client, "[SM] %N is now a Traitor!", target);
		return Plugin_Handled;
	}
	else if (role == 3)
	{
		g_iRole[target] = D;
		TeamInitialize(target);
		ClearIcon(target);
		ApplyIcons();
		ReplyToCommand(client, "[SM] %N is now a Detective!", target);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
	if (0 > client || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
		
	if (g_iRole[client] == U)
		ReplyToCommand(client, "[SM] You role has not been assigned yet!");
	else if (g_iRole[client] == I)
		ReplyToCommand(client, "[SM] You are an Innocent!");
	else if (g_iRole[client] == D)
		ReplyToCommand(client, "[SM] You are a Detective!");
	else if (g_iRole[client] == T)
		ReplyToCommand(client, "[SM] You are a Traitor!");
	
	return Plugin_Handled;
}

// Custom HUD
public Action Timer_5(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (!IsPlayerAlive(i))
			continue;

		g_iIcon[i] = CreateIcon(i);
		
		if (g_iRole[i] == D)
			ShowOverlayToClient(i, "darkness/ttt/overlayDetective");
		else if (g_iRole[i] == T)
			ShowOverlayToClient(i, "darkness/ttt/overlayTraitor");
		else if (g_iRole[i] == I)
			ShowOverlayToClient(i, "darkness/ttt/overlayInnocent");
		
		if (g_bHasActiveHealthStation[i] && g_iHealthStationCharges[i] < 9)
			g_iHealthStationCharges[i]++;
	}
}

public void OnEntityCreated(int entity, const char[] className)
{
	//TargetName: Destroy_Trigger
	if (StrEqual(className, "func_button"))
	{
		char targetName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (StrEqual(targetName, "Destroy_Trigger", false))
			SDKHook(entity, SDKHook_Use, OnUse);
	}
}

public Action OnUse(int entity, int activator, int caller, UseType type, float value)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator))
		return Plugin_Continue;
		
	if (g_bInactive)
		return Plugin_Handled;
		
	else
	{
		if (g_iRole[activator] == I || g_iRole[activator] == D || g_iRole[activator] == U)
		{
			ServerCommand("sm_slay #%i 2", GetClientUserId(activator));
			PrintToChatAll("%N triggered the falling building as a Non-Traitor.", activator);
		}
	}
	return Plugin_Continue;
}

//C4 MOD
public Action explodeC4(Handle timer, Handle pack)
{
	int clientUserId;
	int bombEnt;
	ResetPack(pack);
	clientUserId = ReadPackCell(pack);
	bombEnt = ReadPackCell(pack);
	int client = GetClientOfUserId(clientUserId);
	float explosionOrigin[3];
	GetEntPropVector(bombEnt, Prop_Send, "m_vecOrigin", explosionOrigin);
	if (IsClientValid(client))
	{
		g_bHasActiveBomb[client] = false;
		g_hExplosionTimer[client] = INVALID_HANDLE;
		g_bImmuneRDMManager[client] = true;
		PrintToChat(client, "[\x04T\x02T\x0BT\x01] Your bomb has been detonated!"); // TODO: Translations
	}
	else
		return Plugin_Stop;

	int explosionIndex = CreateEntityByName("env_explosion");
	int particleIndex = CreateEntityByName("info_particle_system");
	int shakeIndex = CreateEntityByName("env_shake");
	if (explosionIndex != -1 && particleIndex != -1 && shakeIndex != -1)
	{
		DispatchKeyValue(shakeIndex, "amplitude", "4"); 
		DispatchKeyValue(shakeIndex, "duration", "1"); 
		DispatchKeyValue(shakeIndex, "frequency", "2.5"); 
		DispatchKeyValue(shakeIndex, "radius", "5000");
		DispatchKeyValue(particleIndex, "effect_name", "explosion_c4_500");
		SetEntProp(explosionIndex, Prop_Data, "m_spawnflags", 16384);
		SetEntProp(explosionIndex, Prop_Data, "m_iRadiusOverride", 850);
		SetEntProp(explosionIndex, Prop_Data, "m_iMagnitude", 850);
		SetEntPropEnt(explosionIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchSpawn(particleIndex);
		DispatchSpawn(explosionIndex);
		DispatchSpawn(shakeIndex);
		ActivateEntity(shakeIndex);
		ActivateEntity(particleIndex);
		ActivateEntity(explosionIndex);
		TeleportEntity(particleIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(explosionIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		TeleportEntity(shakeIndex, explosionOrigin, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(bombEnt, "Kill");
		AcceptEntityInput(explosionIndex, "Explode");
		AcceptEntityInput(particleIndex, "Start");
		AcceptEntityInput(shakeIndex, "StartShake");
		AcceptEntityInput(explosionIndex, "Kill");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i))
				continue;
				
			float clientOrigin[3];
			GetEntPropVector(i, Prop_Data, "m_vecOrigin", clientOrigin);
			if (GetVectorDistance(clientOrigin, explosionOrigin) <= 275.0)
			{
				Handle killEvent = CreateEvent("player_death", true);
				SetEventInt(killEvent, "userid", GetClientUserId(i));
				SetEventInt(killEvent, "attacker", GetClientUserId(client));
				FireEvent(killEvent, false);
				ForcePlayerSuicide(i);
			}
		}
		for (int i = 1; i <= 2; i++)
			EmitAmbientSoundAny("training/firewerks_burst_02.wav", explosionOrigin, _, SNDLEVEL_RAIDSIREN);
			
		CreateTimer(2.0, UnImmune, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action UnImmune(Handle timer, any userId)
{
	int client = GetClientOfUserId(userId);
	if (IsClientValid(client))
		g_bImmuneRDMManager[client] = false;
	return Plugin_Stop;
}

public Action bombBeep(Handle timer, Handle pack)
{
	int bombEnt;
	int beeps;
	ResetPack(pack);
	bombEnt = ReadPackCell(pack);
	beeps = ReadPackCell(pack);
	if (!IsValidEntity(bombEnt))
		return Plugin_Stop;
		
	int owner = GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity");
	if (!IsClientValid(owner))
		return Plugin_Stop;
		
	float bombPos[3];
	GetEntPropVector(bombEnt, Prop_Data, "m_vecOrigin", bombPos);
	bool stopBeeping = false;
	if (beeps > 0)
	{
		EmitAmbientSoundAny("weapons/c4/c4_beep1.wav", bombPos);
		beeps--;
		stopBeeping = false;
	}
	else
		stopBeeping = true;
	if (stopBeeping)
		return Plugin_Stop;

	Handle bombBeep2;
	CreateDataTimer(1.0, bombBeep, bombBeep2);
	WritePackCell(bombBeep2, bombEnt);
	WritePackCell(bombBeep2, beeps);
	return Plugin_Stop;
}


stock void showPlantMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	Handle menuHandle = CreateMenu(plantBombMenu);
	SetMenuTitle(menuHandle, "Set the C4 Timer.");
	AddMenuItem(menuHandle, "10", "10 seconds");
	AddMenuItem(menuHandle, "20", "20 seconds");
	AddMenuItem(menuHandle, "30", "30 seconds");
	AddMenuItem(menuHandle, "40", "40 seconds");
	AddMenuItem(menuHandle, "50", "50 seconds");
	AddMenuItem(menuHandle, "60", "60 seconds");
	SetMenuPagination(menuHandle, 6);
	DisplayMenu(menuHandle, client, 10);
}

stock void showDefuseMenu(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	Handle menuHandle= CreateMenu(defuseBombMenu);
	SetMenuTitle(menuHandle, "Defuse the C4!");
	AddMenuItem(menuHandle, "1", "Wire 1");
	AddMenuItem(menuHandle, "2", "Wire 2");
	AddMenuItem(menuHandle, "3", "Wire 3");
	AddMenuItem(menuHandle, "4", "Wire 4");
	SetMenuPagination(menuHandle, 4);
	DisplayMenu(menuHandle, client, 10);
}

public int plantBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
		
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			GetMenuItem(menu, option, info, sizeof(info));
			if (StrEqual(info, "10"))
				plantBomb(client, 10.0);
			else if (StrEqual(info, "20"))
				plantBomb(client, 20.0);
			else if (StrEqual(info, "30"))
				plantBomb(client, 30.0);
			else if (StrEqual(info, "40"))
				plantBomb(client, 40.0);
			else if (StrEqual(info, "50"))
				plantBomb(client, 50.0);
			else if (StrEqual(info, "60"))
				plantBomb(client, 60.0);
			g_bHasC4[client] = false;
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			g_bHasActiveBomb[client] = false;
			int iEnt;
			
			while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
				if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") == client)
					AcceptEntityInput(iEnt, "Kill");
		}
		case MenuAction_Cancel:
		{
			g_bHasActiveBomb[client] = false;
			int iEnt;
			while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
				if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") == client)
					AcceptEntityInput(iEnt, "Kill");
		}
	}
}

public int defuseBombMenu(Menu menu, MenuAction action, int client, int option)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[100];
			int planter = g_iDefusePlayerIndex[client];	
			g_iDefusePlayerIndex[client] = -1;
			
			if (planter < 1 || planter > MaxClients || !IsClientInGame(planter))
			{
				g_iDefusePlayerIndex[client] = -1;
				return;
			}
			
			int wire;
			int correctWire;
			int planterBombIndex = findBomb(planter);
			float bombPos[3];
			GetEntPropVector(planterBombIndex, Prop_Data, "m_vecOrigin", bombPos);
			correctWire = g_iWire[planter];
			GetMenuItem(menu, option, info, sizeof(info));
			wire = StringToInt(info);
			if (wire == correctWire)
			{
				if (1 <= planter <= MaxClients && IsClientInGame(planter))
				{
					PrintToChat(client, "[\x04T\x02T\x0BT\x01] You have defused %N's bomb!", planter); // TODO: Translations
					PrintToChat(planter, "[\x04T\x02T\x0BT\x01] %N has defused your bomb!", client); // TODO: Translations
					EmitAmbientSoundAny("weapons/c4/c4_disarm.wav", bombPos);
					g_bHasActiveBomb[planter] = false;
					if (g_hExplosionTimer[planter] != INVALID_HANDLE)
					{
						KillTimer(g_hExplosionTimer[planter]);
						g_hExplosionTimer[planter] = INVALID_HANDLE;
					}
					SetEntProp(planterBombIndex, Prop_Send, "m_hOwnerEntity", -1);
				}
			}
			else
			{
				PrintToChat(client, "[\x04T\x02T\x0BT\x01] Failed to defuse!"); // TODO: Translations
				ForcePlayerSuicide(client);
				g_iDefusePlayerIndex[client] = -1;
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
			g_iDefusePlayerIndex[client] = -1;
		}
		case MenuAction_Cancel:
			g_iDefusePlayerIndex[client] = -1;
	}
}

stock float plantBomb(int client, float time)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
		
	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "[\x04T\x02T\x0BT\x01] You must be alive to plant a bomb!"); // TODO: Translations
		return;
	}
	
	PrintToChat(client, "[\x04T\x02T\x0BT\x01] Deploying a c4 that will explode in %.2f seconds.", time); // TODO: Translations
	int bombEnt;
	while ((bombEnt = FindEntityByClassname(bombEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(bombEnt, Prop_Send, "m_hOwnerEntity") == client)
		{
			if (bombEnt != -1)
			{
				Handle explosionPack;
				Handle beepPack;
				if (g_hExplosionTimer[client] != INVALID_HANDLE)
					KillTimer(g_hExplosionTimer[client]);
				g_hExplosionTimer[client] = CreateDataTimer(time, explodeC4, explosionPack);
				CreateDataTimer(1.0, bombBeep, beepPack);
				WritePackCell(explosionPack, GetClientUserId(client));
				WritePackCell(explosionPack, bombEnt);
				WritePackCell(beepPack, bombEnt);
				WritePackCell(beepPack, (time - 1));
				g_bHasActiveBomb[client] = true;
			}
			else
				PrintToChat(client, "[\x04T\x02T\x0BT\x01] Your bomb was not found!"); // TODO: Translations
		}
	}
	g_iWire[client] = Math_GetRandomInt(1, 4);
	PrintToChat(client, "[\x04T\x02T\x0BT\x01] The defuse wire is %i!", g_iWire[client]); // TODO: Translations
}

stock int findBomb(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return -1;
		
	int iEnt;
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics")) != -1)
	{
		if (GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity") == client)
			return iEnt;
	}
	return -1;
}

stock void resetPlayers()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		g_bKarma[i] = false;
		
		char sKarma[32];
		IntToString(g_iKarma[i], sKarma, sizeof(sKarma));
		SetClientCookie(i, g_hKarmaCookie, sKarma);
		
		if (g_hExplosionTimer[i] != INVALID_HANDLE)
		{
			KillTimer(g_hExplosionTimer[i]);
			g_hExplosionTimer[i] = INVALID_HANDLE;
		}
		g_bHasActiveBomb[i] = false;
	}
}

stock void listTraitors(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	
	PrintToChat(client, "[\x02TTT\x01] Your Traitor partners are:"); // TODO: Translations
	int iCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || client == i || g_iRole[i] != T)
			continue;
		PrintToChat(client, "[\x02TTT\x01] %N", i); // TODO: Translations
		iCount++;
	}
	
	if(iCount == 0)
		PrintToChat(client, "[\x02TTT\x01] You have no partner."); // TODO: Translations
}

stock void nameCheck(int client, char name[MAX_NAME_LENGTH])
{
	for (int i = 0; i < sizeof(g_sDetectiveNames); i++)
		if (StrContains(name, g_sDetectiveNames[i]) != -1)
			KickClient(client, "Remove the word Detective from your name.");
}

stock void healthStation_cleanUp()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		g_iHealthStationCharges[i] = 0;
		g_bHasActiveHealthStation[i] = false;
		g_bOnHealingCoolDown[i] = false;
		
		if (g_hRemoveCoolDownTimer[i] != INVALID_HANDLE)
		{
			KillTimer(g_hRemoveCoolDownTimer[i]);
			g_hRemoveCoolDownTimer[i] = INVALID_HANDLE;
		}
	}
}

public Action removeCoolDown(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_bOnHealingCoolDown[client] = false;
	g_hRemoveCoolDownTimer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

stock void spawnHealthStation(int client)
{
	if (!IsPlayerAlive(client))
		return;
		
	int healthStationIndex = CreateEntityByName("prop_physics_multiplayer");
	if (healthStationIndex != -1)
	{
		float clientPos[3];
		GetClientAbsOrigin(client, clientPos);
		SetEntProp(healthStationIndex, Prop_Send, "m_hOwnerEntity", client);
		DispatchKeyValue(healthStationIndex, "model", "models/props/cs_office/microwave.mdl");
		DispatchSpawn(healthStationIndex);
		SDKHook(healthStationIndex, SDKHook_OnTakeDamageAlive, OnTakeDamageHealthStation);
		TeleportEntity(healthStationIndex, clientPos, NULL_VECTOR, NULL_VECTOR);
		g_iHealthStationHealth[client] = 10;
		g_bHasActiveHealthStation[client] = true;
		g_iHealthStationCharges[client] = 10;
		PrintToChat(client, "[\x04T\x02T\x0BT\x01] Health Station deployed. Stand near it to gain HP!"); // TODO: Translations
	}
}

public Action OnTakeDamageHealthStation(int stationIndex, int &iAttacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidEntity(stationIndex) || stationIndex == INVALID_ENT_REFERENCE || stationIndex <= MaxClients || iAttacker < 1 || iAttacker > MaxClients || !IsClientInGame(iAttacker))
		return Plugin_Continue;
	
	int owner = GetEntProp(stationIndex, Prop_Send, "m_hOwnerEntity");
	if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
		return Plugin_Continue;
		
	g_iHealthStationHealth[owner]--;
	
	if (g_iHealthStationHealth[owner] <= 0)
	{
		AcceptEntityInput(stationIndex, "Kill");
		g_bHasActiveHealthStation[owner] = false;
	}
	return Plugin_Continue;
}

public Action healthStationDistanceCheck(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (!IsPlayerAlive(i))
			continue;
		
		checkDistanceFromHealthStation(i);
	}
	return Plugin_Continue;
}

stock void checkDistanceFromHealthStation(int client) {
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	float clientPos[3], stationPos[3]; 
	int curHealth, newHealth, iEnt;
	char sModelName[PLATFORM_MAX_PATH];
	while ((iEnt = FindEntityByClassname(iEnt, "prop_physics_multiplayer")) != -1)
	{
		int owner = GetEntProp(iEnt, Prop_Send, "m_hOwnerEntity");
		if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
			continue;
		
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if (StrContains(sModelName, "microwave") == -1)
			continue;
		
		GetClientEyePosition(client, clientPos);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", stationPos);
		
		if (GetVectorDistance(clientPos, stationPos) > 200.0)
			continue;
		
		if (g_bOnHealingCoolDown[client]) continue;
		curHealth = GetClientHealth(client);
		
		if (curHealth >= 125)
			continue;
		
		if (g_iHealthStationCharges[owner] > 0)
		{
			newHealth = (curHealth + 15);
			if (newHealth >= 125)
				SetEntityHealth(client, 125);
			else
				SetEntityHealth(client, newHealth);

			PrintToChat(client, "[\x04T\x02T\x0BT\x01] Healing from %N's Health Station!", owner); // TODO: Translations
			EmitSoundToClientAny(client, "resource/warning.wav");
			g_iHealthStationCharges[owner]--;
			g_bOnHealingCoolDown[client] = true;
			g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			PrintToChat(client, "[\x04T\x02T\x0BT\x01] This Health Station is out of charges! Wait for it to recharge!"); // TODO: Translations
			g_bOnHealingCoolDown[client] = true;
			g_hRemoveCoolDownTimer[client] = CreateTimer(1.0, removeCoolDown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnWeaponPostSwitch(int client, int weapon)
{
	char weaponName[64];
	GetClientWeapon(client, weaponName, sizeof(weaponName));
	if (StrContains(weaponName, "silence") != -1)
		g_bHoldingSilencedWep[client] = true;
	else
		g_bHoldingSilencedWep[client] = false;
}

public Action Command_KarmaReset(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		g_iKarma[i] = 100;
		char result[32];
		IntToString(g_iKarma[i], result, sizeof(result));
		SetClientCookie(i, g_hKarmaCookie, result);
	}
	return Plugin_Handled;
}

// Thanks SMLib ( https://github.com/bcserv/smlib/blob/master/scripting/include/smlib/math.inc#L149 )
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	
	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock void CheckTeams()
{
	int iT = 0;
	int iD = 0;
	int iI = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && IsPlayerAlive(i))
		{
			if(g_iRole[i] == D)
				iD++;
			else if(g_iRole[i] == T)
				iT++;
			else if(g_iRole[i] == I)
				iI++;
		}
	}
	
	if(iD == 0 && iI == 0)
		CS_TerminateRound(7.0, CSRoundEnd_TerroristWin);
	else if(iT == 0)
		CS_TerminateRound(7.0, CSRoundEnd_CTWin);
}