#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorlib>
#include <clientprefs>
#include <ttt>
#include <ttt_sql>
#include <ttt_shop>
#include <ttt_inventory>

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

bool g_bItemReady = false;
bool g_bHasRegisteredCommands = false;

ArrayList g_aShopItems = null;

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
ConVar g_cCreditsIM = null;
ConVar g_cCreditsTI = null;
ConVar g_cCreditsTT = null;
ConVar g_cCreditsTD = null;
ConVar g_cCreditsTM = null;
ConVar g_cCreditsDI = null;
ConVar g_cCreditsDT = null;
ConVar g_cCreditsDD = null;
ConVar g_cCreditsDM = null;
ConVar g_cCreditsMI = null;
ConVar g_cCreditsMT = null;
ConVar g_cCreditsMD = null;
ConVar g_cCreditsMM = null;
ConVar g_cTraitorloseAliveNonTraitors = null;
ConVar g_cTraitorloseDeadNonTraitors = null;
ConVar g_cTraitorwinAliveTraitors = null;
ConVar g_cTraitorwinDeadTraitors = null;
ConVar g_cCreditsFoundBody = null;
ConVar g_cCreditsFoundBodyTeam = null;
ConVar g_cMessageTypCredits = null;
ConVar g_cStartCredits = null;
ConVar g_cCreditsMin = null;
ConVar g_cCreditsMax = null;
ConVar g_cCreditsInterval = null;
ConVar g_cSQLCredits = null;
ConVar g_cSilentIdRewards = null;
ConVar g_cMoneyCredits = null;
ConVar g_cCreditsFlag = null;
ConVar g_cGiveItemFlag = null;
ConVar g_cSetCreditsFlag = null;
ConVar g_cResetItemsFlag = null;
ConVar g_cListItemsFlag = null;
ConVar g_cDiscountReloadFlag = null;
ConVar g_cFlagsReloadFlag = null;
ConVar g_cShopCMDs = null;
ConVar g_cItemsMenu = null;
ConVar g_cShopMenuTime = null;
ConVar g_cAddLogs = null;
ConVar g_cLogFormat = null;
ConVar g_cTestingMode = null;
ConVar g_cLogPurchases = null;
ConVar g_cMaxSQLCredits = null;
ConVar g_cMaxVIPSQLCredits = null;
ConVar g_cOpenShopPlayerPing = null;

ConVar g_cDebugMessages = null;
ConVar g_cPluginTag = null;
char g_sPluginTag[64];

GlobalForward g_fwOnItemPurchased = null; // Deprecated as of c6b65e.
GlobalForward g_fwOnItemPurchase = null; // Deprecated as of c6b65e.
GlobalForward g_fwOnItemPurchasePost = null;
GlobalForward g_fwOnItemPurchasePre = null;
GlobalForward g_fwOnCreditsGiven_Pre = null;
GlobalForward g_fwOnCreditsGiven = null;
GlobalForward g_fwOnShopReady = null;
GlobalForward g_fwRegisterShopItemPost = null;
GlobalForward g_fwOnStartCredits = null;
GlobalForward g_fwOnItemRemove = null;

Cookie g_coReopen = null;

Database g_dDB = null;

char g_sLog[PLATFORM_MAX_PATH + 1];
char g_sDiscountFile[PLATFORM_MAX_PATH + 1];
char g_sFlagsFile[PLATFORM_MAX_PATH + 1];

int g_iCommands = -1;
char g_sCommandList[6][32];

StringMap g_smDiscountPercent = null;
StringMap g_smDiscountFlag = null;
StringMap g_smAccessFlag = null;
StringMap g_smPurchases = null;

enum struct Item
{
    char Long[SHOP_ITEM_NAME_LONG];
    char Short[SHOP_ITEM_NAME_SHORT];
    int Price;
    int Team;
    int Sort;
    int MaxUsages;
    int Limit;
    Handle Plugin;
    Function Callback;
    bool Logging;
}

enum struct PlayerData {
    int Credits;

    bool Ready;
    bool Reopen;

    char Currency[SHOP_CURRENCY_LENGTH];

    Handle Timer;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];
