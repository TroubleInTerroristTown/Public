#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <multicolors>
#include <clientprefs>
#include <ttt_shop>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Shop"

#pragma newdecls required

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = TTT_PLUGIN_AUTHOR,
	description = TTT_PLUGIN_DESCRIPTION,
	version = TTT_PLUGIN_VERSION,
	url = TTT_PLUGIN_URL
};

ArrayList g_aCustomItems;

ConVar g_cCredits = null;
ConVar g_cBuyCmd = null;
ConVar g_cShowCmd = null;
ConVar g_cSortItems = null;
ConVar g_cShowEarnCreditsMessage = null;
ConVar g_cShowLoseCreditsMessage = null;
ConVar g_cResetCreditsEachRound = null;
ConVar g_cCreditsTimer = null;
ConVar g_cCreditsMessage = null;
ConVar g_cReopenMenu = null;
ConVar g_cCreditsII = null;
ConVar g_cCreditsIT = null;
ConVar g_cCreditsID = null;
ConVar g_cCreditsTI = null;
ConVar g_cCreditsTT = null;
ConVar g_cCreditsTD = null;
ConVar g_cCreditsDI = null;
ConVar g_cCreditsDT = null;
ConVar g_cCreditsDD = null;
ConVar g_cTraitorloseAliveNonTraitors = null;
ConVar g_cTraitorloseDeadNonTraitors = null;
ConVar g_cTraitorwinAliveTraitors = null;
ConVar g_cTraitorwinDeadTraitors = null;
ConVar g_cCreditsFoundBody = null;
ConVar g_cMessageTypCredits = null;
ConVar g_cStartCredits = null;
ConVar g_cCreditsMin = null;
ConVar g_cCreditsMax = null;
ConVar g_cCreditsInterval = null;

char g_sPluginTag[64];

Handle g_hOnItemPurchased = null;
Handle g_hOnItemPurchase = null;
Handle g_hOnCreditsGiven_Pre = null;
Handle g_hOnCreditsGiven = null;
Handle g_hReopenCookie = null;

Handle g_hCreditsTimer[MAXPLAYERS + 1] =  { null, ... };

int g_iCredits[MAXPLAYERS + 1] =  { 0, ... };

bool g_bReopen[MAXPLAYERS + 1] =  { true, ... };


char g_sShopCMDs[][] =  {
	"menu",
	"shop"
};

enum Item
{
	String:Long[64],
	String:Short[16],
	Price,
	Role,
	Sort
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnItemPurchased = CreateGlobalForward("TTT_OnItemPurchased", ET_Hook, Param_Cell, Param_String, Param_Cell);
	g_hOnItemPurchase = CreateGlobalForward("TTT_OnItemPurchase", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_String);

