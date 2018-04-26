/*
* Request Core Plugin turret_core 
* https://forums.alliedmods.net/showpost.php?p=2589375&postcount=2
*/
#pragma semicolon 1
#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#undef REQUIRE_PLUGIN
#include <turret_core>
#define Turret_Core_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SetTurretCanAttackClient") == FeatureStatus_Available)

#pragma newdecls required


#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - turret"
#define SHORT_NAME "turret"

bool g_bHasTurret[MAXPLAYERS+1];

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;

ConVar g_c_sd_turret_checkteam = null;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "bbs.93x.net",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	//TTT
	LoadTranslations("ttt.phrases");
	
	TTT_StartConfig("turret");
	CreateConVar("ttt2_turret_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("turret_name", "turret", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("turret_price", "9000", "The amount of credits turret costs as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("turret_sort_prio", "0", "The sorting priority of the turret in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("tracer_traitor", "0", "Should turret discountable?", _, true, 0.0, true, 1.0);
	HookEvent("player_spawn", Event_PlayerSpawn);
	

	TTT_EndConfig();
	//
}
public void OnAllPluginsLoaded()
{
	g_c_sd_turret_checkteam = FindConVar("sd_turret_checkteam");
	
	if(g_c_sd_turret_checkteam != null){
			g_c_sd_turret_checkteam.SetInt(3);
			g_c_sd_turret_checkteam.AddChangeHook(ConVarChanged);
		
	}
}


public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_c_sd_turret_checkteam)
		g_c_sd_turret_checkteam.SetInt(3);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		g_bHasTurret[client] = false;
	}
}


public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{
		if (StrEqual(itemshort, SHORT_NAME, false))
		{
			int role = TTT_GetClientRole(client);
			
			if (role != TTT_TEAM_TRAITOR || g_bHasTurret[client])
			{
				return Plugin_Stop;
			}
			
			
			LoopValidClients(client_index){
				int irole = TTT_GetClientRole(client_index);
				if(irole == TTT_TEAM_DETECTIVE || irole == TTT_TEAM_INNOCENT)
					SetTurretCanAttackClient(client_index,true);
				else SetTurretCanAttackClient(client_index,false);
			}
			
			CreateTurret(client);
			g_bHasTurret[client] = true;
		}
	}
	return Plugin_Continue;
}

public void Turret_OnTurretDead(int VictimTurretClientIndex,int AttackerClientIndex)
{
	TTT_AddClientCredits(AttackerClientIndex, 800);
	g_bHasTurret[VictimTurretClientIndex] = false;
}
	
public void TTT_OnClientGetRole(int client, int role)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{	
		if(role == TTT_TEAM_DETECTIVE || role == TTT_TEAM_INNOCENT)
			SetTurretCanAttackClient(client,true);
		else SetTurretCanAttackClient(client,false);
	}
}

public void OnConfigsExecuted()
{
	RegisterItem();
}

public Action TTT_OnItemsReset()
{
	RegisterItem();
}


void RegisterItem()
{
	if(!Turret_Core_AVAILABLE()) {
		LogError("can't find plugin turret_core.smx or turret_core.smx not running!");
		return;
	}

	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
}