StringMap g_smUsages[MAXPLAYERS + 1] = { null, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnItemPurchased = new GlobalForward("TTT_OnItemPurchased", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_String);
    g_fwOnItemPurchase = new GlobalForward("TTT_OnItemPurchase", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_String);
    g_fwOnItemPurchasePost = new GlobalForward("TTT_OnItemPurchasePost", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_String);
    g_fwOnItemPurchasePre = new GlobalForward("TTT_OnItemPurchasePre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_String);
    g_fwOnCreditsGiven_Pre = new GlobalForward("TTT_OnCreditsChanged_Pre", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
    g_fwOnCreditsGiven = new GlobalForward("TTT_OnCreditsChanged", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnShopReady = new GlobalForward("TTT_OnShopReady", ET_Ignore);
    g_fwRegisterShopItemPost = new GlobalForward("TTT_OnRegisterShopItemPost", ET_Ignore, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnStartCredits = new GlobalForward("TTT_OnStartCredits", ET_Event, Param_Cell, Param_CellByRef);
    g_fwOnItemRemove = new GlobalForward("TTT_OnItemRemove", ET_Ignore, Param_String);

    CreateNative("TTT_RegisterShopItem", Native_RegisterShopItem);
    CreateNative("TTT_GetItemPrice", Native_GetItemPrice);
    CreateNative("TTT_GetItemTeam", Native_GetItemTeam);
    CreateNative("TTT_UpdateShopItem", Native_UpdateShopItem);
    CreateNative("TTT_RemoveShopItem", Native_RemoveShopItem);
    CreateNative("TTT_GetItemName", Native_GetItemName);
    CreateNative("TTT_ShopItemExist", Native_ShopItemExist);
    CreateNative("TTT_GetItemMaxUsages", Native_GetItemMaxUsages);
    CreateNative("TTT_GetItemLimit", Native_GetItemLimit);

    CreateNative("TTT_GetClientCredits", Native_GetClientCredits);
    CreateNative("TTT_SetClientCredits", Native_SetClientCredits);
    CreateNative("TTT_AddClientCredits", Native_AddClientCredits);
    CreateNative("TTT_GiveClientItem", Native_GiveClientItem);
    CreateNative("TTT_GetItemUsages", Native_GetItemUsages);
    CreateNative("TTT_AddItemUsage", Native_AddItemUsage);
    CreateNative("TTT_RemoveItemUsage", Native_RemoveItemUsage);
    CreateNative("TTT_SetItemUsage", Native_SetItemUsage);

    CreateNative("TTT_GetItemDiscount", Native_GetItemDiscount);
    CreateNative("TTT_CheckItemAccess", Native_CheckItemAccess);

    CreateNative("TTT_GetClientCurrency", Native_GetClientCurrency);

    RegPluginLibrary("ttt_shop");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    RegConsoleCmd("sm_reopenshop", Command_ReopenShop);
    RegConsoleCmd("sm_roshop", Command_ReopenShop);
    RegConsoleCmd("sm_reshop", Command_ReopenShop);
    RegConsoleCmd("sm_rshop", Command_ReopenShop);
    RegConsoleCmd("sm_giveitem", Command_GiveItem);
    RegConsoleCmd("sm_setcredits", Command_SetCredits);
    RegConsoleCmd("sm_resetitems", Command_ResetItems);
    RegConsoleCmd("sm_listitems", Command_ListItems);
    RegConsoleCmd("sm_reload_discount", Command_ReloadDiscount);
    RegConsoleCmd("sm_reload_flags", Command_ReloadFlag);

    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
    AddCommandListener(Listener_PlayerPing, "player_ping");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);

    TTT_StartConfig("shop");
    CreateConVar("ttt2_shop_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cSortItems = AutoExecConfig_CreateConVar("ttt_sort_items", "1", "Sort shop items? 0 = Disabled. 1 = Enabled (default).", _, true, 0.0, true, 1.0);
    g_cCreditsII = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_innocent_subtract", "1500", "The amount of credits an innocent will lose for killing an innocent.");
    g_cCreditsIT = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_traitor_add", "3000", "The amount of credits an innocent will recieve when killing a traitor.");
    g_cCreditsID = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_detective_subtract", "4200", "The amount of credits an innocent will lose for killing a detective.");
    g_cCreditsIM = AutoExecConfig_CreateConVar("ttt_credits_killer_innocent_victim_misc_subtract", "1500", "The amount of credits an innocent will lose for killing a misc.");
    g_cCreditsTI = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_innocent_add", "600", "The amount of credits a traitor will recieve for killing an innocent.");
    g_cCreditsTT = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_traitor_subtract", "3000", "The amount of credits a traitor will lose for killing a traitor.");
    g_cCreditsTD = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_detective_add", "4200", "The amount of credits a traitor will recieve for killing a detective.");
    g_cCreditsTM = AutoExecConfig_CreateConVar("ttt_credits_killer_traitor_victim_misc_add", "0", "The amount of credits a traitor will recieve for killing a misc.");
    g_cCreditsDI = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_innocent_subtract", "300", "The amount of credits a detective will lose for killing an innocent.");
    g_cCreditsDT = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_traitor_add", "2100", "The amount of credits a detective will recieve for killing a traitor.");
    g_cCreditsDD = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_detective_subtract", "300", "The amount of credits a detective will lose for killing a detective.");
    g_cCreditsDM = AutoExecConfig_CreateConVar("ttt_credits_killer_detective_victim_misc_subtract", "300", "The amount of credits a detective will lose for killing a misc.");
    g_cCreditsMI = AutoExecConfig_CreateConVar("ttt_credits_killer_misc_victim_innocent_subtract", "0", "The amount of credits a detective will lose for killing an innocent.");
    g_cCreditsMT = AutoExecConfig_CreateConVar("ttt_credits_killer_misc_victim_traitor_add", "0", "The amount of credits a detective will recieve for killing a traitor.");
    g_cCreditsMD = AutoExecConfig_CreateConVar("ttt_credits_killer_misc_victim_detective_subtract", "0", "The amount of credits a detective will lose for killing a detective.");
    g_cCreditsMM = AutoExecConfig_CreateConVar("ttt_credits_killer_misc_victim_misc_subtract", "0", "The amount of credits a detective will lose for killing a misc.");
    g_cTraitorloseAliveNonTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorlose_alive_nontraitors", "4800", "The amount of credits an innocent or detective will recieve for winning the round if they survived.");
    g_cTraitorloseDeadNonTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorlose_dead_nontraitors", "1200", "The amount of credits an innocent or detective will recieve for winning the round if they died.");
    g_cTraitorwinAliveTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorwin_alive_traitors", "4800", "The amount of credits a traitor will recieve for winning the round if they survived.");
    g_cTraitorwinDeadTraitors = AutoExecConfig_CreateConVar("ttt_credits_roundend_traitorwin_dead_traitors", "1200", "The amount of credits a traitor will recieve for winning the round if they died.");
    g_cCreditsFoundBody = AutoExecConfig_CreateConVar("ttt_credits_found_body_add", "1200", "The amount of credits the player will recieve for discovering a new dead body.");
    g_cCreditsFoundBodyTeam = AutoExecConfig_CreateConVar("ttt_credits_found_body_add_team", "6", "How can gain credits for identifing a dead body?\nPlease read this before you this: https://github.com/TroubleInTerroristTown/Public/wiki/CVAR-Masks");
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
    g_cSQLCredits = AutoExecConfig_CreateConVar("ttt_sql_credits", "0", "Set 1 if you want to use credits over sql (mysql + sqlite are supported)", _, true, 0.0, true, 1.0);
    g_cSilentIdRewards = AutoExecConfig_CreateConVar("ttt_shop_silent_id_rewards", "1", "0 = Disabled, will not reward credits with silent id. 1 = Will reward the client with credits for inspecting the body.", _, true, 0.0, true, 1.0);
    g_cMoneyCredits = AutoExecConfig_CreateConVar("ttt_shop_show_credits_as_money", "1", "Show player credits as csgo money?", _, true, 0.0, true, 1.0);
    g_cCreditsFlag = AutoExecConfig_CreateConVar("ttt_shop_credits_vip", "a", "VIP flag to earn more more credits (look at ttt_shop_max_vip_sql_credits)");
    g_cGiveItemFlag = AutoExecConfig_CreateConVar("ttt_shop_give_item_flag", "z", "Admin flags to give players shop items");
    g_cSetCreditsFlag = AutoExecConfig_CreateConVar("ttt_shop_set_credits_flag", "z", "Admin flags to set players credits");
    g_cResetItemsFlag = AutoExecConfig_CreateConVar("ttt_shop_reset_items_flag", "z", "Admin flags to reset all items from shop (Reload)");
    g_cListItemsFlag = AutoExecConfig_CreateConVar("ttt_shop_list_items_flag", "z", "Admin flags to list all items from shop");
    g_cDiscountReloadFlag = AutoExecConfig_CreateConVar("ttt_shop_discount_reload_flag", "z", "Which flags to get access for reloading the discount file? (Default: z)");
    g_cFlagsReloadFlag = AutoExecConfig_CreateConVar("ttt_shop_flags_reload_flag", "z", "Which flags to get access for reloading the flag file? (Default: z)");
    g_cShopCMDs = AutoExecConfig_CreateConVar("ttt_shop_commands", "shop;menu", "Commands for ttt shop (up to 6 commands)");
    g_cItemsMenu = AutoExecConfig_CreateConVar("ttt_hide_disable_items_menu", "0", "How should unavailable (not enough credits or max usages reached) items be handled? (0 - Enabled with text message (default), 1 - Disable item in menu, 2 - Hide item in menu", _, true, 0.0, true, 2.0);
    g_cShopMenuTime = AutoExecConfig_CreateConVar("ttt_shop_menu_time", "15", "How long shop menu should be displayed.");
    g_cTestingMode = AutoExecConfig_CreateConVar("ttt_enable_testing_mode", "0", "Enable testing mode for shop? All items will be free without any limits!", _, true, 0.0, true, 1.0);
    g_cLogPurchases = AutoExecConfig_CreateConVar("ttt_shop_log_purchases", "2", "Logs purchases of shop items (0 = off, 1 = all, 2 = detective/traitor only", _, true, 0.0, true, 2.0);
    g_cMaxSQLCredits = AutoExecConfig_CreateConVar("ttt_shop_max_sql_credits", "0", "Limit the max possible credits if ttt_sql_credits is 1", _, true, 0.0);
    g_cMaxVIPSQLCredits = AutoExecConfig_CreateConVar("ttt_shop_max_vip_sql_credits", "0", "Limit the max possible vip credits if ttt_sql_credits is 1", _, true, 0.0);
    g_cOpenShopPlayerPing = AutoExecConfig_CreateConVar("ttt_open_shop_player_ping", "1", "Open shop when player use the command \"player_ping\"? (0 - No, 1 - Yes)", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    LoadTranslations("common.phrases");
    TTT_LoadTranslations();

    char sDate[12];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
    BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/ttt/shop_%s.log", sDate);

    BuildPath(Path_SM, g_sDiscountFile, sizeof(g_sDiscountFile), "configs/ttt/shop_discounts.ini");
    BuildPath(Path_SM, g_sFlagsFile, sizeof(g_sFlagsFile), "configs/ttt/shop_flags.ini");

    g_coReopen = new Cookie("ttt_reopen_shop", "Cookie to reopen shop menu", CookieAccess_Private);

    if (TTT_GetSQLConnection() != null)
    {
        g_dDB = TTT_GetSQLConnection();
        AlterCreditsColumn();
    }
}

public void OnMapEnd()
{
    ResetItemsArray("OnMapEnd", false);
}

public void OnConfigsExecuted()
{
    RemoveOldPlugins("ttt_shop_discount");
    RemoveOldPlugins("ttt_shop_flags");

    // Get some values from ttt.cfg
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cAddLogs = FindConVar("ttt_steamid_add_to_logs");
    g_cLogFormat = FindConVar("ttt_steamid_log_format");

    char sBuffer[32];
    g_cCredits.GetString(sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);

    if (!g_bHasRegisteredCommands)
    {
        if(!CommandExists(sBuffer))
        {
            RegConsoleCmd(sBuffer, Command_Credits);
        }

        g_cBuyCmd.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);

        if(!CommandExists(sBuffer))
        {
            RegConsoleCmd(sBuffer, Command_Buy);
        }

        g_cShowCmd.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "sm_%s", sBuffer);

        if(!CommandExists(sBuffer))
        {
            RegConsoleCmd(sBuffer, Command_ShowItems);
        }

        char sCVarCMD[64];
        g_cShopCMDs.GetString(sCVarCMD, sizeof(sCVarCMD));

        g_iCommands = ExplodeString(sCVarCMD, ";", g_sCommandList, sizeof(g_sCommandList), sizeof(g_sCommandList[]));

        for (int i = 0; i < g_iCommands; i++)
        {
            char sCommand[32];
            Format(sCommand, sizeof(sCommand), "sm_%s", g_sCommandList[i]);
            RegConsoleCmd(sCommand, Command_Shop);
        }

        g_bHasRegisteredCommands = true;
    }

    LoopValidClients(i)
    {
            OnClientCookiesCached(i);

            if (g_cSQLCredits.BoolValue && g_dDB != null)
            {
                LoadClientCredits(i);
            }
    }

    LoadShopFile(g_sDiscountFile);
    LoadShopFile(g_sFlagsFile);

    g_cDebugMessages = FindConVar("ttt_show_debug_messages");

    ResetItemsArray("OnConfigsExecuted", true);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

void LoadShopFile(const char[] sFile)
{
    delete g_smDiscountPercent;
    delete g_smDiscountFlag;
    delete g_smAccessFlag;

    Handle hFile = OpenFile(sFile, "rt");

    if (hFile == null)
    {
        SetFailState("[TTT] Can't open File: %s", sFile);
        return;
    }

    KeyValues kvValues;

    if (StrEqual(sFile, g_sDiscountFile))
    {
        kvValues = new KeyValues("Shop-Discount");
    }
    else if (StrEqual(sFile, g_sFlagsFile))
    {
        kvValues = new KeyValues("Shop-Flags");
    }
    else
    {
        delete kvValues;
        delete hFile;
        return;
    }

    if (!kvValues.ImportFromFile(sFile))
    {
        SetFailState("Can't read %s correctly! (ImportFromFile)", sFile);
        delete kvValues;
        delete hFile;
        return;
    }

    if (!kvValues.GotoFirstSubKey())
    {
        SetFailState("Can't read %s correctly! (GotoFirstSubKey)", sFile);
        delete kvValues;
        delete hFile;
        return;
    }

    g_smDiscountPercent = new StringMap();
    g_smDiscountFlag = new StringMap();
    g_smAccessFlag = new StringMap();

    if (StrEqual(sFile, g_sDiscountFile))
    {
        do
        {
            char sShort[16];
            int iPercent;
            char sFlag[16];

            kvValues.GetSectionName(sShort, sizeof(sShort));
            iPercent = kvValues.GetNum("percentage");
            kvValues.GetString("flag", sFlag, sizeof(sFlag));

            if (strlen(sShort) > 1 && iPercent >= 1 && iPercent <= 100)
            {
                g_smDiscountPercent.SetValue(sShort, iPercent, true);
                g_smDiscountFlag.SetString(sShort, sFlag, true);
            }
        }
        while (kvValues.GotoNextKey());
    }
    else if (StrEqual(sFile, g_sFlagsFile))
    {
        do
        {
            char sShort[16];
            char sFlag[16];

            kvValues.GetSectionName(sShort, sizeof(sShort));
            kvValues.GetString("flag", sFlag, sizeof(sFlag));

            if (strlen(sShort) > 1)
            {
                g_smAccessFlag.SetString(sShort, sFlag, true);
            }
        }
        while (kvValues.GotoNextKey());
    }

    delete kvValues;
    delete hFile;
}

public void TTT_OnSQLConnect(Database db)
{
    g_dDB = db;
    AlterCreditsColumn();
}

void AlterCreditsColumn()
{
    if (g_dDB != null)
    {
        char sQuery[72];
        Format(sQuery, sizeof(sQuery), "ALTER TABLE `ttt` ADD COLUMN `credits` INT(11) NOT NULL DEFAULT 0;");
        g_dDB.Query(SQL_AlterCreditsColumn, sQuery);
    }
    else
    {
        SetFailState("Database handle is invalid!");
        return;
    }
}

public void SQL_AlterCreditsColumn(Database db, DBResultSet results, const char[] error, any userid)
{
    if (db == null || strlen(error) > 0)
    {
        if (StrContains(error, "duplicate column name", false) != -1)
        {
            LoadClientCredits(GetClientOfUserId(userid));
        }
        else
        {
            LogError("(SQL_AlterCreditsColumn) Query failed: %s", error);
        }

        return;
    }
    else
    {
        LoadClientCredits(GetClientOfUserId(userid));
    }
}

void LoadClientCredits(int client)
{
    if (TTT_IsClientValid(client) && !IsFakeClient(client))
    {
        if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
        {
            LogMessage("(LoadClientCredits) Client: \"%L\"", client);
        }

        char sCommunityID[64];

        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            LogError("(LoadClientCredits) Auth failed: #%d", client);
            return;
        }

        char sQuery[2048];
        Format(sQuery, sizeof(sQuery), "SELECT `credits` FROM `ttt` WHERE `communityid`= \"%s\";", sCommunityID);

        if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
        {
            LogMessage(sQuery);
        }

        if (g_dDB != null)
        {
            g_dDB.Query(SQL_OnClientPostAdminCheck, sQuery, GetClientUserId(client));
        }
    }
}

public void SQL_OnClientPostAdminCheck(Database db, DBResultSet results, const char[] error, any userid)
{
    int client = GetClientOfUserId(userid);

    if (!client || !TTT_IsClientValid(client) || IsFakeClient(client))
    {
        return;
    }

    if (db == null || strlen(error) > 0)
    {
        LogError("(SQL_OnClientPostAdminCheck) Query failed: %s", error);
        return;
    }
    else
    {
        if (results.RowCount > 0 && results.FetchRow())
        {
            char sCommunityID[64];

            if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
            {
                LogError("(SQL_OnClientPostAdminCheck) Auth failed: #%d", client);
                return;
            }

            int credits = results.FetchInt(0);

            if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
            {
                LogMessage("Name: %L has %d credits", client, credits);
            }

            if (credits == 0)
            {
                g_iPlayer[client].Credits = g_cStartCredits.IntValue;
            }
            else
            {
                g_iPlayer[client].Credits = credits;
            }

            if (g_cMoneyCredits.BoolValue)
            {
                SetEntProp(client, Prop_Send, "m_iAccount", g_iPlayer[client].Credits);
            }

            g_iPlayer[client].Ready = true;
        }
        else
        {
            g_iPlayer[client].Credits = g_cStartCredits.IntValue;
            UpdatePlayer(client);
        }
    }
}

void UpdatePlayer(int client)
{
    char sCommunityID[64];

    if (IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("(UpdatePlayer) Auth failed: #%d", client);
        return;
    }

    char sQuery[2048];
    Format(sQuery, sizeof(sQuery), "INSERT INTO ttt (communityid, credits) VALUES (\"%s\", %d) ON DUPLICATE KEY UPDATE credits = %d;", sCommunityID, g_iPlayer[client].Credits, g_iPlayer[client].Credits);

    if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
    {
        LogMessage(sQuery);
    }

    if (g_dDB != null)
    {
        g_dDB.Query(SQL_UpdatePlayer, sQuery, GetClientUserId(client));
    }

    if (g_cMoneyCredits.BoolValue)
    {
        SetEntProp(client, Prop_Send, "m_iAccount", g_iPlayer[client].Credits);
    }
}

public void SQL_UpdatePlayer(Database db, DBResultSet results, const char[] error, any userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("(SQL_UpdatePlayer) Query failed: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (TTT_IsClientValid(client))
        {
            g_iPlayer[client].Ready = true;
        }
    }
}

public void OnClientCookiesCached(int client)
{
    if (AreClientCookiesCached(client))
    {
        char sBuffer[4];
        g_coReopen.Get(client, sBuffer, sizeof(sBuffer));
        g_iPlayer[client].Reopen = view_as<bool>(StringToInt(sBuffer));
    }
    else
    {
        char sBuffer[4];
        IntToString(view_as<int>(true), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
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
        ClientBuyItem(client, sItem, false);
    }

    return Plugin_Handled;
}

public Action Command_ShowItems(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strlen(item.Short) > 1)
        {
            PrintToConsole(client, "Name: %s (%s) - Teams: %d - Price: %i - Max Usages: %d, Limit: %d", item.Long, item.Short, item.Team, item.Price, item.MaxUsages, item.Limit);
        }
    }
    return Plugin_Handled;
}

public Action Command_Shop(int client, int args)
{
    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Shop - 0 - Start");
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Shop - 1 - Client valid");
    }

    if (TTT_GetRoundStatus() != Round_Active)
    {
        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "Can not open shop. Round status: %d", TTT_GetRoundStatus());
        }

        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Shop - 2 - Round valid");
    }

    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "YouAreDead", client);
        return Plugin_Handled;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Command_Shop - 3 - Yeah, you're alive! (Team: %d", TTT_GetClientTeam(client));
    }

    int iTeam = TTT_GetClientTeam(client);
    if (iTeam != TTT_TEAM_UNASSIGNED)
    {
        Menu menu = new Menu(Menu_ShopHandler);
        menu.SetTitle("%T", "TTT Shop", client, g_iPlayer[client].Credits, g_iPlayer[client].Currency);

        char sDisplay[128];
        Item item;
        int iCount = 0;

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "Command_Shop - 4 - Items: %d", g_aShopItems.Length);
        }

        for (int i = 0; i < g_aShopItems.Length; i++)
        {
            g_aShopItems.GetArray(i, item);
            if (strlen(item.Short) > 1)
            {
                if (g_cDebugMessages.BoolValue)
                {
                    PrintToChat(client, "Command_Shop - 5 - Item: %s", item.Short);
                }

                if ((item.Team == 1) || (item.Team == iTeam))
                {
                    int iPrice = item.Price;

                    bool bAvailable = true;

                    if (!TTT_CheckItemAccess(client, item.Short))
                    {
                        bAvailable = false;
                    }

                    bool bDiscount = false;
                    int iPercents = TTT_GetItemDiscount(client, item.Short);

                    if (iPercents > 0)
                    {
                        float fPercentage = iPercents / 100.0;
                        int iDiscount = RoundToCeil(iPrice * fPercentage);
                        iPrice = item.Price - iDiscount;
                        bDiscount = true;
                    }

                    if (iPrice > g_iPlayer[client].Credits)
                    {
                        bAvailable = false;
                    }

                    int iPurchases = -1;
                    g_smPurchases.GetValue(item.Short, iPurchases);

                    if (item.Limit > 0 && iPurchases >= item.Limit)
                    {
                        bAvailable = false;
                    }

                    // We don't need to check this anymore, if it's unavailable
                    if (bAvailable && g_smUsages[client] != null)
                    {
                        int iUsages;
                        g_smUsages[client].GetValue(item.Short, iUsages);

                        if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
                        {
                            PrintToChat(client, "(Command_Shop) Usages: %d", iUsages);
                        }

                        if (iUsages >= item.MaxUsages)
                        {
                            bAvailable = false;
                        }
                    }

                    if (g_cItemsMenu.IntValue == 2 && !bAvailable)
                    {
                        continue;
                    }

                    if (bDiscount)
                    {
                        Format(sDisplay, sizeof(sDisplay), "%s - %d %T", item.Long, iPrice, "Shop Discount Price", client, iPercents);
                    }
                    else
                    {
                        Format(sDisplay, sizeof(sDisplay), "%s - %d", item.Long, iPrice);
                    }

                    if (g_cItemsMenu.IntValue == 1 && !bAvailable)
                    {
                        menu.AddItem(item.Short, sDisplay, ITEMDRAW_DISABLED);
                    }
                    else
                    {
                        menu.AddItem(item.Short, sDisplay);
                    }

                    iCount++;
                }
            }
        }

        menu.ExitButton = true;

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChat(client, "Command_Shop - X - Valid items: %d", iCount);
        }

        if (iCount > 0)
        {
            menu.Display(client, g_cShopMenuTime.IntValue);
        }
        else
        {
            delete menu;
        }
    }
    else
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Please wait till your team is assigned", client);
    }

    return Plugin_Handled;

}