	g_hOnCreditsGiven_Pre = CreateGlobalForward("TTT_OnCreditsChanged_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_hOnCreditsGiven = CreateGlobalForward("TTT_OnCreditsChanged", ET_Ignore, Param_Cell, Param_Cell);

	CreateNative("TTT_RegisterCustomItem", Native_RegisterCustomItem);
	CreateNative("TTT_GetCustomItemPrice", Native_GetCustomItemPrice);
	CreateNative("TTT_GetCustomItemRole", Native_GetCustomItemRole);

	CreateNative("TTT_GetClientCredits", Native_GetClientCredits);
	CreateNative("TTT_SetClientCredits", Native_SetClientCredits);
	CreateNative("TTT_AddClientCredits", Native_AddClientCredits);

	RegPluginLibrary("ttt_shop");

	return APLRes_Success;
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "sm_%s", g_sShopCMDs[i]);
		RegConsoleCmd(sBuffer, Command_Shop);
	}

	RegConsoleCmd("sm_reopenshop", Command_ReopenShop);
	RegConsoleCmd("sm_roshop", Command_ReopenShop);
	RegConsoleCmd("sm_reshop", Command_ReopenShop);
	RegConsoleCmd("sm_rshop", Command_ReopenShop);

	g_aCustomItems = new ArrayList(83);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	RegAdminCmd("sm_setcredits", Command_SetCredits, ADMFLAG_ROOT);

	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);

	HookEvent("player_death", Event_PlayerDeath);

	StartConfig("shop");
	CreateConVar("ttt2_shop_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cSortItems = AutoExecConfig_CreateConVar("ttt_sort_items", "1", "Sort shop items? 0 = Disabled. 1 = Enabled (default).", _, true, 0.0, true, 1.0);
	g_cCreditsII = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_innocent_subtract", "1500", "The amount of credits an innocent will lose for killing an innocent.");
	g_cCreditsIT = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_traitor_add", "3000", "The amount of credits an innocent will recieve when killing a traitor.");
	g_cCreditsID = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_detective_subtract", "4200", "The amount of credits an innocent will lose for killing a detective.");
	g_cCreditsTI = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_innocent_add", "600", "The amount of credits a traitor will recieve for killing an innocent.");
	g_cCreditsTT = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_traitor_subtract", "3000", "The amount of credits a traitor will lose for killing a traitor.");
	g_cCreditsTD = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_detective_add", "4200", "The amount of credits a traitor will recieve for killing a detective.");
	g_cCreditsDI = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_innocent_subtract", "300", "The amount of credits a detective will lose for killing an innocent.");
	g_cCreditsDT = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_traitor_add", "2100", "The amount of credits a detective will recieve for killing a traitor.");
	g_cCreditsDD = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_detective_subtract", "300", "The amount of credits a detective will lose for killing a detective.");

	g_cTraitorloseAliveNonTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorlose_alive_nontraitors", "4800", "The amount of credits an innocent or detective will recieve for winning the round if they survived.");
	g_cTraitorloseDeadNonTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorlose_dead_nontraitors", "1200", "The amount of credits an innocent or detective will recieve for winning the round if they died.");
	g_cTraitorwinAliveTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorwin_alive_traitors", "4800", "The amount of credits a traitor will recieve for winning the round if they survived.");
	g_cTraitorwinDeadTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorwin_dead_traitors", "1200", "The amount of credits a traitor will recieve for winning the round if they died.");
	g_cCreditsFoundBody = AutoExecConfig_CreateConVar("ttt_credits_found_body_add", "1200", "The amount of credits an innocent or detective will recieve for discovering a new dead body.");

	g_cShowEarnCreditsMessage = AutoExecConfig_CreateConVar("ttt_show_message_earn_credits", "1", "Display a message showing how many credits you earned. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
	g_cShowLoseCreditsMessage = AutoExecConfig_CreateConVar("ttt_show_message_lose_credits", "1", "Display a message showing how many credits you lost. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
	g_cMessageTypCredits = AutoExecConfig_CreateConVar("ttt_message_typ_credits", "1", "The credit message type. 1 = Hint Text, 2 = Chat Message", _, true, 1.0, true, 2.0);

	g_cStartCredits = AutoExecConfig_CreateConVar("ttt_start_credits", "800", "The amount of credits players will recieve when they join for the first time.");
	g_cResetCreditsEachRound = AutoExecConfig_CreateConVar("ttt_credits_reset_each_round", "0", "Reset credits for all players each round?. 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);

	g_cCreditsTimer = AutoExecConfig_CreateConVar("ttt_credits_timer", "1", "Players earn every minute (configurable) credits", _, true, 0.0, true, 1.0);
	g_cCreditsMessage = AutoExecConfig_CreateConVar("ttt_credits_show_message", "1", "Show a message when player earn credits (ttt_credits_timer must be true)", _, true, 0.0, true, 1.0);
	g_cCreditsInterval = AutoExecConfig_CreateConVar("ttt_credits_interval", "60.0", "Interval for earning credits - TIME IN SECONDS - MINIMUM: 60.0 - (ttt_credits_timer must be true)", _, true, 60.0);
	g_cCreditsMin = AutoExecConfig_CreateConVar("ttt_credits_amount_min", "30", "How much credits the player can get (min)");
	g_cCreditsMax = AutoExecConfig_CreateConVar("ttt_credits_amount_max", "90", "How much credits the player can get (max)");

	g_cReopenMenu = AutoExecConfig_CreateConVar("ttt_menu_reopen", "1", "Reopen the shop menu, after buying something.", _, true, 0.0, true, 1.0);

	g_cCredits = AutoExecConfig_CreateConVar("ttt_credits_command", "credits", "The command to show the credits");
	g_cBuyCmd = AutoExecConfig_CreateConVar("ttt_shop_buy_command", "buyitem", "The command to buy a shop item instantly");
	g_cShowCmd = AutoExecConfig_CreateConVar("ttt_shop_show_command", "showitems", "The command to show the shortname of the shopitems (to use for the buycommand)");
	EndConfig();

	LoadTranslations("common.phrases");
	LoadTranslations("ttt.phrases");

	g_hReopenCookie = RegClientCookie("ttt_reopen_shop", "Cookie to reopen shop menu", CookieAccess_Private);

	for (int i = 0; i <= MaxClients; i++)
	{
		if (TTT_IsClientValid(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnConfigsExecuted()
{
	// Get some values from ttt.config
	ConVar cCVar = FindConVar("ttt_plugin_tag");
	cCVar.GetString(g_sPluginTag, sizeof(g_sPluginTag));
	
	char sBuffer[32];
	g_cCredits.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
	RegConsoleCmd(sBuffer, Command_Credits);

	g_cBuyCmd.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
	RegConsoleCmd(sBuffer, Command_Buy);

	g_cShowCmd.GetString(sBuffer, sizeof(sBuffer));
	Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);
	RegConsoleCmd(sBuffer, Command_ShowItems);
}

public void OnClientCookiesCached(int client)
{
	if (AreClientCookiesCached(client))
	{
		char sBuffer[4];
		GetClientCookie(client, g_hReopenCookie, sBuffer, sizeof(sBuffer));
		g_bReopen[client] = view_as<bool>(StringToInt(sBuffer));
	}
	else
	{
		char sBuffer[4];
		IntToString(view_as<int>(true), sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_hReopenCookie, sBuffer);
	}
}

public Action Command_Buy(int client, int args)
{
	if (!TTT_IsClientValid(client) || args < 1)
	{
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "YouAreDead", client);
		return Plugin_Handled;
	}

	char sItem[16];
	GetCmdArg(1, sItem, sizeof(sItem));

	if (strlen(sItem) > 0)
	{
		ClientBuyItem(client, sItem);
	}

	return Plugin_Handled;
}

public Action Command_ShowItems(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	int temp_item[Item];

	PrintToConsole(client, "ShortName - LongName, Team", temp_item[Short], temp_item[Long], temp_item[Role]);

	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if (strlen(temp_item[Short]) > 1)
		{
			PrintToConsole(client, "%s - %s, %i", temp_item[Short], temp_item[Long], temp_item[Role]);
		}
	}
	return Plugin_Handled;
}

public Action Command_Shop(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, g_sPluginTag, "YouAreDead", client);
		return Plugin_Handled;
	}

	int team = TTT_GetClientRole(client);
	if (team != TTT_TEAM_UNASSIGNED)
	{
		Handle menu = CreateMenu(Menu_ShopHandler);
		SetMenuTitle(menu, "%T", "TTT Shop", client, TTT_GetClientCredits(client));

		char display[128];
		int temp_item[Item];

		for (int i = 0; i < g_aCustomItems.Length; i++)
		{
			g_aCustomItems.GetArray(i, temp_item[0]);
			if (strlen(temp_item[Short]) > 1)
			{
				if ((temp_item[Role] == 1) || (temp_item[Role] == team))
				{
					Format(display, sizeof(display), "%s - %d", temp_item[Long], temp_item[Price]);
					AddMenuItem(menu, temp_item[Short], display);
				}
			}
		}

		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 15);
	}
	else
	{
		CPrintToChat(client, "%s %T", g_sPluginTag, "Please wait till your team is assigned", client);
	}

	return Plugin_Handled;

}

public Action Command_ReopenShop(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (g_bReopen[client])
	{
		g_bReopen[client] = false;

		CPrintToChat(client, "%s %T", g_sPluginTag, "Reopen Shop deactivated", client);

		char sBuffer[4];
		IntToString(view_as<int>(g_bReopen[client]), sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_hReopenCookie, sBuffer);
	}
	else
	{
		g_bReopen[client] = true;

		CPrintToChat(client, "%s %T", g_sPluginTag, "Reopen Shop activated", client);

		char sBuffer[4];
		IntToString(view_as<int>(g_bReopen[client]), sBuffer, sizeof(sBuffer));
		SetClientCookie(client, g_hReopenCookie, sBuffer);
	}

	return Plugin_Continue;
}

public int Menu_ShopHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		if (!IsPlayerAlive(client))
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "YouAreDead", client);
			return;
		}

		char info[32];
		GetMenuItem(menu, itemNum, info, sizeof(info));

		ClientBuyItem(client, info);

		if (g_cReopenMenu.BoolValue && g_bReopen[client])
		{
			Command_Shop(client, 0);
		}
	}

	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

