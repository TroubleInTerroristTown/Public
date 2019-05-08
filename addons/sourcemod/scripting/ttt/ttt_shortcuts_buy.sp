#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <ttt>
#include <ttt_shop>
#include <clientprefs>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - ShortcutsBuy"
#define SHORT_NAME "ShortcutsBuy"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

methodmap Cookie < Handle
{
	public Cookie(const char[] name, const char[] description, CookieAccess access)
	{
		if(name[0] == 0)
			return view_as<Cookie>(INVALID_HANDLE);
		return view_as<Cookie>(RegClientCookie(name, description, access));
	}
	
	property Handle Ref
	{
		public get() { return view_as<Handle>(this); }
	}
	
	public void SetValue(int iClient, const char[] sValue="")
	{
		if(this.Ref != INVALID_HANDLE)
			SetClientCookie(iClient, this.Ref, sValue);
		else
			LogError("[SM] Tried to set a cookie with an invalid cookie handle!");
	}
	
	public void GetValue(int iClient, char[] sValue, int iMaxLen)
	{
		if(this.Ref != INVALID_HANDLE)
			GetClientCookie(iClient, this.Ref, sValue, iMaxLen);
		else
			LogError("[SM] Tried to get a cookie with an invalid cookie handle!");
	}

}

ArrayList g_TTTitemsList = null;

#define SHORT_NAMEt "ShortcutsBuy_t"
#define SHORT_NAMEd "ShortcutsBuy_d"
#define SHORT_NAMEi "ShortcutsBuy_i"

ConVar g_cPrio = null;
ConVar g_cLongName = null;

enum sItemInfo
{
	String:szitemshort[32],
	String:szitemlong[64],
	String:iprice[11],
	String:irole[11]
}


char g_iSELECT_ItemName[MAXPLAYERS+1][32];
int g_iSELECT_Team[MAXPLAYERS+1];
enum UserItemInfoADT
{
	String:slot1[64],
	String:slot2[64],
	String:slot3[64],
	String:slot4[64],
	String:slot5[64],
	String:slot6[64],
}

Cookie g_cookie_slot1_t = null;
Cookie g_cookie_slot2_t = null;
Cookie g_cookie_slot3_t = null;
Cookie g_cookie_slot4_t = null;
Cookie g_cookie_slot5_t = null;
Cookie g_cookie_slot6_t = null;

Cookie g_cookie_slot1_i = null;
Cookie g_cookie_slot2_i = null;
Cookie g_cookie_slot3_i = null;
Cookie g_cookie_slot4_i = null;
Cookie g_cookie_slot5_i = null;
Cookie g_cookie_slot6_i = null;


Cookie g_cookie_slot1_d = null;
Cookie g_cookie_slot2_d = null;
Cookie g_cookie_slot3_d = null;
Cookie g_cookie_slot4_d = null;
Cookie g_cookie_slot5_d = null;
Cookie g_cookie_slot6_d = null;

int g_ePlayerIteamSaveInfo[MAXPLAYERS + 1][10][UserItemInfoADT];