public Action Listener_PlayerPing(int client, const char[] command, int args)
{
    if (g_cOpenShopPlayerPing.BoolValue)
    {
        Command_Shop(client, 0);
    }
    
    return Plugin_Continue;
}

public Action Command_ReopenShop(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_iPlayer[client].Reopen)
    {
        g_iPlayer[client].Reopen = false;

        CPrintToChat(client, "%s %T", g_sPluginTag, "Reopen Shop deactivated", client);

        char sBuffer[4];
        IntToString(view_as<int>(g_iPlayer[client].Reopen), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
    }
    else
    {
        g_iPlayer[client].Reopen = true;

        CPrintToChat(client, "%s %T", g_sPluginTag, "Reopen Shop activated", client);

        char sBuffer[4];
        IntToString(view_as<int>(g_iPlayer[client].Reopen), sBuffer, sizeof(sBuffer));
        g_coReopen.Set(client, sBuffer);
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
            return 0;
        }

        char info[32];
        menu.GetItem(itemNum, info, sizeof(info));

        ClientBuyItem(client, info, true);
    }

    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

bool ClientBuyItem(int client, char[] sItem, bool menu, bool free = false)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return false;
    }

    if (g_cTestingMode.BoolValue)
    {
        free = true;
    }

    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if ((strlen(item.Short) > 0) && (strcmp(sItem, item.Short) == 0) && ((item.Team == 1) || (TTT_GetClientTeam(client) == item.Team)))
        {
            int iPrice = 0;

            if (!free)
            {
                iPrice = item.Price;
            }

            if (!g_cTestingMode.BoolValue && item.MaxUsages == 0)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Item Disabled - MaxUsages", client, item.Long);
                return false;
            }

            int iPurchases = -1;
            g_smPurchases.GetValue(item.Short, iPurchases);

            if (item.Limit > 0 && iPurchases >= item.Limit)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Global Limit Reached", client, item.Long, item.Limit);
                return false;
            }

            if (g_smUsages[client] == null)
            {
                g_smUsages[client] = new StringMap();
                g_smUsages[client].SetValue(item.Short, 0);
            }

            int iUsages = 0;
            if (!g_cTestingMode.BoolValue && g_smUsages[client] != null)
            {
                g_smUsages[client].GetValue(item.Short, iUsages);

                if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
                {
                    PrintToChat(client, "(ClientBuyItem) Usages: %d (Item Max: %d)", iUsages, item.MaxUsages);
                }

                if (iUsages >= item.MaxUsages)
                {
                    CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Usage Limit Reached", client, item.Long, item.MaxUsages);
                    return false;
                }
            }

            int iQuantity = TTT_GetClientItemQuantity(client, item.Short);

            int iMax = iQuantity + iUsages;
            if (!g_cTestingMode.BoolValue && iMax >= item.MaxUsages)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Shop: Purchase Limit", client, item.MaxUsages);
                return false;
            }

            int count = 1;

            Action result = Plugin_Continue;

            Call_StartForward(g_fwOnItemPurchase);  // Deprecated as of c6b65e.
            Call_PushCell(client);                  //
            Call_PushCellRef(iPrice);               //
            Call_PushCellRef(count);                //
            Call_PushString(item.Short);            //
            Call_Finish(result);                    //

            Call_StartForward(g_fwOnItemPurchasePre);
            Call_PushCell(client);
            Call_PushCellRef(iPrice);
            Call_PushCellRef(count);
            Call_PushString(item.Short);
            Call_Finish(result);

            if (result == Plugin_Stop || result == Plugin_Handled)
            {
                return false;
            }

            if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
            {
                if (CheckCommandAccess(client, "ttt_root", ADMFLAG_ROOT, true))
                {
                    PrintToChat(client, "Item: %s Shop Price: %d Price: %d, Max Usages: %d, Limit: %d", item.Long, item.Price, iPrice, item.MaxUsages, item.Limit);
                }
            }

            if ((!free && g_iPlayer[client].Credits >= iPrice) || (free && iPrice == 0))
            {
                Action res = Plugin_Continue;
                Call_StartFunction(item.Plugin, item.Callback);
                Call_PushCell(client);
                Call_PushString(item.Short);
                Call_PushCell(count);
                Call_PushCell(iPrice);
                Call_Finish(res);

                if (res < Plugin_Stop)
                {
                    setCredits(client, (g_iPlayer[client].Credits - iPrice));

                    if (!free)
                    {
                        CPrintToChat(client, "%s %T", g_sPluginTag, "Item bought! (NEW)", client, g_iPlayer[client].Credits, item.Long, iPrice, g_iPlayer[client].Currency);
                    }

                    int iTeam = TTT_GetClientTeam(client);
                    if (g_cLogPurchases != null && (g_cLogPurchases.IntValue == 1 || (g_cLogPurchases.IntValue == 2 && (iTeam == TTT_TEAM_TRAITOR || iTeam == TTT_TEAM_DETECTIVE))))
                    {
                        char sClientID[32], sTeam[ROLE_LENGTH];
                        TTT_GetTeamNameByID(iTeam, sTeam, sizeof(sTeam));

                        if (g_cAddLogs != null && g_cAddLogs.BoolValue)
                        {
                            if (g_cLogFormat.IntValue == 1)
                            {
                                GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
                            }
                            else if (g_cLogFormat.IntValue == 2)
                            {
                                GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
                            }
                            else if (g_cLogFormat.IntValue == 3)
                            {
                                GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
                            }
                            else if (g_cLogFormat.IntValue == 4)
                            {
                                Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
                            }

                            if (strlen(sClientID) > 2)
                            {
                                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
                            }
                        }

                        if (item.Logging)
                        {
                            TTT_LogString("-> [%N%s (%s) purchased an item from the shop: %s]", client, sClientID, sTeam, item.Long);
                        }
                    }

                    Call_StartForward(g_fwOnItemPurchased);  // Deprecated as of c6b65e.
                    Call_PushCell(client);                   //
                    Call_PushCell(iPrice);                   //
                    Call_PushCell(count);                    //
                    Call_PushString(item.Short);             //
                    Call_Finish();                           //

                    Call_StartForward(g_fwOnItemPurchasePost);
                    Call_PushCell(client);
                    Call_PushCell(iPrice);
                    Call_PushCell(count);
                    Call_PushString(item.Short);
                    Call_Finish();

                    if (g_smPurchases == null)
                    {
                        g_smPurchases = new StringMap();
                    }

                    int iValue = -1;
                    g_smPurchases.GetValue(item.Short, iValue);

                    // https://github.com/alliedmodders/sourcemod/blob/aae71612731eaa6771067a31f3a7ad34bdb0df28/core/logic/smn_adt_trie.cpp#L396
                    // If Get(Trie)Value returns false, it doesn't modify the value (iValue here) and it should be stay on -1
                    // We do this after the purchase, so the item was added to the player inventory of the player and we can set it from -1 to 1,
                    // otherwise we increase it by 1
                    if (iValue == -1)
                    {
                        iValue = 1;
                    }
                    else
                    {
                        iValue++;
                    }

                    g_smPurchases.SetValue(item.Short, iValue);

                    return true;
                }
            }
            else
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "You don't have enough money", client, g_iPlayer[client].Currency);
                return false;
            }

            if (menu && g_cReopenMenu.BoolValue && g_iPlayer[client].Reopen)
            {
                Command_Shop(client, 0);
            }
        }
    }
    return false;
}

