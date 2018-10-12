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

enum eLootChance
{
	Float:lootchance_credit,
	Float:lootchance_item
}

bool g_bCreditLoot;
bool g_bItemLoot;

char g_szPluginTag[64];

float g_fCreditLootChance;
float g_fItemLootChance;
float g_fLootChanceFallOff;

int g_iCreditLootMax;
int g_iItemLootMax;

ConVar g_cv_PluginTag = null;
ConVar g_cv_EnableCreditLoot = null;
ConVar g_cv_EnableItemLoot = null;
ConVar g_cv_CreditLootMax = null;
ConVar g_cv_ItemLootMax = null;
ConVar g_cv_CreditLootChance = null;
ConVar g_cv_ItemLootChance = null;
ConVar g_cv_LootChanceFallOff = null;

Handle g_hOnInventoryReady = null;
Handle g_hOnInventoryMenuItemSelect = null;

StringMap g_PlayerInventory = null;
StringMap g_PlayerLootChance = null;

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
	g_PlayerInventory = CreateTrie();
	
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
	
	g_cv_EnableCreditLoot = CreateConVar("ttt_enable_loot_credit", "1", "Enables players to loot credits from dead bodies.");
	g_cv_EnableItemLoot = CreateConVar("ttt_enable_loot_item", "1", "Enables players to loot items from dead bodies.");
	g_cv_CreditLootMax = CreateConVar("ttt_loot_credit_max", "0", "The amount of credits a player can loot. 0 for unlimited.");
	g_cv_ItemLootMax = CreateConVar("ttt_loot_item_max", "0", "The amount of items a player can loot per dead body. Duplicates count as an item. 0 for unlimited.");	
	g_cv_CreditLootChance = CreateConVar("ttt_loot_credit_chance", "0.2", "Chance to loot credits. Default: 0.2 meaning 20%.");
	g_cv_ItemLootChance = CreateConVar("ttt_loot_item_chance", "0.3", "Chance to loot items. Default: 0.3 meaning 30%.");
	g_cv_LootChanceFallOff = CreateConVar("ttt_loot_chance_falloff", "0.5", 
	"Upon successful looting, the ratio at which your next loot chance is reduced by. Default: 0.5 meaning loot chance is reduced by 50%.");
	
	RegConsoleCmd("sm_ttt_inventory", Command_Inventory);
	
	HookConVarChange(g_cv_EnableCreditLoot, OnConvarChanged);
	HookConVarChange(g_cv_EnableItemLoot, OnConvarChanged);
	HookConVarChange(g_cv_CreditLootMax, OnConvarChanged);
	HookConVarChange(g_cv_ItemLootMax, OnConvarChanged);
	HookConVarChange(g_cv_CreditLootChance, OnConvarChanged);
	HookConVarChange(g_cv_ItemLootChance, OnConvarChanged);
	HookConVarChange(g_cv_LootChanceFallOff, OnConvarChanged);
	
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
	g_bCreditLoot = GetConVarBool(g_cv_EnableCreditLoot);
	g_bItemLoot = GetConVarBool(g_cv_EnableItemLoot);
	g_iCreditLootMax = GetConVarInt(g_cv_CreditLootMax);
	g_iItemLootMax = GetConVarInt(g_cv_ItemLootMax);
	g_fCreditLootChance = GetConVarFloat(g_cv_CreditLootChance);
	g_fItemLootChance = GetConVarFloat(g_cv_ItemLootChance);
	g_fLootChanceFallOff = GetConVarFloat(g_cv_LootChanceFallOff);
	
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
		ReplyToCommand(client, "%T", "RoundInactive");
		return Plugin_Handled;
	}
	
	Menu inventoryMenu = CreateMenu(Menu_InventoryHandler);
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
		if (TTT_GetItemLong(itemShort, itemLong, sizeof(itemLong)))
		{
			char display[64];
			char szAmount[4];
			
			IntToString(amount, szAmount, sizeof(szAmount));
			Format(display, sizeof(display), "%s (x%s)", itemLong, szAmount);
			inventoryMenu.AddItem(itemShort, display);
		}
	}
	inventoryMenu.SetTitle("%T", "InventoryTitle");
	inventoryMenu.Display(client, MENU_TIME_FOREVER);
	
	CloseHandle(inventoryListing);
	
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
			GetMenuItem(menu, itemNum, info, sizeof(info));
			
			Call_StartForward(g_hOnInventoryMenuItemSelect);
			Call_PushCell(client);
			Call_PushString(info);
			Call_Finish();
		}
		
		case MenuAction_End:
		{
			CloseHandle(menu);
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
	
	char clientUserId[16];
	float chance[eLootChance];
	int lootedCredits;
	IntToString(GetClientUserId(client), clientUserId, sizeof(clientUserId));
	if (!g_PlayerLootChance.GetArray(clientUserId, chance, eLootChance))
	{
		chance[lootchance_credit] = g_fCreditLootChance;
		chance[lootchance_item] = g_fItemLootChance;
		g_PlayerLootChance.SetArray(clientUserId, chance, eLootChance);
	}
	
	float randomFloat = GetRandomFloat();
	//Loot Credit
	if (randomFloat < chance[lootchance_credit])
	{
		randomFloat = GetRandomFloat();
		float giveCredit;
		if (g_iCreditLootMax == 0)
		{
			giveCredit = view_as<float>(inventory[availableCredits]);
		}
		else if (g_iCreditLootMax > 0)
		{
			if (inventory[availableCredits] >= g_iCreditLootMax)
			{
				giveCredit = view_as<float>(g_iCreditLootMax);
			}
			else
			{
				giveCredit = view_as<float>(inventory[availableCredits]);
			}
		}
		
		giveCredit *= randomFloat;
		lootedCredits = RoundFloat(giveCredit);
	}
	
	//Loot Items
	randomFloat = GetRandomFloat();
	char[][] lootedItems = new char[g_iItemLootMax][16];
	int itemsLooted = 0;
	ArrayList lootItemList = CreateArray(16);
	if (randomFloat < chance[lootchance_item])
	{
		StringMapSnapshot items = invItems.Snapshot();
		for (int i = 0; i < items.Length; i++)
		{
			char key[16];
			items.GetKey(i, key, sizeof(key));
			
			int amount;
			invItems.GetValue(key, amount);
			
			for (int j = 0; j < amount; j++)
			{
				lootItemList.PushString(key);
			}
		}
		
		float extraItemChance = chance[lootchance_item] * g_fLootChanceFallOff;
		int maxLoots = g_iItemLootMax;
		ArrayList itemIndex = CreateArray();
		if (lootItemList.Length <= g_iItemLootMax)
		{
			maxLoots = lootItemList.Length;
		}
		
		for (; itemsLooted < maxLoots; itemsLooted++) 
		{
			char itembuf[16];
			int randomIndex = GetRandomInt(0, lootItemList.Length - 1);
			if (itemIndex.FindValue(randomIndex) != -1)
			{
				itemsLooted--;
				continue;
			}
			
			lootItemList.GetString(randomIndex, itembuf, sizeof(itembuf));
			strcopy(lootedItems[itemsLooted], 16, itembuf);
			itemIndex.Push(randomIndex);
			
			randomFloat = GetRandomFloat();
			if (randomFloat < extraItemChance)
			{
				extraItemChance *= g_fLootChanceFallOff;
				continue;
			}
			
			break;
		}
		
	}
	
	if (lootedCredits > 0)
	{
		TTT_AddClientCredits(client, lootedCredits);
	}
	
	for (int i = 0; i < itemsLooted; i++)
	{
		TTT_GiveClientItem(client, lootedItems[i]);
	}
	
	CPrintToChat(client, "You looted %d credits and %d items from %s's corpse!", lootedCredits, itemsLooted, ragdoll[VictimName]);
	return Plugin_Continue;
}

