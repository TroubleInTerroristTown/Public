#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Inventory"

enum eInventory
{
	userid,
	availableCredits,
	StringMap:hInventoryItems
}

bool g_bCreditLoot = false;
bool g_bItemLoot = false;

char g_szPluginTag[64];

ConVar g_cv_PluginTag = null;
ConVar g_cv_EnableCreditLoot = null;
ConVar g_cv_EnableItemLoot = null;

Handle g_hOnInventoryReady = null;
Handle g_hOnInventoryMenuItemSelect = null;

StringMap g_PlayerInventory = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_PlayerInventory = new StringMap();
	
	g_hOnInventoryReady = CreateGlobalForward("TTT_OnInventoryReady", ET_Ignore);
	g_hOnInventoryMenuItemSelect = CreateGlobalForward("TTT_OnInventoryMenuItemSelect", ET_Ignore, Param_Cell, Param_String);
	
	CreateNative("TTT_AddInventoryItem", Native_AddInventoryItem);
	CreateNative("TTT_RemoveInventoryItem", Native_RemoveInventoryItem);
	CreateNative("TTT_GetInventoryListing", Native_GetInventoryListing);
	CreateNative("TTT_IsItemInInventory", Native_IsItemInInventory);
	
	RegPluginLibrary("ttt_inventory");
}

public void OnPluginStart()
{
	TTT_IsGameCSGO();
	LoadTranslations("ttt.phrases");
	
	TTT_StartConfig("inventory");
	CreateConVar("ttt2_inventory_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
	g_cv_EnableCreditLoot = AutoExecConfig_CreateConVar("inventory_enable_loot_credit", "1", "Enables players to loot credits from dead bodies.");
	g_cv_EnableItemLoot = AutoExecConfig_CreateConVar("inventory_enable_loot_item", "1", "Enables players to loot items from dead bodies.");
	TTT_EndConfig();
	
	RegConsoleCmd("sm_ttt_inventory", Command_Inventory);
	
	g_cv_EnableCreditLoot.AddChangeHook(OnConvarChanged);
	g_cv_EnableItemLoot.AddChangeHook(OnConvarChanged);
	
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
	g_bCreditLoot = g_cv_EnableCreditLoot.BoolValue;
	g_bItemLoot = g_cv_EnableItemLoot.BoolValue;
	
	g_cv_PluginTag = FindConVar("ttt_plugin_tag");
	g_cv_PluginTag.AddChangeHook(OnConvarChanged);
	g_cv_PluginTag.GetString(g_szPluginTag, sizeof(g_szPluginTag));
}

public Action Command_Inventory(int client, int args)
{
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (!TTT_IsRoundActive())
	{
		ReplyToCommand(client, "%T", "RoundInactive", client);
		return Plugin_Handled;
	}
	
	Menu inventoryMenu = new Menu(Menu_InventoryHandler);
	StringMap playerInv = GetPlayerInventory(client);
	if (playerInv == null)
	{
		ReplyToCommand(client, "You have no items registered in your inventory.");
		return Plugin_Handled;
	}
	
	
	StringMapSnapshot inventoryListing = playerInv.Snapshot();
	for (int i = 0; i < inventoryListing.Length; i++)
	{
		char itemShort[16];
		inventoryListing.GetKey(i, itemShort, sizeof(itemShort));
		
		int amount;
		GetTrieValue(inventoryListing, itemShort, amount);
		
		char itemLong[32];
		if (TTT_GetItemName(itemShort, itemLong, sizeof(itemLong)))
		{
			char display[64];
			char szAmount[4];
			
			IntToString(amount, szAmount, sizeof(szAmount));
			Format(display, sizeof(display), "%s (x%s)", itemLong, szAmount);
			inventoryMenu.AddItem(itemShort, display);
		}
	}
	inventoryMenu.SetTitle("%T", "InventoryTitle", client);
	inventoryMenu.Display(client, MENU_TIME_FOREVER);
	
	delete inventoryListing;
	
	return Plugin_Handled;
}

public int Menu_InventoryHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsPlayerAlive(client))
			{
				CPrintToChat(client, "%s %T", g_szPluginTag, "YouAreDead", client);
				return;
			}
			
			char info[16];
			menu.GetItem(itemNum, info, sizeof(info));
			
			Call_StartForward(g_hOnInventoryMenuItemSelect);
			Call_PushCell(client);
			Call_PushString(info);
			Call_Finish();
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
	//Reset Inventories
	StringMapSnapshot inventories = g_PlayerInventory.Snapshot();
	for (int i = 0; i < inventories.Length; i++)
	{
		char key[16];
		inventories.GetKey(i, key, sizeof(key));
		
		ClearInventory(key);
	}
	
	LoopValidClients(client)
	{
		CreateNewInventory(client);
	}
	
	Call_StartForward(g_hOnInventoryReady);
	Call_Finish();
	
	delete inventories;
}