public Action TTT_OnItemPurchasePre(int client, int &price, int &count, const char[] itemshort)
{
    char sFlag[16];
    g_smDiscountFlag.GetString(itemshort, sFlag, sizeof(sFlag));

    if (strlen(sFlag) > 0 && !HasFlag(client, sFlag, g_sDiscountFile))
    {
        return Plugin_Continue;
    }

    int iPercent = 0;
    if (g_smDiscountPercent.GetValue(itemshort, iPercent))
    {
        float fPercentage = iPercent / 100.0;
        int iDiscount = RoundToCeil(price * fPercentage);
        int iOld = price;
        price = iOld - iDiscount;
        return Plugin_Changed;
    }

    return Plugin_Continue;
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

    for (int i = 0; i < g_iCommands; i++)
    {
        char sCommand[32];
        Format(sCommand, sizeof(sCommand), "sm_%s", g_sCommandList[i]);

        if (StrEqual(sText, sCommand, false))
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public int Native_RegisterShopItem(Handle plugin, int numParams)
{
    if (!g_bItemReady)
    {
        return false;
    }

    if (numParams < 4)
    {
        return false;
    }

    char sShort[16];
    char temp_long[64];
    GetNativeString(1, sShort, sizeof(sShort));
    GetNativeString(2, temp_long, sizeof(temp_long));

    int temp_price = GetNativeCell(3);
    int temp_team = GetNativeCell(4);
    int temp_sort = GetNativeCell(5);
    int temp_maxUsages = GetNativeCell(6);
    int temp_limit = GetNativeCell(7);

    Function temp_callback = GetNativeFunction(8);

    bool temp_logging = view_as<bool>(GetNativeCell(9));

    LogToFile(g_sLog, "Short: %s - Long: %s - Price: %d, - Team: %d - Sort: %d - MaxUsages: %d, Limit: %d, Logging: %d", sShort, temp_long, temp_price, temp_team, temp_sort, temp_maxUsages, temp_limit, temp_logging);

    if ((strlen(sShort) < 1) || (strlen(temp_long) < 1) || (temp_price <= 0))
    {
        return false;
    }

    Item item;
    int iIndex = -1;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (StrEqual(item.Short, sShort, false))
        {
            iIndex = i;
            break;
        }
    }

    bool bReturn = false;

    Format(item.Short, sizeof(sShort), "%s", sShort);
    Format(item.Long, sizeof(temp_long), "%s", temp_long);
    item.Price = temp_price;
    item.Team = temp_team;
    item.Sort = temp_sort;
    item.MaxUsages = temp_maxUsages;
    item.Limit = temp_limit;
    item.Plugin = plugin;
    item.Callback = temp_callback;
    item.Logging = temp_logging;

    if (iIndex != -1)
    {
        g_aShopItems.SetArray(iIndex, item, sizeof(item));
        bReturn = true;
    }
    else
    {
        g_aShopItems.PushArray(item, sizeof(item));
        bReturn = true;
    }

    if (bReturn)
    {
        Call_StartForward(g_fwRegisterShopItemPost);
        Call_PushString(item.Short);
        Call_PushString(item.Long);
        Call_PushCell(item.Price);
        Call_PushCell(item.Team);
        Call_PushCell(item.Sort);
        Call_PushCell(item.MaxUsages);
        Call_PushCell(item.Limit);
        Call_PushCell(item.Logging);
        Call_Finish();

        if (g_cSortItems.IntValue)
        {
            SortADTArrayCustom(g_aShopItems, Sorting);
        }
    }

    return bReturn;
}

public int Native_UpdateShopItem(Handle plugin, int numParams)
{
    Item item;
    char sShort[16];
    GetNativeString(1, sShort, sizeof(sShort));

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (StrEqual(item.Short, sShort, false))
        {
            PrintToChatAll("Found: %s", sShort);

            item.Price = GetNativeCell(2);
            item.Sort = GetNativeCell(3);
            item.MaxUsages = GetNativeCell(4);
            item.Limit = GetNativeCell(5);

            PrintToChatAll("New values... Price: %d, Team: %d, Sort: %d, Max Usages: %d, Limit: %d", item.Price, item.Team, item.Sort, item.MaxUsages, item.Limit);

            g_aShopItems.SetArray(i, item);

            return true;
        }
    }

    return false;
}