bool ClientBuyItem(int client, char[] item)
{
	int temp_item[Item];
	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if ((strlen(temp_item[Short]) > 0) && (strcmp(item, temp_item[Short]) == 0))
		{
			int price = temp_item[Price];
			int count = true;

			Action result = Plugin_Continue;
			Call_StartForward(g_hOnItemPurchase);
			Call_PushCell(client);
			Call_PushCell(price);
			Call_PushCell(count);
			Call_PushString(temp_item[Short]);
			Call_Finish(result);

			if (result == Plugin_Stop || result == Plugin_Handled)
			{
				return false;
			}
			
			ConVar cCVar = FindConVar("ttt_show_debug_messages");
			if (cCVar.BoolValue && temp_item[Price] != price)
			{
				if (CheckCommandAccess(client, "ttt_root", ADMFLAG_ROOT, true))
				{
					PrintToChat(client, "Item: %s Price: %d New Price: %d", temp_item[Long], temp_item[Price], price);
				}
			}

			if ((TTT_GetClientCredits(client) >= price) && ((temp_item[Role] == 1) || (TTT_GetClientRole(client) == temp_item[Role])))
			{
				Action res = Plugin_Continue;
				Call_StartForward(g_hOnItemPurchased);
				Call_PushCell(client);
				Call_PushString(temp_item[Short]);
				Call_PushCell(count);
				Call_Finish(res);

				if (res < Plugin_Stop)
				{
					TTT_SetClientCredits(client, (TTT_GetClientCredits(client) - price));
					CPrintToChat(client, "%s %T", g_sPluginTag, "Item bought! (NEW)", client, TTT_GetClientCredits(client), temp_item[Long], price);
					return true;
				}
			}
			else
			{
				CPrintToChat(client, "%s %T", g_sPluginTag, "You don't have enough money", client);
				return false;
			}
		}
	}
	return false;
}


