#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_bodies>
#include <ttt_inventory>

#undef REQUIRE_PLUGIN
#include <ttt_shop>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Inventory"

enum struct Inventory
{
    int UserID;
    int Credits;
    StringMap Items;
}

char g_sPluginTag[64];
ConVar g_cDebugMessages = null;

ConVar g_cPluginTag = null;
ConVar g_cEnableCreditLoot = null;
ConVar g_cEnableItemLoot = null;

GlobalForward g_fwOnInventoryReady = null;
GlobalForward g_fwOnInventoryMenuItemSelect = null;

StringMap g_smInventory = null;

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
    g_fwOnInventoryReady = new GlobalForward("TTT_OnInventoryReady", ET_Ignore);
    g_fwOnInventoryMenuItemSelect = new GlobalForward("TTT_OnInventoryMenuItemSelect", ET_Ignore, Param_Cell, Param_String);
    
    CreateNative("TTT_AddInventoryItem", Native_AddInventoryItem);
    CreateNative("TTT_RemoveInventoryItem", Native_RemoveInventoryItem);
    CreateNative("TTT_GetInventoryListing", Native_GetInventoryListing);
    CreateNative("TTT_IsItemInInventory", Native_IsItemInInventory);
    CreateNative("TTT_GetClientItemQuantity", Native_GetClientItemQuantity);
    
    RegPluginLibrary("ttt_inventory");
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    LoadTranslations("ttt.phrases");
    
    TTT_StartConfig("inventory");
    CreateConVar("ttt2_inventory_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cEnableCreditLoot = AutoExecConfig_CreateConVar("inventory_enable_loot_credit", "1", "Enables players to loot credits from dead bodies.");
    g_cEnableItemLoot = AutoExecConfig_CreateConVar("inventory_enable_loot_item", "1", "Enables players to loot items from dead bodies.");
    TTT_EndConfig();
    
    RegConsoleCmd("sm_inventory", Command_Inventory);
    
    HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConvarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cDebugMessages = FindConVar("ttt_show_debug_messages");
}

public Action Command_Inventory(int client, int args)
{
    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 1");
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 2");
    }
    
    if (TTT_GetRoundStatus() != Round_Active)
    {
        ReplyToCommand(client, "%T", "RoundInactive", client);
        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 3");
    }
    
    StringMap smInventory = GetPlayerInventory(client);
    if (smInventory == null)
    {
        ReplyToCommand(client, "%T", "InventoryNoItems", client);
        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 4");
    }
    
    Menu mMenu = new Menu(Menu_InventoryHandler);
    mMenu.SetTitle("%T", "InventoryTitle", client);

    bool bFound = false;

    StringMapSnapshot smsInventory = smInventory.Snapshot();

    for (int i = 0; i < smsInventory.Length; i++)
    {
        char sShort[16];
        smsInventory.GetKey(i, sShort, sizeof(sShort));
        
        int iAmount;
        smInventory.GetValue(sShort, iAmount);

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "Command_Inventory - 4.1 (sShort: %s, iAmount: %d)", sShort, iAmount);
        }
        
        char sLong[64];
        if (TTT_GetItemName(sShort, sLong, sizeof(sLong)))
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "Command_Inventory - 4.2 (sLong: %s, iAmount: %d)", sLong, iAmount);
            }
            char sDisplay[64];
            Format(sDisplay, sizeof(sDisplay), "%s (x%d)", sLong, iAmount);
            mMenu.AddItem(sShort, sDisplay);

            bFound = true;
        }
    }

    delete smsInventory;

    if (!bFound)
    {
        char sBuffer[48];
        Format(sBuffer, sizeof(sBuffer), "%T", "NoItems", client);
        mMenu.AddItem("noitems", sBuffer, ITEMDRAW_DISABLED);
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 5");
    }

    mMenu.Display(client, MENU_TIME_FOREVER);

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 6");
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Inventory - 7");
    }
    
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
                CPrintToChat(client, "%s %T", g_sPluginTag, "YouAreDead", client);
                return;
            }
            
            char sInfo[16];
            menu.GetItem(itemNum, sInfo, sizeof(sInfo));
            
            Call_StartForward(g_fwOnInventoryMenuItemSelect);
            Call_PushCell(client);
            Call_PushString(sInfo);
            Call_Finish();
        }
        
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective, int misc)
{
    ResetAndCreateInventories();
}

public void TTT_OnRoundEnd(int winner, int role, Handle array)
{
    ResetAndCreateInventories(false);
}