public int Native_RemoveShopItem(Handle plugin, int numParams)
{
    Item item;
    char sShort[16];
    GetNativeString(1, sShort, sizeof(sShort));

    if (g_aShopItems != null)
    {
        for (int i = 0; i < g_aShopItems.Length; i++)
        {
            g_aShopItems.GetArray(i, item);
            if (StrEqual(item.Short, sShort, false))
            {
                g_aShopItems.Erase(i);

                Call_StartForward(g_fwOnItemRemove);
                Call_PushString(item.Short);
                Call_Finish();

                return true;
            }
        }
    }

    return false;
}

public int Native_GetItemName(Handle plugin, int numParams)
{
    char sName[16];
    int iSize = GetNativeCell(3);
    GetNativeString(1, sName, sizeof(sName));

    char[] sBuffer = new char[iSize];
    if (GetItemLong(sName, sBuffer, iSize) && SetNativeString(2, sBuffer, iSize) == SP_ERROR_NONE)
    {
        return true;
    }

    return false;
}

public int Native_ShopItemExist(Handle plugin, int numParams)
{
    char sName[16];
    GetNativeString(1, sName, sizeof(sName));

    bool bExist = false;
    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (StrEqual(item.Short, sName))
        {
            bExist = true;
            break;
        }
    }

    return bExist;
}

