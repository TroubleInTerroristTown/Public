#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Spec Menu"

#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

ConVar g_cMenuTime = null;
ConVar g_cAutoOpen = null;

bool g_bMutedAlive[MAXPLAYERS + 1] =  { false, ... };
bool g_bMutedDead[MAXPLAYERS + 1] =  { false, ... };

ArrayList g_aAlivePlayers = null;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
	TTT_IsGameCSGO();

	g_aAlivePlayers = new ArrayList(1);

	StartConfig("spec_menu");
	CreateConVar("ttt2_spec_menu_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cAutoOpen = AutoExecConfig_CreateConVar("specmenu_auto_open", "1", "Show spec menu automatically after death?", _, true, 0.0, true, 1.0);
	g_cMenuTime = AutoExecConfig_CreateConVar("specmenu_menu_time", "0", "Time (in seconds) to autoclose the menu (0 - FOREVER)");
	EndConfig();

	LoadTranslations("ttt.phrases");

	RegConsoleCmd("sm_specmenu", Command_SpecMenu);
	RegConsoleCmd("sm_spm", Command_SpecMenu);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	g_bMutedAlive[client] = false;
	g_bMutedDead[client] = false;

	if (TTT_IsClientValid(client) && !IsFakeClient(client))
	{
		if (g_aAlivePlayers.FindValue(client) == -1)
		{
			g_aAlivePlayers.Push(client);
		}
	}
}

public void OnClientDisconnect(int client)
{
	int iIndex = g_aAlivePlayers.FindValue(client);
	if (iIndex != -1)
	{
		g_aAlivePlayers.Erase(iIndex);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client) && !IsFakeClient(client))
	{
		LoopValidClients(i)
		{
			if (g_bMutedDead[i])
			{
				SetListenOverride(i, client, Listen_No);
			}
		}
		int iIndex = g_aAlivePlayers.FindValue(client);
		if (iIndex != -1)
		{
			g_aAlivePlayers.Erase(iIndex);
		}

		if (g_cAutoOpen.BoolValue)
		{
			ShowSpecMenu(client);
		}
	}
}

public Action Command_SpecMenu(int client, int args)
{
	if (!TTT_IsClientValid(client) && !IsFakeClient(client))
	{
		return Plugin_Handled;
	}

	ShowSpecMenu(client);

	return Plugin_Continue;
}

void ShowSpecMenu(int client)
{
	Menu menu = new Menu(Menu_MainMenu);
	menu.SetTitle("%T", "SpecMenu: Title", client);

	if (TTT_IsClientValid(GetObservTarget(client)) && !IsFakeClient(client))
	{
		char sPlayer[128];
		Format(sPlayer, sizeof(sPlayer), "%T\n--------------------", "SpecMenu: Player", client, GetObservTarget(client));
		menu.AddItem("player", sPlayer, ITEMDRAW_DISABLED);
	}

	char sNext[32], sPrev[32];
	Format(sNext, sizeof(sNext), "%T", "SpecMenu: Next", client);
	Format(sPrev, sizeof(sPrev), "%T\n--------------------", "SpecMenu: Prev", client);

	menu.AddItem("next", sNext);
	menu.AddItem("prev", sPrev);

	char sItem[32];
	if (g_bMutedAlive[client])
	{
		Format(sItem, sizeof(sItem), "%T", "SpecMenu: Unmute Alive", client);
	}
	else
	{
		Format(sItem, sizeof(sItem), "%T", "SpecMenu: Mute Alive", client);
	}

	menu.AddItem("alive", sItem);

	if (g_bMutedDead[client])
	{
		Format(sItem, sizeof(sItem), "%T", "SpecMenu: Unmute Dead", client);
	}
	else
	{
		Format(sItem, sizeof(sItem), "%T", "SpecMenu: Mute Dead", client);
	}

	menu.AddItem("dead", sItem);

	menu.ExitButton = true;
	menu.Display(client, g_cMenuTime.IntValue);
}