public void OnPluginStart()
{
	
	TTT_IsGameCSGO();
	TTT_StartConfig("shortcutsbuy");
	CreateConVar("ttt2_shortcutsbuy_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cLongName = AutoExecConfig_CreateConVar("shortcuts_buy_name", "Shortcuts buy ttt item", "The name of this in Shop");
	g_cPrio = AutoExecConfig_CreateConVar("shortcutsbuy_sort_prio", "-1000", "The sorting priority of the fastbuy in the shop menu.");
	TTT_EndConfig();
	
	
	g_cookie_slot1_t = new Cookie("ttt_shortcutsbuy_slot1_t","",CookieAccess_Private);
	g_cookie_slot2_t = new Cookie("ttt_shortcutsbuy_slot2_t","",CookieAccess_Private);
	g_cookie_slot3_t = new Cookie("ttt_shortcutsbuy_slot3_t","",CookieAccess_Private);
	g_cookie_slot4_t = new Cookie("ttt_shortcutsbuy_slot4_t","",CookieAccess_Private);
	g_cookie_slot5_t = new Cookie("ttt_shortcutsbuy_slot5_t","",CookieAccess_Private);
	g_cookie_slot6_t = new Cookie("ttt_shortcutsbuy_slot6_t","",CookieAccess_Private);
	
	
	g_cookie_slot1_d = new Cookie("ttt_shortcutsbuy_slot1_d","",CookieAccess_Private);
	g_cookie_slot2_d = new Cookie("ttt_shortcutsbuy_slot2_d","",CookieAccess_Private);
	g_cookie_slot3_d = new Cookie("ttt_shortcutsbuy_slot3_d","",CookieAccess_Private);
	g_cookie_slot4_d = new Cookie("ttt_shortcutsbuy_slot4_d","",CookieAccess_Private);
	g_cookie_slot5_d = new Cookie("ttt_shortcutsbuy_slot5_d","",CookieAccess_Private);
	g_cookie_slot6_d = new Cookie("ttt_shortcutsbuy_slot6_d","",CookieAccess_Private);
	
	g_cookie_slot1_i = new Cookie("ttt_shortcutsbuy_slot1_i","",CookieAccess_Private);
	g_cookie_slot2_i = new Cookie("ttt_shortcutsbuy_slot2_i","",CookieAccess_Private);
	g_cookie_slot3_i = new Cookie("ttt_shortcutsbuy_slot3_i","",CookieAccess_Private);
	g_cookie_slot4_i = new Cookie("ttt_shortcutsbuy_slot4_i","",CookieAccess_Private);
	g_cookie_slot5_i = new Cookie("ttt_shortcutsbuy_slot5_i","",CookieAccess_Private);
	g_cookie_slot6_i = new Cookie("ttt_shortcutsbuy_slot6_i","",CookieAccess_Private);
	
	RegConsoleCmd("sm_fbuy", CMD_fbuy);
	
	g_TTTitemsList = new ArrayList(118);
	
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));

    
    TTT_RegisterCustomItem(SHORT_NAMEt, sName, 1, TTT_TEAM_TRAITOR, g_cPrio.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEd, sName, 1, TTT_TEAM_DETECTIVE, g_cPrio.IntValue);
    TTT_RegisterCustomItem(SHORT_NAMEi, sName, 1, TTT_TEAM_INNOCENT, g_cPrio.IntValue);
}



public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAMEt, false) || StrEqual(itemshort, SHORT_NAMEd, false) || StrEqual(itemshort, SHORT_NAMEi, false))
        {
			TTT_SetClientCredits(client,TTT_GetClientCredits(client)+1);
			Menu_ShowFastBuyMenu(client);
		}
	}
}



int CheckItemInArray(const char[] itemshort)
{
	int ItemInfo[sItemInfo];
	for(int i=0;i < g_TTTitemsList.Length;++i)
	{
		g_TTTitemsList.GetArray(i,ItemInfo[0]);
			
		if(ItemInfo[szitemshort][0] != '\0' && StrEqual(ItemInfo[szitemshort],itemshort,false))	{
			return true;
		}
	}
	return false;

}

public void TTT_OnRegisterCustomItemPost(const char[] itemshort, const char[] itemlong, const int price, const int role, const int sort)
{
	if(CheckItemInArray(itemshort))
		return;

	int ItemInfo[sItemInfo];
	Format(ItemInfo[szitemshort], 32, itemshort);
	Format(ItemInfo[szitemlong], 64, itemlong);
	Format(ItemInfo[iprice], 11, "%d",price);
	Format(ItemInfo[irole], 11, "%d",role);

	g_TTTitemsList.PushArray(ItemInfo[0]);

}