public int Sorting(int i, int j, Handle array, Handle hndl)
{
    Item item1;
    Item item2;

    g_aShopItems.GetArray(i, item1);
    g_aShopItems.GetArray(j, item2);

    if (item1.Sort < item2.Sort)
    {
        return -1;
    }
    else if (item1.Sort > item2.Sort)
    {
        return 1;
    }

    return 0;
}

public int Native_GetItemPrice(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Price;
        }
    }

    return 0;
}

public int Native_GetItemTeam(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Team;
        }
    }
    return 0;
}

public int Native_GetItemMaxUsages(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.MaxUsages;
        }
    }

    return -1;
}

public int Native_GetItemLimit(Handle plugin, int numParams)
{
    char sShort[32];
    GetNativeString(1, sShort, sizeof(sShort));

    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strcmp(sShort, item.Short, false) == 0)
        {
            return item.Limit;
        }
    }

    return -1;
}

public void TTT_OnClientGetRole(int client, int team, int role)
{
    if (g_cCreditsTimer.BoolValue)
    {
        if (g_cCreditsInterval.FloatValue >= 60.0)
        {
            delete g_iPlayer[client].Timer;
            RequestFrame(Frame_StartCreditsTimer, GetClientUserId(client));
        }
    }
}

public void Frame_StartCreditsTimer(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].Timer = CreateTimer(g_cCreditsInterval.FloatValue, Timer_CreditsTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void TTT_OnInventoryReady()
{
    LoopValidClients(client)
    {
        int iLength = 0;
        if (g_smUsages[client] != null)
        {
            StringMapSnapshot snap = g_smUsages[client].Snapshot();
            iLength = snap.Length;
            delete snap;

        }

        if (iLength == 0)
        {
            delete g_smUsages[client];
            g_smUsages[client] = new StringMap();
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
            int iCredits = g_cCreditsMin.IntValue;

            if (g_cCreditsMax.IntValue > g_cCreditsMin.IntValue)
            {
                GetRandomInt(g_cCreditsMin.IntValue, g_cCreditsMax.IntValue);
            }

            addCredits(client, iCredits, g_cCreditsMessage.BoolValue);
            return Plugin_Continue;
        }
    }

    g_iPlayer[client].Timer = null;
    return Plugin_Stop;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        delete g_smUsages[client];

        if (g_cResetCreditsEachRound.BoolValue && !g_cSQLCredits.BoolValue)
        {
            int iCredits = g_cStartCredits.IntValue;

            Action res = Plugin_Continue;
            Call_StartForward(g_fwOnStartCredits);
            Call_PushCell(client);
            Call_PushCellRef(iCredits);
            Call_Finish(res);

            if (res != Plugin_Changed)
            {
                g_iPlayer[client].Credits = g_cStartCredits.IntValue;
            }
            else
            {
                g_iPlayer[client].Credits = iCredits;
            }
        }

        if (TTT_GetRoundStatus() == Round_Active)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Your credits is", client, g_iPlayer[client].Credits, g_iPlayer[client].Currency);
        }
    }

    return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
    if (!g_cSQLCredits.BoolValue)
    {
        g_iPlayer[client].Credits = g_cStartCredits.IntValue;
    }
    else
    {
        LoadClientCredits(client);
    }

    Format(g_iPlayer[client].Currency, sizeof(PlayerData::Currency), "%T", "Shop: Currency", client);
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    delete g_iPlayer[client].Timer;
    
    return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    delete g_smUsages[client];
    delete g_iPlayer[client].Timer;
}