public Action TTT_OnBodyCheck(int client, int[] ragdoll)
{
	if (!g_bCreditLoot && !g_bItemLoot)
	{
		return Plugin_Continue;
	}
	
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}
	
	char ragdollUserIdKey[16];
	int inventory[eInventory];
	int ragdollUserId = ragdoll[Victim];
	
	IntToString(ragdollUserId, ragdollUserIdKey, sizeof(ragdollUserIdKey));
	if (!g_PlayerInventory.GetArray(ragdollUserIdKey, inventory, eInventory))
	{
		return Plugin_Continue;
	}
	
	StringMap invItems = inventory[hInventoryItems];
	if (invItems == null)
	{
		return Plugin_Continue;
	}
	
	int lootedCredits;
	int lootedItems;
	if (g_bCreditLoot)
	{
		lootedCredits = inventory[availableCredits];
		if (lootedCredits > 0)
		{
			TTT_AddClientCredits(client, lootedCredits);
			inventory[availableCredits] = 0;
		}
	}
	
	if (g_bItemLoot)
	{
		StringMapSnapshot items = invItems.Snapshot();
		for (int i = 0; i < items.Length; i++)
		{
			char key[16];
			items.GetKey(i, key, sizeof(key));
			
			int clientRole = TTT_GetClientRole(client);
			int itemRole = TTT_GetCustomItemRole(key);
			if (clientRole != itemRole || itemRole != TTT_TEAM_UNASSIGNED)
			{
				continue;
			}
			
			TTT_GiveClientItem(client, key);
			
			invItems.Remove(key);
			lootedItems++;
		}
		
		delete items;
	}
	
	g_PlayerInventory.SetArray(ragdollUserIdKey, inventory, eInventory);
	
	if (lootedCredits || lootedItems)
	{
		CPrintToChat(client, "%T", "SuccessfulLoot", client, lootedCredits, lootedItems, ragdoll[VictimName]);
	}
	
	return Plugin_Continue;
}

public int Native_AddInventoryItem(Handle plugin, int numparams)
{
	char itemshort[16];
	int client = GetNativeCell(1);
	GetNativeString(2, itemshort, sizeof(itemshort));
	
	return AddInventoryItem(client, itemshort);
}

public int Native_RemoveInventoryItem(Handle plugin, int numparams)
{
	char itemshort[16];
	int client = GetNativeCell(1);
	GetNativeString(2, itemshort, sizeof(itemshort));
	
	return RemoveInventoryItem(client, itemshort);
}

public int Native_GetInventoryListing(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	
	StringMap inventoryListing = GetPlayerInventory(client);
	
	if (inventoryListing == null)
	{
		return view_as<int>(INVALID_HANDLE);
	}
	
	return view_as<int>(inventoryListing.Snapshot());
}

public int Native_IsItemInInventory(Handle plugin, int numparams)
{
	char itemshort[16];
	int client = GetNativeCell(1);
	
	GetNativeString(2, itemshort, sizeof(itemshort));
	
	return IsItemInInventory(client, itemshort);
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	char szUserId[16];
	int iUserId = event.GetInt("userid");
	int inventory[eInventory];
	
	IntToString(iUserId, szUserId, sizeof(szUserId));
	if (!g_PlayerInventory.GetArray(szUserId, inventory, eInventory))
	{
		return Plugin_Continue;
	}
	
	int client = GetClientOfUserId(iUserId);
	if (!TTT_IsClientValid(client))
	{
		return Plugin_Continue;
	}
	
	inventory[availableCredits] = TTT_GetClientCredits(client);
	g_PlayerInventory.SetArray(szUserId, inventory, eInventory);
	
	return Plugin_Continue;
}