void Menu_SELECT_Role(int client)
{
	Menu menu = new Menu(HMenu_SELECT_Role);

	menu.SetTitle("Shortcuts buy Settings");

	if(TTT_IsClientValid(client)){
		int role = TTT_GetClientRole(client);

		if(role == TTT_TEAM_INNOCENT){
			menu.AddItem("I", "Current:Innocent");
		}
		else if(role == TTT_TEAM_DETECTIVE){
			menu.AddItem("D", "Current:Detective");
		}
		else if(role == TTT_TEAM_TRAITOR){
			menu.AddItem("T", "Current:Traitor");
		}
	}

	menu.AddItem("I", "Innocent");
	menu.AddItem("D", "Detective");
	menu.AddItem("T", "Traitor");

	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int HMenu_SELECT_Role(Menu menu, MenuAction action, int param1, int param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if(info[0] == 'I')
		{
			g_iSELECT_Team[param1] = TTT_TEAM_INNOCENT;
			Menu_Test_SetBuyInfo(param1,TTT_TEAM_INNOCENT);
		}
		else if(info[0] == 'D')
		{
			g_iSELECT_Team[param1] = TTT_TEAM_DETECTIVE;
			Menu_Test_SetBuyInfo(param1,TTT_TEAM_DETECTIVE);
		}
		else if(info[0] == 'T')
		{
			g_iSELECT_Team[param1] = TTT_TEAM_TRAITOR;
			Menu_Test_SetBuyInfo(param1,TTT_TEAM_TRAITOR);
		}
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}


public Action CMD_REDIRECT(int client, int args)
{
	Menu_SELECT_Role(client);
	return Plugin_Handled;
}



void Menu_Test_SetBuyInfo(int client,int role)
{
	Menu menu = new Menu(MenuHandler1);

	char szShow[128];

	menu.SetTitle("Shortcuts buy settings");

	for(int i=0;i < g_TTTitemsList.Length;++i)
	{
		int ItemInfo[sItemInfo];
		g_TTTitemsList.GetArray(i,ItemInfo[0]);

		if(StringToInt(ItemInfo[irole]) == role)
		{
			Format(szShow,128,"%s Price:%s",ItemInfo[szitemlong],ItemInfo[iprice]);
			menu.AddItem(ItemInfo[szitemshort], szShow);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, 20);
}


public int MenuHandler1(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		strcopy(g_iSELECT_ItemName[client],32,info);
		Menu_SetSlot(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}


//SETTINGS menu

void Menu_SetSlot(int client)
{
	Menu menu = new Menu(MenuHandler_SetSlot);

	char szShow[128],tsz[128];
	GetLongItemLongName(g_iSELECT_ItemName[client],tsz);


	menu.SetTitle("Shortcuts buy menu  %s(%s)",g_iSELECT_ItemName[client],tsz);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot1],szShow);
	Format(szShow,128,"Slot [1] --- %s",szShow);
	menu.AddItem("1", szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot2],szShow);
	Format(szShow,128,"Slot [2] --- %s",szShow);
	menu.AddItem("2", szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot3],szShow);
	Format(szShow,128,"Slot [3] --- %s",szShow);
	menu.AddItem("3", szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot4],szShow);
	Format(szShow,128,"Slot [4] --- %s",szShow);
	menu.AddItem("4", szShow);


	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot5],szShow);
	Format(szShow,128,"Slot [5] --- %s",szShow);
	menu.AddItem("5", szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot6],szShow);
	Format(szShow,128,"Slot [6] --- %s",szShow);
	menu.AddItem("6", szShow);






	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int MenuHandler_SetSlot(Menu menu, MenuAction action, int client, int param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if(info[0] == '1')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot1],64,g_iSELECT_ItemName[client]);
		else if(info[0] == '2')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot2],64,g_iSELECT_ItemName[client]);
		else if(info[0] == '3')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot3],64,g_iSELECT_ItemName[client]);
		else if(info[0] == '4')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot4],64,g_iSELECT_ItemName[client]);
		else if(info[0] == '5')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot5],64,g_iSELECT_ItemName[client]);
		else if(info[0] == '6')
			Format(g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot6],64,g_iSELECT_ItemName[client]);

		UpdateCookies(client);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void OnClientCookiesCached(int client)
{
	GetCookie(client);
}

void GetCookie(int client)
{
	g_cookie_slot1_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot1],32);
	g_cookie_slot2_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot2],32);
	g_cookie_slot3_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot3],32);
	g_cookie_slot4_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot4],32);
	g_cookie_slot5_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot5],32);
	g_cookie_slot6_t.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_TRAITOR][slot6],32);

	g_cookie_slot1_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot1],32);
	g_cookie_slot2_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot2],32);
	g_cookie_slot3_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot3],32);
	g_cookie_slot4_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot4],32);
	g_cookie_slot5_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot5],32);
	g_cookie_slot6_i.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_INNOCENT][slot6],32);



	g_cookie_slot1_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot1],32);
	g_cookie_slot2_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot2],32);
	g_cookie_slot2_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot3],32);
	g_cookie_slot3_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot4],32);
	g_cookie_slot4_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot5],32);
	g_cookie_slot6_d.GetValue(client,g_ePlayerIteamSaveInfo[client][TTT_TEAM_DETECTIVE][slot6],32);

}

