#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <ttt_shop>

#include <turret_core>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Turret"
#define SHORT_NAME "turret"

bool g_bHasTurret[MAXPLAYERS+1];

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cDiscount = null;
ConVar g_cKillTurretCount = null;

ConVar g_cCheckTeam = null;


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR ... " & bbs.93x.net",
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("ttt.phrases");
	
	TTT_StartConfig("turret");
	CreateConVar("ttt2_turret_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("turret_name", "Turret", "The name of this in Shop");
	g_cPrice = AutoExecConfig_CreateConVar("turret_price", "9000", "The amount of credits turret costs as traitor. 0 to disable.");
	g_cPrio = AutoExecConfig_CreateConVar("turret_sort_prio", "0", "The sorting priority of the turret in the shop menu.");
	g_cDiscount = AutoExecConfig_CreateConVar("turret_traitor", "0", "Should turret discountable?", _, true, 0.0, true, 1.0);
	g_cKillTurretCount = AutoExecConfig_CreateConVar("turret_kill_cash_amount", "800", "Kill turret credits ?");
	HookEvent("player_spawn", Event_PlayerSpawn);
	

	TTT_EndConfig();
}

public void OnAllPluginsLoaded()
{
	g_cCheckTeam = FindConVar("sd_turret_checkteam");
	
	if(g_cCheckTeam != null)
	{
        g_cCheckTeam.SetInt(3);
        g_cCheckTeam.AddChangeHook(ConVarChanged);
	}

	RegisterItem();
}

public void TTT_OnItemsReset()
{
	RegisterItem();
}

void RegisterItem()
{
	if(!LibraryExists("turret_core"))
    {
		TTT_RemoveCustomItem(SHORT_NAME);
		SetFailState("Can't find turret_core.smx! This file will be provided with TTT.");
		return;
	}

	char sName[MAX_ITEM_LENGTH];
	g_cLongName.GetString(sName, sizeof(sName));
	
	TTT_RegisterCustomItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cDiscount.BoolValue);
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
			
			
			LoopValidClients(client_index)
            {
				int irole = TTT_GetClientRole(client_index);
				if(irole == TTT_TEAM_DETECTIVE || irole == TTT_TEAM_INNOCENT)
                {
					SetTurretCanAttackClient(client_index,true);
                }
				else
                {
                    SetTurretCanAttackClient(client_index,false);
                }
			}
			
			CreateTurret(client);
			g_bHasTurret[client] = true;
		}
	}
	return Plugin_Continue;
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(convar == g_cCheckTeam)
    {
		g_cCheckTeam.SetInt(3);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TTT_IsClientValid(client))
	{
		g_bHasTurret[client] = false;
	}
}

public void Turret_OnTurretDead(int VictimTurretClientIndex,int AttackerClientIndex)
{
	TTT_AddClientCredits(AttackerClientIndex, g_cKillTurretCount.IntValue);
	g_bHasTurret[VictimTurretClientIndex] = false;
}
	
public void TTT_OnClientGetRole(int client, int role)
{
	if (TTT_IsClientValid(client) && IsPlayerAlive(client))
	{	
		if(role == TTT_TEAM_DETECTIVE || role == TTT_TEAM_INNOCENT)
        {
			SetTurretCanAttackClient(client,true);
        }
		else
        {
            SetTurretCanAttackClient(client,false);
        }
	}
}