public Action Command_Say(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));

	StripQuotes(sText);

	if (sText[0] == '@')
	{
		return Plugin_Continue;
	}

	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "!%s", g_sShopCMDs[i]);

		if (StrEqual(sText, sBuffer, false))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public int Native_RegisterCustomItem(Handle plugin, int numParams)
{
	if (numParams < 4)
	{
		return false;
	}

	char temp_short[16];
	char temp_long[64];
	GetNativeString(1, temp_short, sizeof(temp_short));
	GetNativeString(2, temp_long, sizeof(temp_long));

	int temp_price = GetNativeCell(3);
	int temp_role = GetNativeCell(4);
	int temp_sort = GetNativeCell(5);
	int temp_item[Item];

	if ((strlen(temp_short) < 1) || (strlen(temp_long) < 1) || (temp_price <= 0))
	{
		return false;
	}

	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if (StrEqual(temp_item[Short], temp_short, false))
		{
			return false;
		}
	}

	Format(temp_item[Short], sizeof(temp_short), "%s", temp_short);
	Format(temp_item[Long], sizeof(temp_long), "%s", temp_long);
	temp_item[Price] = temp_price;
	temp_item[Role] = temp_role;
	temp_item[Sort] = temp_sort;
	g_aCustomItems.PushArray(temp_item[0]);


	if (g_cSortItems.IntValue)
	{
		SortADTArrayCustom(g_aCustomItems, Sorting);
	}

	return true;
}

public int Sorting(int i, int j, Handle array, Handle hndl)
{
	int temp_item[Item];
	int temp_item2[Item];

	g_aCustomItems.GetArray(i, temp_item[0]);
	g_aCustomItems.GetArray(j, temp_item2[0]);

	if (temp_item[Sort] < temp_item2[Sort])
	{
		return -1;
	}
	else if (temp_item[Sort] > temp_item2[Sort])
	{
		return 1;
	}

	return 0;
}