public void OnConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cv_PluginTag)
	{
		strcopy(g_szPluginTag, sizeof(g_szPluginTag), newValue);
	}
	else if (convar == g_cv_EnableCreditLoot || convar == g_cv_EnableItemLoot)
	{
		if (StrEqual(oldValue, newValue))
		{
			return;
		}
			
		if (!IsCharNumeric(newValue[0]))
		{
			return;
		}
			
		int val = StringToInt(newValue);
		if (val < 0 || val > 1)
		{
			return;
		}
			
		if (convar == g_cv_EnableCreditLoot)
		{
			g_bCreditLoot = view_as<bool>(val);
		}
		else
		{
			g_bItemLoot = view_as<bool>(val);
		}
	}
}

bool IsItemInInventory(int client, const char[] itemshort)
{
	any inventory[eInventory];
	char useridkey[16];
	StringMap inventoryMap;
	
	IntToString(GetClientUserId(client), useridkey, sizeof(useridkey));
	if (!g_PlayerInventory.GetArray(useridkey, inventory, eInventory))
	{
		return false;
	}
	
	inventoryMap = inventory[hInventoryItems];
	if (inventoryMap == null)
	{
		return false;
	}
	
	int amount;
	if (inventoryMap.GetValue(itemshort, amount))
	{
		return true;
	}
	
	return false;
}

bool EditInventoryItem(int client, const char[] itemshort, int quantity)
{
	any inventory[eInventory];
	bool all = false;
	char useridkey[16];
	StringMap inventoryMap;
	
	if (quantity == 0)
	{
		all = true;
	}
	
	IntToString(GetClientUserId(client), useridkey, sizeof(useridkey));
	if (!g_PlayerInventory.GetArray(useridkey, inventory, eInventory))
	{
		if (quantity <= 0)
		{
			return true;
		}
		return false;
	}
	
	inventoryMap = inventory[hInventoryItems];
	if (inventoryMap == null)
	{
		if (quantity <= 0)
		{
			return true;
		}
		return false;
	}
	
	int amount;
	if (!inventoryMap.GetValue(itemshort, amount))
	{
		if (quantity <= 0)
		{
			return true;
		}
		
		return inventoryMap.SetValue(itemshort, quantity);
	}
	
	amount -= quantity;
	if (amount <= 0 || all)
	{
		inventoryMap.Remove(itemshort);
		return true;
	}
	
	inventoryMap.SetValue(itemshort, amount);
	return true;
}

bool AddInventoryItem(int client, const char[] itemshort)
{
	if (!TTT_IsClientValid(client))
	{
		return false;
	}
	
	return EditInventoryItem(client, itemshort, 1);
}

bool RemoveInventoryItem(int client, const char[] itemshort)
{
	if (!TTT_IsClientValid(client))
	{
		return false;
	}
	
	return EditInventoryItem(client, itemshort, 0);
}

void CreateNewInventory(int client)
{
	any newInventory[eInventory];
	newInventory[userid] = GetClientUserId(client);
	newInventory[availableCredits] = 0;
	newInventory[hInventoryItems] = new StringMap();
	
	char key[16];
	IntToString(newInventory[userid], key, sizeof(key));
	ClearInventory(key);
	
	g_PlayerInventory.SetArray(key, newInventory, eInventory);
}

void ClearInventory(const char[] useridkey)
{
	any inventory[eInventory];
	if (g_PlayerInventory.GetArray(useridkey, inventory, eInventory))
	{
		return;
	}
	
	if (inventory[hInventoryItems] == null)
	{
		return;
	}
	
	delete inventory[hInventoryItems];
	g_PlayerInventory.Remove(useridkey);
}

StringMap GetPlayerInventory(int client, bool isuserid = false)
{
	char useridkey[16];
	if (!isuserid)
	{
		if (!TTT_IsClientValid(client))
		{
			return null;
		}
		
		IntToString(GetClientUserId(client), useridkey, sizeof(useridkey));
	}
	else
	{
		IntToString(client, useridkey, sizeof(useridkey));
	}
	
	any inventory[eInventory];
	if (!g_PlayerInventory.GetArray(useridkey, inventory, eInventory))
	{
		return null;
	}
	
	if (inventory[hInventoryItems] == null)
	{
		return null;
	}
	
	return inventory[hInventoryItems];
}