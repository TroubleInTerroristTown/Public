#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <ttt>
#include <config_loader>
#include <multicolors>
#include <ttt_shop>

#pragma newdecls required

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

char g_sPluginTag[128];
char g_sConfigFile[PLATFORM_MAX_PATH];

bool g_bSortItems = false;

Handle g_hOnItemPurchased = null;

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

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	
	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "sm_%s", g_sShopCMDs[i]);
		RegConsoleCmd(sBuffer, Command_Shop);
	}
	
	g_aCustomItems = new ArrayList(83);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/config.cfg");
	Config_Setup("TTT", g_sConfigFile);
	Config_LoadString("ttt_plugin_tag", "{orchid}[{green}T{darkred}T{blue}T{orchid}]{lightgreen} %T", "The prefix used in all plugin messages (DO NOT DELETE '%T')", g_sPluginTag, sizeof(g_sPluginTag));
	Config_Done();
	
	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/ttt/shop.cfg");
	Config_Setup("Shop", g_sConfigFile);
	g_bSortItems = Config_LoadBool("ttt_sort_items", true, "Sort shop items? 0 = Disabled. 1 = Enabled (default).");
	// Doesn't exist anymore
	Config_Remove("ttt_sort_items_price");
	Config_Remove("ttt_sort_items_price_order");
	Config_Done();
	
	LoadTranslations("ttt.phrases");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnItemPurchased = CreateGlobalForward("TTT_OnItemPurchased", ET_Hook, Param_Cell, Param_String);
	
	CreateNative("TTT_RegisterCustomItem", Native_RegisterCustomItem);
	CreateNative("TTT_GetCustomItemPrice", Native_GetCustomItemPrice);
	CreateNative("TTT_GetCustomItemRole", Native_GetCustomItemRole);
	
	return APLRes_Success;
}

public Action Command_Shop(int client, int args)
{
	if (!TTT_IsClientValid(client))
		return Plugin_Handled;
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, g_sPluginTag, "YouAreDead", client);
		return Plugin_Handled;
	}
	
	int team = TTT_GetClientRole(client);
	if (team != TTT_TEAM_UNASSIGNED)
	{
		Handle menu = CreateMenu(Menu_ShopHandler);
		SetMenuTitle(menu, "%T", "TTT Shop", client);
		
		char display[128];
		int temp_item[Item];
		
		for (int i = 0; i < g_aCustomItems.Length; i++)
		{
			g_aCustomItems.GetArray(i, temp_item[0]);
			if (strlen(temp_item[Short]) > 1)
			{
				if ((temp_item[Role] == 0) || (temp_item[Role] == team))
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
		CPrintToChat(client, g_sPluginTag, "Please wait till your team is assigned", client);
	}
	
	return Plugin_Handled;
	
}

public int Menu_ShopHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		if(!IsPlayerAlive(client))
		{
			CPrintToChat(client, g_sPluginTag, "YouAreDead", client);
			return;
		}
			
		char info[32];
		GetMenuItem(menu, itemNum, info, sizeof(info));	
		
		int temp_item[Item];
		
		for (int i = 0; i < g_aCustomItems.Length; i++)
		{
			g_aCustomItems.GetArray(i, temp_item[0]);
			if ((strlen(temp_item[Short]) > 0) && (strcmp(info, temp_item[Short]) == 0))
			{
				if ((TTT_GetClientCredits(client) >= temp_item[Price]) && ((temp_item[Role] == 0) || (TTT_GetClientRole(client) == temp_item[Role])))
				{
					Action res = Plugin_Continue;
					Call_StartForward(g_hOnItemPurchased);
					Call_PushCell(client);
					Call_PushString(temp_item[Short]);
					Call_Finish(res);
					
					if (res < Plugin_Stop) {
						TTT_SetClientCredits(client, (TTT_GetClientCredits(client) - temp_item[Price]));
						CPrintToChat(client, g_sPluginTag, "Item bought! Your REAL money is", client, TTT_GetClientCredits(client));
					}
				}
				else
					CPrintToChat(client, g_sPluginTag, "You don't have enough money", client);
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if (!TTT_IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	char sText[MAX_MESSAGE_LENGTH];
	GetCmdArgString(sText, sizeof(sText));
	
	StripQuotes(sText);
	
	if (sText[0] == '@')
		return Plugin_Continue;
	
	for (int i = 0; i < sizeof(g_sShopCMDs); i++)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "!%s", g_sShopCMDs[i]);
		
		if (StrEqual(sText, sBuffer, false))
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public int Native_RegisterCustomItem(Handle plugin, int numParams)
{
	if (numParams < 4)
		return false;
	
	char temp_short[16];
	char temp_long[64];
	GetNativeString(1, temp_short, sizeof(temp_short));
	GetNativeString(2, temp_long, sizeof(temp_long));
	
	int temp_price = GetNativeCell(3);
	int temp_role = GetNativeCell(4);
	int temp_sort = GetNativeCell(5);
	
	int temp_item[Item];
	
	if ((strlen(temp_short) < 1) || (strlen(temp_long) < 1) || (temp_price <= 0))
		return false;
	
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
	
	if(g_bSortItems)
	{
		Sorting();
	}
	
	return true;
}

//TODO Improve sort algorithm (currently it's a bubble sort)
public void Sorting()
{
	int temp_item[Item];
	int temp_item2[Item];

	for (int i = 1; i < g_aCustomItems.Length; i++)
	{
		for (int j = 0; j < (g_aCustomItems.Length - i); j++)
		{
			g_aCustomItems.GetArray(j, temp_item[0]);
			g_aCustomItems.GetArray(j + 1, temp_item2[0]);
			if (temp_item[Sort] < temp_item2[Sort])
			{
				g_aCustomItems.SwapAt(j, j + 1);
			}
		}
	}
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
			return temp_item[Price];
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
			return temp_item[Role];
	}
	return 0;
} 