public int Native_AddInventoryItem(Handle plugin, int numparams)
{
	char itemshort[16];
	int client = GetNativeCell(1);
	int quantity = GetNativeCell(3);
	GetNativeString(2, itemshort, sizeof(itemshort));
	
	if (quantity <= 0)
	{
		quantity = 1;
	}
	
	return AddInventoryItem(client, itemshort, quantity);
}

public int Native_RemoveInventoryItem(Handle plugin, int numparams)
{
	char itemshort[16];
	int client = GetNativeCell(1);
	int amount = GetNativeCell(3);
	GetNativeString(2, itemshort, sizeof(itemshort));
	
	return RemoveInventoryItem(client, itemshort, amount);
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
	
	return view_as<int>(IsItemInInventory(client, itemshort));
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
	if (!client)
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
	else if (convar == g_cv_CreditLootMax || convar == g_cv_ItemLootMax)
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
		if (val < 0)
		{
			return;
		}
		
		if (convar == g_cv_CreditLootMax)
		{
			g_iCreditLootMax = val;
		}
		else
		{
			g_iItemLootMax = val;
		}
	}
	else if (convar == g_cv_CreditLootChance || convar == g_cv_ItemLootChance || convar == g_cv_LootChanceFallOff)
	{
		if (StrEqual(oldValue, newValue))
		{
			return;
		}
			
		if (!IsCharNumeric(newValue[0]) || !IsCharNumeric(newValue[2]))
		{
			return;
		}
			
		float val = StringToFloat(newValue);
		if (val < 0.0 || val > 1.0)
		{
			return;
		}
		
		if (convar == g_cv_CreditLootChance)
		{
			g_fCreditLootChance = val;
		}
		else if (convar == g_cv_ItemLootChance)
		{
			g_fItemLootChance = val;
		}
		else
		{
			g_fLootChanceFallOff = val;
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

bool AddInventoryItem(int client, const char[] itemshort, int quantity)
{
	if (!TTT_IsClientValid(client))
	{
		return false;
	}
	
	if (quantity <= 0)
	{
		return false;
	}
	
	return EditInventoryItem(client, itemshort, quantity);
}

bool RemoveInventoryItem(int client, const char[] itemshort, int amount = 0)
{
	if (!TTT_IsClientValid(client))
	{
		return false;
	}
	
	if (amount < 0)
	{
		return false;
	}
	
	return EditInventoryItem(client, itemshort, 0 - amount);
}

void CreateNewInventory(int client)
{
	any newInventory[eInventory];
	newInventory[userid] = GetClientUserId(client);
	newInventory[availableCredits] = 0;
	newInventory[hInventoryItems] = CreateTrie();
	
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
	
	CloseHandle(inventory[hInventoryItems]);
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