void UpdateCookies(int client)
{
	if(g_iSELECT_Team[client] == TTT_TEAM_TRAITOR)
	{
		g_cookie_slot1_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot1]);
		g_cookie_slot2_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot2]);
		g_cookie_slot3_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot3]);
		g_cookie_slot4_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot4]);
		g_cookie_slot5_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot5]);
		g_cookie_slot6_t.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot6]);
	}

	if(g_iSELECT_Team[client] == TTT_TEAM_INNOCENT)
	{
		g_cookie_slot1_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot1]);
		g_cookie_slot2_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot2]);
		g_cookie_slot3_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot3]);
		g_cookie_slot4_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot4]);
		g_cookie_slot5_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot5]);
		g_cookie_slot6_i.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot6]);
	}


	if(g_iSELECT_Team[client] == TTT_TEAM_DETECTIVE)
	{
		g_cookie_slot1_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot1]);
		g_cookie_slot2_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot2]);
		g_cookie_slot3_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot3]);
		g_cookie_slot4_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot4]);
		g_cookie_slot5_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot5]);
		g_cookie_slot6_d.SetValue(client,g_ePlayerIteamSaveInfo[client][g_iSELECT_Team[client]][slot6]);
	}


}


public Action CMD_fbuy(int client, int args)
{
	Menu_ShowFastBuyMenu(client);
	return Plugin_Handled;
}

void Menu_ShowFastBuyMenu(int client)
{
	if(!TTT_IsClientValid(client) || !IsPlayerAlive(client))
		return;
	int role = TTT_GetClientRole(client);


	Menu menu = new Menu(MenuHandler_BuyMenu);
	menu.SetTitle("Shortcuts Buy Menu");
	char szShow[128];


	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot1],szShow);

	if(szShow[0] != '\0')
		menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot1], szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot2],szShow);

	if(szShow[0] != '\0')
		menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot2], szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot3],szShow);

	if(szShow[0] != '\0')
	menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot3], szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot4],szShow);

	if(szShow[0] != '\0')
	menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot4], szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot5],szShow);

	if(szShow[0] != '\0')
	menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot5], szShow);

	GetLongItemLongName(g_ePlayerIteamSaveInfo[client][role][slot6],szShow);

	if(szShow[0] != '\0')
		menu.AddItem(g_ePlayerIteamSaveInfo[client][role][slot6], szShow);

	menu.AddItem("Setting", "------Setting shortcuts buy");
	
	menu.ExitButton = true;
	menu.Display(client, 20);
}


public int MenuHandler_BuyMenu(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));

		if(StrEqual(info,"Setting",false))
		{
			Menu_SELECT_Role(client);
			return 0;
		}

		int price = TTT_GetCustomItemPrice(info);
		if(TTT_GetClientCredits(client) > price)
		{
			if(!TTT_IsClientValid(client) || !IsPlayerAlive(client))
				return 0;

			TTT_SetClientCredits(client,TTT_GetClientCredits(client)-price);
			TTT_GiveClientItem(client,info);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}


int GetLongItemLongName(const char[] mszitemshort,char[] sname)
{
	int ItemInfo[sItemInfo];
	for(int i=0;i < g_TTTitemsList.Length;++i)
	{
		g_TTTitemsList.GetArray(i,ItemInfo[0]);
			
		if(ItemInfo[szitemshort][0] != '\0' && StrEqual(ItemInfo[szitemshort],mszitemshort,false))	{

			char szFormat[100];
			Format(szFormat,100,"%s---%s",ItemInfo[szitemlong],ItemInfo[iprice]);

			strcopy(sname,64,szFormat);
			return 0;
		}
	}
	strcopy(sname,64,"");

	return 0;
}