public int Menu_MainMenu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		if (IsPlayerAlive(client))
			return 0;

		if (!IsPlayerAlive(client) || IsClientObserver(client))
		{
			char sParam[32];
			GetMenuItem(menu, param, sParam, sizeof(sParam));

			if (StrEqual(sParam, "next", false))
			{
				if (g_aAlivePlayers.Length > 0)
				{
					int iTarget = GetObservTarget(client);
					int iIndex = g_aAlivePlayers.FindValue(iTarget) + 1;

					if (iIndex >= g_aAlivePlayers.Length)
					{
						iIndex = 0;
					}

					int iNextTarget = g_aAlivePlayers.Get(iIndex);
					if (!TTT_IsClientValid(iNextTarget) && !IsFakeClient(client))
					{
						g_aAlivePlayers.Erase(iIndex);
						FakeClientCommand(client, "spec_next");
					}
					else
					{
						int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

						if (iMode != SPECMODE_FIRSTPERSON && iMode != SPECMODE_3RDPERSON)
						{
							SetEntProp(client, Prop_Send, "m_iObserverMode", SPECMODE_FIRSTPERSON);
						}

						SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iNextTarget);
					}
				}
				else
				{
					FakeClientCommand(client, "spec_next");
				}

				ShowSpecMenu(client);

				return 0;
			}
			else if (StrEqual(sParam, "prev", false))
			{
				if (g_aAlivePlayers.Length > 0)
				{
					int iTarget = GetObservTarget(client);
					int iIndex = g_aAlivePlayers.FindValue(iTarget) - 1;

					if (iIndex < 0)
					{
						iIndex = g_aAlivePlayers.Length -1;
					}

					int iNextTarget = g_aAlivePlayers.Get(iIndex);
					if (!TTT_IsClientValid(iNextTarget) && !IsFakeClient(client))
					{
						g_aAlivePlayers.Erase(iIndex);
						FakeClientCommand(client, "spec_next");
					}
					else
					{
						int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

						if (iMode != SPECMODE_FIRSTPERSON && iMode != SPECMODE_3RDPERSON)
						{
							SetEntProp(client, Prop_Send, "m_iObserverMode", SPECMODE_FIRSTPERSON);
						}

						SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iNextTarget);
					}
				}
				else
				{
					FakeClientCommand(client, "spec_next");
				}

				ShowSpecMenu(client);

				return 0;
			}
			else if (StrEqual(sParam, "alive", false))
			{
				if (g_bMutedAlive[client])
				{
					LoopValidClients(i)
					{
						if (IsPlayerAlive(i))
						{
							SetListenOverride(client, i, Listen_Yes);
						}
					}

					g_bMutedAlive[client] = false;
				}
				else
				{
					LoopValidClients(i)
					{
						if (IsPlayerAlive(i))
						{
							SetListenOverride(client, i, Listen_No);
						}
					}

					g_bMutedAlive[client] = true;
				}

				ShowSpecMenu(client);
			}
			else if (StrEqual(sParam, "dead", false))
			{
				if (g_bMutedDead[client])
				{
					LoopValidClients(i)
					{
						if (!IsPlayerAlive(i))
						{
							SetListenOverride(client, i, Listen_Yes);
						}
					}

					g_bMutedDead[client] = false;
				}
				else
				{
					LoopValidClients(i)
					{
						if (!IsPlayerAlive(i))
						{
							SetListenOverride(client, i, Listen_No);
						}
					}

					g_bMutedDead[client] = true;
				}

				ShowSpecMenu(client);
			}
		}

		return 0;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

int GetObservTarget(int client)
{
	if (!IsPlayerAlive(client) || IsClientObserver(client))
	{
		int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if (iMode == SPECMODE_FIRSTPERSON || iMode == SPECMODE_3RDPERSON)
		{
			int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if (target < 1 || !TTT_IsClientValid(client))
			{
				target = 0;
			}

			return target;
		}
	}
	return 0;
}