public Action Command_Credits(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Your credits is", client, g_iPlayer[client].Credits, g_iPlayer[client].Currency);

    return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }

    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
    if (!TTT_IsClientValid(iAttacker) || iAttacker == client)
    {
        return Plugin_Continue;
    }

    int iATeam = TTT_GetClientTeam(iAttacker);
    int iVTeam = TTT_GetClientTeam(client);
    if (iATeam == TTT_TEAM_INNOCENT && iVTeam == TTT_TEAM_INNOCENT)
    {
        subtractCredits(iAttacker, g_cCreditsII.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_INNOCENT && iVTeam == TTT_TEAM_TRAITOR)
    {
        addCredits(iAttacker, g_cCreditsIT.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_INNOCENT && iVTeam == TTT_TEAM_DETECTIVE)
    {
        subtractCredits(iAttacker, g_cCreditsID.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_INNOCENT && iVTeam == TTT_TEAM_MISC)
    {
        subtractCredits(iAttacker, g_cCreditsIM.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_TRAITOR && iVTeam == TTT_TEAM_INNOCENT)
    {
        addCredits(iAttacker, g_cCreditsTI.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_TRAITOR && iVTeam == TTT_TEAM_TRAITOR)
    {
        subtractCredits(iAttacker, g_cCreditsTT.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_TRAITOR && iVTeam == TTT_TEAM_DETECTIVE)
    {
        addCredits(iAttacker, g_cCreditsTD.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_TRAITOR && iVTeam == TTT_TEAM_MISC)
    {
        addCredits(iAttacker, g_cCreditsTM.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_DETECTIVE && iVTeam == TTT_TEAM_INNOCENT)
    {
        subtractCredits(iAttacker, g_cCreditsDI.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_DETECTIVE && iVTeam == TTT_TEAM_TRAITOR)
    {
        addCredits(iAttacker, g_cCreditsDT.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_DETECTIVE && iVTeam == TTT_TEAM_DETECTIVE)
    {
        subtractCredits(iAttacker, g_cCreditsDD.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_DETECTIVE && iVTeam == TTT_TEAM_MISC)
    {
        subtractCredits(iAttacker, g_cCreditsDM.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_MISC && iVTeam == TTT_TEAM_INNOCENT)
    {
        subtractCredits(iAttacker, g_cCreditsMI.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_MISC && iVTeam == TTT_TEAM_TRAITOR)
    {
        addCredits(iAttacker, g_cCreditsMT.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_MISC && iVTeam == TTT_TEAM_DETECTIVE)
    {
        subtractCredits(iAttacker, g_cCreditsMD.IntValue, true);
    }
    else if (iATeam == TTT_TEAM_MISC && iVTeam == TTT_TEAM_MISC)
    {
        subtractCredits(iAttacker, g_cCreditsMM.IntValue, true);
    }
    
    return Plugin_Continue;
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detective, int misc)
{
    delete g_smPurchases;
    g_smPurchases = new StringMap();
}

public void TTT_OnRoundEnd(int winner, int role, Handle array)
{
    LoopValidClients(client)
    {
        delete g_iPlayer[client].Timer;
        switch (winner)
        {
            case TTT_TEAM_DETECTIVE:
            {
                if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE || TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
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
                if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE || TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
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
                if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
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

public void TTT_OnBodyFound(int client, int victim, int victimTeam, int attackerTeam, int entityref, bool silentID)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }

    if ((TTT_GetClientTeam(client) & g_cCreditsFoundBodyTeam.IntValue) && !silentID || (g_cSilentIdRewards.BoolValue && silentID))
    {
        addCredits(client, g_cCreditsFoundBody.IntValue);
    }
}

void addCredits(int client, int credits, bool message = false)
{
    int newcredits = g_iPlayer[client].Credits + credits;

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnCreditsGiven_Pre);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_PushCellRef(newcredits);
    Call_Finish(res);

    if (res > Plugin_Changed)
    {
        return;
    }

    g_iPlayer[client].Credits = newcredits;

    if (g_cMaxSQLCredits.IntValue > 0 && g_iPlayer[client].Credits > g_cMaxSQLCredits.IntValue)
    {
        if (g_cMaxVIPSQLCredits.IntValue > 0 && g_cMaxVIPSQLCredits.IntValue > g_cMaxSQLCredits.IntValue && TTT_CheckCommandAccess(client, "ttt_credits_vip", g_cCreditsFlag))
        {
            if (g_iPlayer[client].Credits > g_cMaxVIPSQLCredits.IntValue)
            {
                g_iPlayer[client].Credits = g_cMaxVIPSQLCredits.IntValue;
            }
        }
        else
        {
            if (g_iPlayer[client].Credits > g_cMaxSQLCredits.IntValue)
            {
                g_iPlayer[client].Credits = g_cMaxSQLCredits.IntValue;
            }
        }
    }

    if (g_cShowEarnCreditsMessage.BoolValue && message)
    {
        if (g_cMessageTypCredits.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "%T", "credits earned", client, credits, g_iPlayer[client].Credits, g_iPlayer[client].Currency);
            CFormat(sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "<pre>%s</pre>", sBuffer);
            PrintCenterText2(client, "TTT - Shop", sBuffer); // TODO: Add 2nd option as synchud
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "credits earned", client, credits, g_iPlayer[client].Credits, g_iPlayer[client].Currency);
        }
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

void subtractCredits(int client, int credits, bool message = false)
{
    int newcredits = g_iPlayer[client].Credits - credits;

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnCreditsGiven_Pre);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_PushCellRef(newcredits);
    Call_Finish(res);

    if (res > Plugin_Changed)
    {
        return;
    }

    g_iPlayer[client].Credits = newcredits;

    if (g_iPlayer[client].Credits < 0)
    {
        g_iPlayer[client].Credits = 0;
    }

    if (g_cShowLoseCreditsMessage.BoolValue && message)
    {
        if (g_cMessageTypCredits.IntValue == 1)
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            Format(sBuffer, sizeof(sBuffer), "%T", "lost credits", client, credits, g_iPlayer[client].Credits, g_iPlayer[client].Currency);
            CFormat(sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "<pre>%s</pre>", sBuffer);
            PrintCenterText2(client, "TTT - Shop", sBuffer); // TODO: Add 2nd option as synchud
        }
        else
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "lost credits", client, credits, g_iPlayer[client].Credits, g_iPlayer[client].Currency);
        }
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

void setCredits(int client, int credits)
{
    g_iPlayer[client].Credits = credits;

    if (g_iPlayer[client].Credits < 0)
    {
        g_iPlayer[client].Credits = 0;
    }

    if (g_cMaxSQLCredits.IntValue > 0 && g_iPlayer[client].Credits > g_cMaxSQLCredits.IntValue)
    {
        if (g_cMaxVIPSQLCredits.IntValue > 0 && g_cMaxVIPSQLCredits.IntValue > g_cMaxSQLCredits.IntValue && TTT_CheckCommandAccess(client, "ttt_credits_vip", g_cCreditsFlag))
        {
            if (g_iPlayer[client].Credits > g_cMaxVIPSQLCredits.IntValue)
            {
                g_iPlayer[client].Credits = g_cMaxVIPSQLCredits.IntValue;
            }
        }
        else
        {
            if (g_iPlayer[client].Credits > g_cMaxSQLCredits.IntValue)
            {
                g_iPlayer[client].Credits = g_cMaxSQLCredits.IntValue;
            }
        }
    }

    UpdatePlayer(client);

    Call_StartForward(g_fwOnCreditsGiven);
    Call_PushCell(client);
    Call_PushCell(g_iPlayer[client].Credits);
    Call_Finish();
}

public Action Command_GiveItem(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_giveitem", g_cGiveItemFlag, true))
    {
        return Plugin_Handled;
    }

    if (args != 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_giveitem <#userid|name> <item>");
        return Plugin_Handled;
    }

    char sArg1[12];
    GetCmdArg(1, sArg1, sizeof(sArg1));

    char sItem[16];
    GetCmdArg(2, sItem, sizeof(sItem));

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS];
    int target_count;
    bool tn_is_ml;

    if ((target_count = ProcessTargetString(sArg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        int target = target_list[i];

        if (!TTT_IsClientValid(target))
        {
            return Plugin_Handled;
        }

        if (!GiveClientItem(target, sItem))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Shop Item not found", client, sItem);
        }
    }

    return Plugin_Continue;
}

public Action Command_SetCredits(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_setcredits", g_cSetCreditsFlag, true))
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

        char sName[MAX_NAME_LENGTH];
        TTT_GetClientName(target_list[i], sName, sizeof(sName));
        CPrintToChat(client, "%s %T", g_sPluginTag, "AdminSet", client, sName, credits, "Credits");
    }

    return Plugin_Continue;
}

public Action Command_ResetItems(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_resetitems", g_cResetItemsFlag, true))
    {
        return Plugin_Handled;
    }

    ResetItemsArray("Command_ResetItems", true);

    return Plugin_Continue;
}

public Action Command_ListItems(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_listitems", g_cListItemsFlag, true))
    {
        return Plugin_Handled;
    }

    PrintToConsole(client, "If you want something the names, make sure you take the right name with the correct team tag (like \"_t\" for traitor)");

    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strlen(item.Short) > 1)
        {
            PrintToConsole(client, "Name: %s \t Short Name: %s \t Price (without discount): %d \t  Max Usages: %d \t  Limit: %d", item.Long, item.Short, item.Price, item.MaxUsages, item.Limit);
        }
    }

    PrintToConsole(client, "If you want something the names, make sure you take the right name with the correct team tag (like \"_t\" for traitor)");

    return Plugin_Handled;
}

public Action Command_ReloadDiscount(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "shop_discount_reload_flag", g_cDiscountReloadFlag, true))
    {
        return Plugin_Handled;
    }

    ReplyToCommand(client, "Shop Discount file reloaded!");

    LoadShopFile(g_sDiscountFile);
    return Plugin_Continue;
}

public Action Command_ReloadFlag(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "ttt_shop_flags", g_cFlagsReloadFlag, true))
    {
        return Plugin_Handled;
    }

    ReplyToCommand(client, "Shop Flags file reloaded!");

    LoadShopFile(g_sFlagsFile);
    return Plugin_Continue;
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (TTT_IsClientValid(client))
    {
        return g_iPlayer[client].Credits;
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
        return g_iPlayer[client].Credits;
    }
    return 0;
}

public int Native_AddClientCredits(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int credits = GetNativeCell(2);

    if (TTT_IsClientValid(client))
    {
        setCredits(client, g_iPlayer[client].Credits+credits);
        return g_iPlayer[client].Credits;
    }
    return 0;
}

public int Native_GiveClientItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (TTT_IsClientValid(client))
    {
        return GiveClientItem(client, sItem);
    }

    return false;
}

public int Native_GetItemUsages(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsages = -1;

    if (g_smUsages[client].GetValue(sShort, iUsages))
    {
        return iUsages;
    }

    return -1;
}

public int Native_AddItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iOldUsage;
    g_smUsages[client].GetValue(sShort, iOldUsage);

    if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "Usage: %d, OldUsage: %d", iUsage, iOldUsage);
    }

    int iItemMaxUsages;

    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strlen(item.Short) > 1 && StrEqual(item.Short, sShort, false))
        {
            iItemMaxUsages = item.MaxUsages;
        }
    }

    if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "MaxUsages: %d", iItemMaxUsages);
    }

    int iNewUsage = iOldUsage + iUsage;

    if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "NewUsage Before: %d", iNewUsage);
    }

    if (iNewUsage > iItemMaxUsages)
    {
        iNewUsage = iItemMaxUsages;
    }

    if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
    {
        PrintToChat(client, "NewUsage After: %d", iNewUsage);
    }

    g_smUsages[client].SetValue(sShort, iNewUsage);

    return iNewUsage;
}