public Action TTT_OnBodyCheck(int client, int entityref)
{
    if (!g_cEnableCreditLoot.BoolValue && !g_cEnableItemLoot.BoolValue)
    {
        return Plugin_Continue;
    }

    if  (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }
    
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }
    
    Ragdoll body;
    TTT_GetEntityRefRagdoll(entityref, body);

    char sUserID[16];
    Inventory pInventory;
    
    IntToString(body.Victim, sUserID, sizeof(sUserID));
    if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        return Plugin_Continue;
    }
    
    StringMap smItems = pInventory.Items;
    if (smItems == null)
    {
        return Plugin_Continue;
    }
    
    int iCredits;
    int iItems;
    if (g_cEnableCreditLoot.BoolValue)
    {
        iCredits = pInventory.Credits;
        if (iCredits > 0)
        {
            TTT_AddClientCredits(client, iCredits);
            pInventory.Credits = 0;
        }
    }
    
    if (g_cEnableItemLoot.BoolValue)
    {
        StringMapSnapshot smsItems = smItems.Snapshot();
        for (int i = 0; i < smsItems.Length; i++)
        {
            char sKey[16];
            smsItems.GetKey(i, sKey, sizeof(sKey));
            
            int clientTeam = TTT_GetClientTeam(client);
            int itemTeam = TTT_GetItemTeam(sKey);
            if (clientTeam != itemTeam || itemTeam != TTT_TEAM_UNASSIGNED)
            {
                continue;
            }
            
            TTT_GiveClientItem(client, sKey);
            
            smItems.Remove(sKey);
            iItems++;
        }
        
        delete smsItems;
    }
    
    g_smInventory.SetArray(sUserID, pInventory, sizeof(pInventory));
    
    if (iCredits || iItems)
    {
        char sCurrency[SHOP_CURRENCY_LENGTH];
        TTT_GetClientCurrency(client, sCurrency, sizeof(sCurrency));

        CPrintToChat(client, "%s %T", g_sPluginTag, "SuccessfulLoot", client, iCredits, iItems, body.VictimName, sCurrency);
    }
    
    return Plugin_Continue;
}

public int Native_AddInventoryItem(Handle plugin, int numparams)
{
    char sShort[16];
    int client = GetNativeCell(1);
    GetNativeString(2, sShort, sizeof(sShort));
    int quantity = GetNativeCell(3);
    
    return EditInventoryItem(client, sShort, 1, quantity);
}

public int Native_RemoveInventoryItem(Handle plugin, int numparams)
{
    char sShort[16];
    int client = GetNativeCell(1);
    GetNativeString(2, sShort, sizeof(sShort));
    int quantity = GetNativeCell(3);
    
    return EditInventoryItem(client, sShort, 2, quantity);
}

public int Native_GetInventoryListing(Handle plugin, int numparams)
{
    int client = GetNativeCell(1);
    
    StringMap smInventory = GetPlayerInventory(client);
    
    if (smInventory == null)
    {
        return view_as<int>(INVALID_HANDLE);
    }
    
    return view_as<int>(smInventory.Snapshot());
}

public int Native_IsItemInInventory(Handle plugin, int numparams)
{
    char sShort[16];
    int client = GetNativeCell(1);
    
    GetNativeString(2, sShort, sizeof(sShort));
    
    return IsItemInInventory(client, sShort);
}

public int Native_GetClientItemQuantity(Handle plugin, int numparams)
{
    int client = GetNativeCell(1);

    StringMap smInventory = GetPlayerInventory(client);
    
    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));
    
    int iQuantity = -1;
    if (smInventory != null && smInventory.GetValue(sShort, iQuantity))
    {
        return iQuantity;
    }

    return iQuantity;
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
    if (g_smInventory == null)
    {
        return Plugin_Continue;
    }

    char sUserID[16];
    int iUserID = event.GetInt("userid");
    Inventory pInventory;
    
    IntToString(iUserID, sUserID, sizeof(sUserID));
    if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        return Plugin_Continue;
    }
    
    int client = GetClientOfUserId(iUserID);
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }
    
    pInventory.Credits = TTT_GetClientCredits(client);
    g_smInventory.SetArray(sUserID, pInventory, sizeof(pInventory));
    
    return Plugin_Continue;
}

public void OnConvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        strcopy(g_sPluginTag, sizeof(g_sPluginTag), newValue);
    }
}