public int Native_GetCustomItemPrice(Handle plugin, int numParams)
{
	char temp_short[32];
	GetNativeString(1, temp_short, sizeof(temp_short));

	int temp_item[Item];

	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if (strcmp(temp_short, temp_item[Short], false) == 0)
		{
			return temp_item[Price];
		}
	}

	return 0;
}

public int Native_GetCustomItemRole(Handle plugin, int numParams)
{
	char temp_short[32];
	GetNativeString(1, temp_short, sizeof(temp_short));

	int temp_item[Item];

	for (int i = 0; i < g_aCustomItems.Length; i++)
	{
		g_aCustomItems.GetArray(i, temp_item[0]);
		if (strcmp(temp_short, temp_item[Short], false) == 0)
		{
			return temp_item[Role];
		}
	}
	return 0;
}

public void TTT_OnClientGetRole(int client, int role)
{
	if (g_cCreditsTimer.BoolValue)
	{
		if (g_cCreditsInterval.FloatValue >= 60.0)
		{
			g_hCreditsTimer[client] = CreateTimer(g_cCreditsInterval.FloatValue, Timer_CreditsTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_CreditsTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (TTT_IsClientValid(client))
	{
		if (IsPlayerAlive(client))
		{
			int iCredits = GetRandomInt(g_cCreditsMin.IntValue, g_cCreditsMax.IntValue);
			addCredits(client, iCredits, g_cCreditsMessage.BoolValue);
			return Plugin_Continue;
		}
	}

	g_hCreditsTimer[client] = null;
	return Plugin_Stop;
}

public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		if (g_cResetCreditsEachRound.BoolValue)
		{
			g_iCredits[client] = g_cStartCredits.IntValue;
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (TTT_IsClientValid(client))
	{
		if (TTT_IsRoundActive())
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "Your credits is", client, g_iCredits[client]);
		}
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	g_iCredits[client] = g_cStartCredits.IntValue;
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	ClearTimer(g_hCreditsTimer[client]);
}

public void OnClientDisconnect(int client)
{
	ClearTimer(g_hCreditsTimer[client]);
}

public Action Command_Credits(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	CPrintToChat(client, "%s %T", g_sPluginTag, "Your credits is", client, g_iCredits[client]);

	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!TTT_IsClientValid(client))
	{
		return;
	}

	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!TTT_IsClientValid(iAttacker) || iAttacker == client)
	{
		return;
	}

	if (TTT_GetClientRole(iAttacker) == TTT_TEAM_INNOCENT && TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		subtractCredits(iAttacker, g_cCreditsII.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_INNOCENT && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		addCredits(iAttacker, g_cCreditsIT.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_INNOCENT && TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		subtractCredits(iAttacker, g_cCreditsID.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_TRAITOR && TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		addCredits(iAttacker, g_cCreditsTI.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_TRAITOR && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		subtractCredits(iAttacker, g_cCreditsTT.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_TRAITOR && TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		addCredits(iAttacker, g_cCreditsTD.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_DETECTIVE && TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
	{
		subtractCredits(iAttacker, g_cCreditsDI.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_DETECTIVE && TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
	{
		addCredits(iAttacker, g_cCreditsDT.IntValue, true);
	}
	else if (TTT_GetClientRole(iAttacker) == TTT_TEAM_DETECTIVE && TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
	{
		subtractCredits(iAttacker, g_cCreditsDD.IntValue, true);
	}
}

public void TTT_OnRoundEnd(int WinningTeam)
{
	LoopValidClients(client)
	{
		ClearTimer(g_hCreditsTimer[client]);
		switch (WinningTeam)
		{
			case TTT_TEAM_DETECTIVE:
			{
				if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE || TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if (IsPlayerAlive(client))
					{
						addCredits(client, g_cTraitorloseAliveNonTraitors.IntValue);
					}
					else
					{
						addCredits(client, g_cTraitorloseDeadNonTraitors.IntValue);
					}
				}

			}
			case TTT_TEAM_INNOCENT:
			{
				if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE || TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
				{
					if (IsPlayerAlive(client))
					{
						addCredits(client, g_cTraitorloseAliveNonTraitors.IntValue);
					}
					else
					{
						addCredits(client, g_cTraitorloseDeadNonTraitors.IntValue);
					}
				}
			}
			case TTT_TEAM_TRAITOR:
			{
				if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
				{
					if (IsPlayerAlive(client))
					{
						addCredits(client, g_cTraitorwinAliveTraitors.IntValue);
					}
					else
					{
						addCredits(client, g_cTraitorwinDeadTraitors.IntValue);
					}
				}
			}
		}
	}
}

public void TTT_OnBodyFound(int client, int victim, const char[] deadPlayer)
{
	addCredits(client, g_cCreditsFoundBody.IntValue);
}

stock void addCredits(int client, int credits, bool message = false)
{
	int newcredits = g_iCredits[client] + credits;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnCreditsGiven_Pre);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_PushCell(newcredits);
	Call_Finish(res);

	if (res > Plugin_Changed)
	{
		return;
	}

	g_iCredits[client] = newcredits;

	if (g_cShowEarnCreditsMessage.BoolValue && message)
	{
		if (g_cMessageTypCredits.IntValue == 1)
		{
			char sBuffer[MAX_MESSAGE_LENGTH];
			Format(sBuffer, sizeof(sBuffer), "%T", "credits earned", client, credits, g_iCredits[client]);
			CFormatColor(sBuffer, sizeof(sBuffer), client);
			PrintHintText(client, sBuffer);
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "credits earned", client, credits, g_iCredits[client]);
		}
	}

	Call_StartForward(g_hOnCreditsGiven);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_Finish();
}

stock void subtractCredits(int client, int credits, bool message = false)
{
	int newcredits = g_iCredits[client] - credits;

	Action res = Plugin_Continue;
	Call_StartForward(g_hOnCreditsGiven_Pre);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_PushCell(newcredits);
	Call_Finish(res);

	if (res > Plugin_Changed)
	{
		return;
	}

	g_iCredits[client] = newcredits;

	if (g_iCredits[client] < 0)
	{
		g_iCredits[client] = 0;
	}

	if (g_cShowLoseCreditsMessage.BoolValue && message)
	{
		if (g_cMessageTypCredits.IntValue == 1)
		{
			char sBuffer[MAX_MESSAGE_LENGTH];
			Format(sBuffer, sizeof(sBuffer), "%T", "lost credits", client, credits, g_iCredits[client]);
			CFormatColor(sBuffer, sizeof(sBuffer), client);
			PrintHintText(client, sBuffer);
		}
		else
		{
			CPrintToChat(client, "%s %T", g_sPluginTag, "lost credits", client, credits, g_iCredits[client]);
		}
	}

	Call_StartForward(g_hOnCreditsGiven);
	Call_PushCell(client);
	Call_PushCell(g_iCredits[client]);
	Call_Finish();
}

stock void setCredits(int client, int credits)
{
	g_iCredits[client] = credits;

	if (g_iCredits[client] < 0)
	{
		g_iCredits[client] = 0;
	}
}

public Action Command_SetCredits(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setcredits <#userid|name> <credits>");

		return Plugin_Handled;
	}
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	char arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	int credits = StringToInt(arg2);

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		if (!TTT_IsClientValid(target_list[i]))
		{
			return Plugin_Handled;
		}

		setCredits(target_list[i], credits);

		CPrintToChat(client, "%s %T", g_sPluginTag, "AdminSet", client, target_list[i], credits, "Credits");
	}

	return Plugin_Continue;
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (TTT_IsClientValid(client))
	{
		return g_iCredits[client];
	}
	return 0;
}

public int Native_SetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int credits = GetNativeCell(2);

	if (TTT_IsClientValid(client))
	{
		setCredits(client, credits);
		return g_iCredits[client];
	}
	return 0;
}

public int Native_AddClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int credits = GetNativeCell(2);

	if (TTT_IsClientValid(client))
	{
		setCredits(client, g_iCredits[client]+credits);
		return g_iCredits[client];
	}
	return 0;
}

stock void ClearTimer(Handle &timer)
{
	if (timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}