public int Native_RemoveItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iOldUsage;
    g_smUsages[client].GetValue(sShort, iOldUsage);

    int iNewUsage = iOldUsage - iUsage;

    if (iNewUsage < 0)
    {
        iNewUsage = 0;
    }

    g_smUsages[client].SetValue(sShort, iNewUsage);

    return iNewUsage;

}

public int Native_SetItemUsage(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sShort[16];
    GetNativeString(2, sShort, sizeof(sShort));

    int iUsage = GetNativeCell(3);

    int iItemMaxUsages;

    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strlen(item.Short) > 1 && StrEqual(item.Short, sShort, false))
        {
            iItemMaxUsages = item.MaxUsages;
        }
    }

    if (iUsage > iItemMaxUsages)
    {
        iUsage = iItemMaxUsages;
    }

    if (iUsage < 0)
    {
        iUsage = 0;
    }

    g_smUsages[client].SetValue(sShort, iUsage);

    return iUsage;
}

public int Native_GetItemDiscount(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (TTT_IsClientValid(client))
    {
        char sFlag[16];
        g_smDiscountFlag.GetString(sItem, sFlag, sizeof(sFlag));

        int iPercent = 0;

        if (!HasFlag(client, sFlag, g_sDiscountFile))
        {
            return iPercent;
        }

        if (g_smDiscountPercent.GetValue(sItem, iPercent))
        {
            return iPercent;
        }

        return iPercent;
    }

    return -1;
}

public int Native_CheckItemAccess(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sItem[16];
    GetNativeString(2, sItem, sizeof(sItem));

    if (TTT_IsClientValid(client))
    {
        char sFlag[16];
        bool success = g_smAccessFlag.GetString(sItem, sFlag, sizeof(sFlag));

        if (!success || strlen(sFlag) == 0)
        {
            return true;
        }

        return HasFlag(client, sFlag, g_sFlagsFile);
    }

    return true;
}

public int Native_GetClientCurrency(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    SetNativeString(2, g_iPlayer[client].Currency, GetNativeCell(3));
    
    return 0;
}

void ResetItemsArray(const char[] sFunction, bool initArray = false)
{
    g_bItemReady = false;
    delete g_aShopItems;

    LogToFile(g_sLog, "Function: %s - Init: %d", sFunction, initArray);

    if (initArray)
    {
        g_aShopItems = new ArrayList(sizeof(Item));
        RequestFrame(Frame_ShopReady, g_aShopItems);
    }
}

public void Frame_ShopReady(any items)
{
    if (view_as<ArrayList>(items) != null && g_aShopItems != null && view_as<ArrayList>(items) == g_aShopItems) // ¯\_(ツ)_/¯
    {
        g_bItemReady = true;

        Call_StartForward(g_fwOnShopReady);
        Call_Finish();
    }
}

int GiveClientItem(int client, char[] sItem)
{
    Item item;

    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (strlen(item.Short) > 1 && StrEqual(item.Short, sItem, false))
        {
            ClientBuyItem(client, sItem, false, true);
            return true;
        }
    }

    return false;
}

bool GetItemLong(const char[] itemshort, char[] buffer, int size)
{
    Item item;
    for (int i = 0; i < g_aShopItems.Length; i++)
    {
        g_aShopItems.GetArray(i, item);
        if (!StrEqual(itemshort, item.Short))
        {
            continue;
        }

        strcopy(buffer, size, item.Long);
        return true;
    }

    return false;
}

bool HasFlag(int client, const char[] flags, char[] file)
{
    int iFlag = ReadFlagString(flags);

    if (StrEqual(file, g_sDiscountFile))
    {
        return CheckCommandAccess(client, "ttt_shop_discount", iFlag, true);
    }

    if (StrEqual(file, g_sFlagsFile))
    {
        return CheckCommandAccess(client, "ttt_shop_flags", iFlag, true);
    }

    return false;
}

void RemoveOldPlugins(char[] sPlugin)
{
    char sOldFile[200];
    BuildPath(Path_SM, sOldFile, sizeof(sOldFile), "plugins/ttt/%s.smx", sPlugin);

    if (FileExists(sOldFile))
    {
        char sNewFile[200];
        BuildPath(Path_SM, sNewFile, sizeof(sNewFile), "plugins/disabled/%s.smx", sPlugin);

        ServerCommand("sm plugins unload ttt/%s", sPlugin);

        if (FileExists(sNewFile))
        {
            DeleteFile(sNewFile);
        }

        RenameFile(sNewFile, sOldFile);
    }
}