bool IsItemInInventory(int client, const char[] itemshort)
{
    Inventory pInventory;
    char sUserID[16];

    if (g_smInventory == null)
    {
        return false;
    }
    
    IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
    if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        return false;
    }
    
    StringMap smInventory = pInventory.Items;
    if (smInventory == null)
    {
        return false;
    }
    
    int amount;
    if (smInventory.GetValue(itemshort, amount))
    {
        return true;
    }
    
    return false;
}

/*
    type:
        - 0 - Set
        - 1 - Add
        - 2 - Remove

*/
bool EditInventoryItem(int client, const char[] itemshort, int type, int quantity)
{
    Inventory pInventory;
    bool all = false;
    char sUserID[16];

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 1");
    }
    
    if (quantity == 0)
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 1.1");
        }
        all = true;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 2");
    }
    
    IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
    if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 2.1");
        }
        if (quantity <= 0)
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "EditInventoryItem - 2.1.1");
            }
            return true;
        }

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 2.2");
        }
        return false;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 3");
    }
    
    StringMap smInventory = pInventory.Items;
    if (smInventory == null)
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 3.1");
        }
        if (quantity <= 0)
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "EditInventoryItem - 3.1.1");
            }
            return true;
        }
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 3.2");
        }
        return false;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 4");
    }
    
    int amount;
    if (!smInventory.GetValue(itemshort, amount))
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 4.1");
        }
        if (quantity <= 0)
        {
            if (g_cDebugMessages.BoolValue)
            {
                PrintToChat(client, "EditInventoryItem - 4.1.1");
            }
            return true;
        }

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 4.2 (itemshort: %s, quantity: %d", itemshort, quantity);
        }
        return smInventory.SetValue(itemshort, quantity);
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 5");
    }
    
    if (type == 0)
    {
        amount = quantity;
    }
    else if (type == 1)
    {
        amount += quantity;
    }
    else if (type == 2)
    {
        amount -= quantity;
    }

    if (amount <= 0 || all)
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "EditInventoryItem - 5.1");
        }
        smInventory.Remove(itemshort);
        return true;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "EditInventoryItem - 6");
    }
    
    smInventory.SetValue(itemshort, amount);
    return true;
}

void CreateNewInventory(int client)
{
    Inventory pInventory;
    pInventory.UserID = GetClientUserId(client);
    pInventory.Credits = 0;
    pInventory.Items = new StringMap();
    
    char key[16];
    IntToString(pInventory.UserID, key, sizeof(key));
    ClearInventory(key);
    
    g_smInventory.SetArray(key, pInventory, sizeof(pInventory));
}

void ClearInventory(const char[] sUserID)
{
    Inventory pInventory;
    if (g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        delete pInventory.Items;
        g_smInventory.Remove(sUserID);
    }
}

StringMap GetPlayerInventory(int client, bool isuserid = false)
{
    char sUserID[16];
    if (!isuserid)
    {
        if (!TTT_IsClientValid(client))
        {
            return null;
        }
        
        IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
    }
    else
    {
        IntToString(client, sUserID, sizeof(sUserID));
    }
    
    Inventory pInventory;
    if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
    {
        return null;
    }
    
    return pInventory.Items;
}

void ResetAndCreateInventories(bool create = true)
{
    //Reset Inventories
    if (g_smInventory != null)
    {
        StringMapSnapshot smsIventory = g_smInventory.Snapshot();
        for (int i = 0; i < smsIventory.Length; i++)
        {
            char sKey[16];
            smsIventory.GetKey(i, sKey, sizeof(sKey));
            
            ClearInventory(sKey);
        }

        delete smsIventory;
    }

    delete g_smInventory;
    
    if (create)
    {
        g_smInventory = new StringMap();

        LoopValidClients(client)
        {
            CreateNewInventory(client);
        }
        
        Call_StartForward(g_fwOnInventoryReady);
        Call_Finish();
    }
}

public void TTT_OnItemRemove(const char[] itemshort)
{
    LoopValidClients(client)
    {
        char sUserID[16];
        Inventory pInventory;
        
        IntToString(client, sUserID, sizeof(sUserID));
        if (!g_smInventory.GetArray(sUserID, pInventory, sizeof(pInventory)))
        {
            return;
        }
        
        StringMap smItems = pInventory.Items;
        if (smItems == null)
        {
            return;
        }

        StringMapSnapshot smsItems = smItems.Snapshot();
        char sKey[16];

        for (int i = 0; i < smsItems.Length; i++)
        {
            smsItems.GetKey(i, sKey, sizeof(sKey));
            
            if (StrEqual(sKey, itemshort, false))
            {
                smItems.Remove(sKey);
            }
        }

        delete smsItems;
    }
}
