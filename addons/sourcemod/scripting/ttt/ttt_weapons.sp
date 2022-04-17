#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt_inventory>
#include <ttt>
#include <ttt_weapons>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Weapons"

#define HEAVY_MODEL "models/player/custom_player/legacy/tm_phoenix_heavy.mdl"

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

ConVar g_cKev_Long = null;
ConVar g_cKevHelm_Long = null;
ConVar g_cHeavy_Long = null;
ConVar g_cHelm_Long = null;
ConVar g_cUSP_Long = null;
ConVar g_cMP5SD_Long = null;
ConVar g_cM4_Long = null;
ConVar g_cAWP_Long = null;
ConVar g_cBreachCharge_Long = null;
ConVar g_cBumpmine_Long = null;
ConVar g_cKF_Long = null;
ConVar g_cAK_Long = null;
ConVar g_cDeagle_Long = null;
ConVar g_cRevolver_Long = null;
ConVar g_cScout_Long = null;
ConVar g_cHammer_Long = null;
ConVar g_cAxe_Long = null;
ConVar g_cSpanner_Long = null;

ConVar g_cKevHelm_Price = null;
ConVar g_cUSP_Price = null;
ConVar g_cMP5SD_Price = null;
ConVar g_cM4_Price = null;
ConVar g_cAWP_Price = null;
ConVar g_cBreachCharge_Price = null;
ConVar g_cBumpmine_Price = null;
ConVar g_cKnife_Price = null;
ConVar g_cAK_Price = null;
ConVar g_cDeagle_Price = null;
ConVar g_cRevolver_Price = null;
ConVar g_cScout_Price = null;
ConVar g_cHammer_Price = null;
ConVar g_cAxe_Price = null;
ConVar g_cSpanner_Price = null;
ConVar g_cKev_Price = null;
ConVar g_cHeavy_Price = null;
ConVar g_cHelm_Price = null;

ConVar g_cKevHelm_Limit = null;
ConVar g_cUSP_Limit = null;
ConVar g_cMP5SD_Limit = null;
ConVar g_cM4_Limit = null;
ConVar g_cAWP_Limit = null;
ConVar g_cBreachCharge_Limit = null;
ConVar g_cBumpmine_Limit = null;
ConVar g_cKnife_Limit = null;
ConVar g_cAK_Limit = null;
ConVar g_cDeagle_Limit = null;
ConVar g_cRevolver_Limit = null;
ConVar g_cScout_Limit = null;
ConVar g_cHammer_Limit = null;
ConVar g_cAxe_Limit = null;
ConVar g_cSpanner_Limit = null;
ConVar g_cKev_Limit = null;
ConVar g_cHeavy_Limit = null;
ConVar g_cHelm_Limit = null;

ConVar g_cKevHelm_Count = null;
ConVar g_cUSP_Count = null;
ConVar g_cMP5SD_Count = null;
ConVar g_cM4_Count = null;
ConVar g_cAWP_Count = null;
ConVar g_cBreachCharge_Count = null;
ConVar g_cBumpmine_Count = null;
ConVar g_cKnife_Count = null;
ConVar g_cAK_Count = null;
ConVar g_cDeagle_Count = null;
ConVar g_cRevolver_Count = null;
ConVar g_cScout_Count = null;
ConVar g_cHammer_Count = null;
ConVar g_cAxe_Count = null;
ConVar g_cSpanner_Count = null;
ConVar g_cKev_Count = null;
ConVar g_cHeavy_Count = null;
ConVar g_cHelm_Count = null;

ConVar g_cKev_Type = null;
ConVar g_cHeavy_Type = null;
ConVar g_cHelm_Type = null;
ConVar g_cKevHelm_Type = null;
ConVar g_cHammer_Type = null;
ConVar g_cAxe_Type = null;
ConVar g_cSpanner_Type = null;
ConVar g_cBumpmine_Type = null;

ConVar g_cAWP_Min_Shots = null;
ConVar g_cAWP_Max_Shots = null;

ConVar g_cBreachCharge_Min = null;
ConVar g_cBreachCharge_Max = null;

ConVar g_cBumpmine_Min = null;
ConVar g_cBumpmine_Max = null;

ConVar g_cKev_Prio = null;
ConVar g_cHeavy_Prio = null;
ConVar g_cKevHelm_Prio = null;
ConVar g_cHelm_Prio = null;
ConVar g_cKnife_Prio = null;
ConVar g_cUSP_Prio = null;
ConVar g_cMP5SD_Prio = null;
ConVar g_cM4_Prio = null;
ConVar g_cAWP_Prio = null;
ConVar g_cBreachCharge_Prio = null;
ConVar g_cBumpmine_Prio = null;
ConVar g_cAK_Prio = null;
ConVar g_cDeagle_Prio = null;
ConVar g_cRevolver_Prio = null;
ConVar g_cScout_Prio = null;
ConVar g_cHammer_Prio = null;
ConVar g_cAxe_Prio = null;
ConVar g_cSpanner_Prio = null;

ConVar g_cDebugMessages = null;

enum struct PlayerData {
    int Knives;
    int Kevlar;
    int Heavy;
    int Helm;
    int KevlarHelm;

    bool HasKnife;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("ttt_weapons");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("weapons");
    CreateConVar("ttt2_weapons_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    
    g_cKev_Type = AutoExecConfig_CreateConVar("kevlar_type", "1", "Type of kevlar configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cHeavy_Type = AutoExecConfig_CreateConVar("heavy_type", "1", "Type of heavy configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cHelm_Type = AutoExecConfig_CreateConVar("helm_type", "1", "Type of helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cKevHelm_Type = AutoExecConfig_CreateConVar("kevhelm_type", "1", "Type of kevlar+helm configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cHammer_Type = AutoExecConfig_CreateConVar("hammer_type", "1", "Type of hammer configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cAxe_Type = AutoExecConfig_CreateConVar("axe_type", "1", "Type of Axe configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cSpanner_Type = AutoExecConfig_CreateConVar("spanner_type", "1", "Type of Spanner configuration to use. 0 = Everyone, 1 = Traitor + Detective (Default), 2 = Traitor Only");
    g_cBumpmine_Type = AutoExecConfig_CreateConVar("bumpmine_type", "2", "Type of Bumpmine configuration to use. 0 = Everyone, 1 = Traitor + Detective, 2 = Traitor Only (Default)");

    g_cKev_Long = AutoExecConfig_CreateConVar("kevlar_name", "Kevlar", "The name of the kevlar in the shop menu.");
    g_cHeavy_Long = AutoExecConfig_CreateConVar("heavy_name", "Heavy", "The name of the heavy in the shop menu.");
    g_cHelm_Long = AutoExecConfig_CreateConVar("helm_name", "Helm", "The name of the helm in the shop menu.");
    g_cKevHelm_Long = AutoExecConfig_CreateConVar("kevhelm_name", "Kevlar+Helm", "The name of the kevlar+helm in the shop menu.");
    g_cUSP_Long = AutoExecConfig_CreateConVar("usp_name", "USP-S", "The name of the USP-S in the shop menu.");
    g_cMP5SD_Long = AutoExecConfig_CreateConVar("mp5sd_name", "MP5-SD", "The name of the MP5-SD in the shop menu.");
    g_cAK_Long = AutoExecConfig_CreateConVar("ak47_name", "AK47", "The name of the AK47 in the shop menu.");
    g_cDeagle_Long = AutoExecConfig_CreateConVar("deagle_name", "Deagle", "The name of the Deagle in the shop menu.");
    g_cRevolver_Long = AutoExecConfig_CreateConVar("revolver_name", "Revolver", "The name of the Revolver in the shop menu.");
    g_cScout_Long = AutoExecConfig_CreateConVar("scout_name", "Scout", "The name of the Scout in the shop menu.");
    g_cM4_Long = AutoExecConfig_CreateConVar("m4a1_name", "M4A1-S", "The name of the M4A1-S in the shop menu.");
    g_cAWP_Long = AutoExecConfig_CreateConVar("awp_name", "AWP", "The name of the AWP in the shop menu.");
    g_cBreachCharge_Long = AutoExecConfig_CreateConVar("breathcharge_name", "Breachcharge", "The name of the Breachcharge in the shop menu.");
    g_cBumpmine_Long = AutoExecConfig_CreateConVar("bumpmine_name", "Bumpmine", "The name of the Bumpmine in the shop menu.");
    g_cKF_Long = AutoExecConfig_CreateConVar("oneknife_name", "1-Hit Knife", "The name of the 1-hit knife in the shop menu.");
    g_cHammer_Long = AutoExecConfig_CreateConVar("hammer_name", "Hammer", "The name of the Hammer in the shop menu.");
    g_cAxe_Long = AutoExecConfig_CreateConVar("axe_name", "Axe", "The name of the Axe in the shop menu.");
    g_cSpanner_Long = AutoExecConfig_CreateConVar("spanner_name", "Spanner", "The name of the Spanner in the shop menu.");

    g_cKev_Price = AutoExecConfig_CreateConVar("kevlar_price", "3000", "The amount of credits the kevlar costs. 0 to disable.");
    g_cHeavy_Price = AutoExecConfig_CreateConVar("heavy_price", "10000", "The amount of credits the heavy costs. 0 to disable.");
    g_cHelm_Price = AutoExecConfig_CreateConVar("helm_price", "2000", "The amount of credits the helm costs. 0 to disable.");
    g_cKevHelm_Price = AutoExecConfig_CreateConVar("kevhelm_price", "2000", "The amount of credits the kevlar+helm costs. 0 to disable.");
    g_cUSP_Price = AutoExecConfig_CreateConVar("usp_price", "3000", "The amount of credits the USP-S costs. 0 to disable.");
    g_cMP5SD_Price = AutoExecConfig_CreateConVar("mp5sd_price", "3000", "The amount of credits the MP5-SD costs. 0 to disable.");
    g_cAK_Price = AutoExecConfig_CreateConVar("ak47_price", "3000", "The amount of credits the AK47 costs. 0 to disable.");
    g_cDeagle_Price = AutoExecConfig_CreateConVar("deagle_price", "3000", "The amount of credits the Deagle costs. 0 to disable.");
    g_cRevolver_Price = AutoExecConfig_CreateConVar("revolver_price", "3000", "The amount of credits the Revolver costs. 0 to disable.");
    g_cScout_Price = AutoExecConfig_CreateConVar("scout_price", "3000", "The amount of credits the Scout costs. 0 to disable.");
    g_cM4_Price = AutoExecConfig_CreateConVar("m4a1_price", "3000", "The amount of credits the M4A1-S costs. 0 to disable.");
    g_cAWP_Price = AutoExecConfig_CreateConVar("awp_price", "3000", "The amount of credits the AWP costs. 0 to disable.");
    g_cBreachCharge_Price = AutoExecConfig_CreateConVar("breathcharge_price", "3000", "The amount of credits the Breachcharge costs. 0 to disable.");
    g_cBumpmine_Price = AutoExecConfig_CreateConVar("bumpmine_price", "3000", "The amount of credits the Bumpmine costs. 0 to disable.");
    g_cKnife_Price = AutoExecConfig_CreateConVar("oneknife_price", "3000", "The amount of credits the One-Hit Knife costs. 0 to disable.");
    g_cHammer_Price = AutoExecConfig_CreateConVar("hammer_price", "3000", "The amount of credits the Hammer costs. 0 to disable.");
    g_cAxe_Price = AutoExecConfig_CreateConVar("axe_price", "3000", "The amount of credits the Axe costs. 0 to disable.");
    g_cSpanner_Price = AutoExecConfig_CreateConVar("spanner_price", "3000", "The amount of credits the Spanner costs. 0 to disable.");

    g_cKev_Limit = AutoExecConfig_CreateConVar("kevlar_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cHeavy_Limit = AutoExecConfig_CreateConVar("heavy_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cHelm_Limit = AutoExecConfig_CreateConVar("helm_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cKevHelm_Limit = AutoExecConfig_CreateConVar("kevhelm_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cUSP_Limit = AutoExecConfig_CreateConVar("usp_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cMP5SD_Limit = AutoExecConfig_CreateConVar("mp5sd_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cAK_Limit = AutoExecConfig_CreateConVar("ak47_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDeagle_Limit = AutoExecConfig_CreateConVar("deagle_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cRevolver_Limit = AutoExecConfig_CreateConVar("revolver_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cScout_Limit = AutoExecConfig_CreateConVar("scout_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cM4_Limit = AutoExecConfig_CreateConVar("m4a1_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cAWP_Limit = AutoExecConfig_CreateConVar("awp_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cBreachCharge_Limit = AutoExecConfig_CreateConVar("breathcharge_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cBumpmine_Limit = AutoExecConfig_CreateConVar("bumpmine_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cKnife_Limit = AutoExecConfig_CreateConVar("oneknife_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cHammer_Limit = AutoExecConfig_CreateConVar("hammer_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cAxe_Limit = AutoExecConfig_CreateConVar("axe_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cSpanner_Limit = AutoExecConfig_CreateConVar("spanner_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);


    g_cKev_Prio = AutoExecConfig_CreateConVar("kevlar_sort_prio", "0", "The sorting priority of the kevlar in the shop menu.");
    g_cHeavy_Prio = AutoExecConfig_CreateConVar("heavy_sort_prio", "0", "The sorting priority of the heavy in the shop menu.");
    g_cHelm_Prio = AutoExecConfig_CreateConVar("helm_sort_prio", "0", "The sorting priority of the helm in the shop menu.");
    g_cKevHelm_Prio = AutoExecConfig_CreateConVar("kevhelm_sort_prio", "0", "The sorting priority of the kevlar+helm in the shop menu.");
    g_cUSP_Prio = AutoExecConfig_CreateConVar("usp_sort_prio", "0", "The sorting priority of the USP-S in the shop menu.");
    g_cMP5SD_Prio = AutoExecConfig_CreateConVar("mp5sd_sort_prio", "0", "The sorting priority of the MP5-SD in the shop menu.");
    g_cAK_Prio = AutoExecConfig_CreateConVar("ak47_sort_prio", "0", "The sorting priority of the AK47 in the shop menu.");
    g_cDeagle_Prio = AutoExecConfig_CreateConVar("deagle_sort_prio", "0", "The sorting priority of the Deagle in the shop menu.");
    g_cRevolver_Prio = AutoExecConfig_CreateConVar("revolver_sort_prio", "0", "The sorting priority of the Revolver in the shop menu.");
    g_cScout_Prio = AutoExecConfig_CreateConVar("scout_sort_prio", "0", "The sorting priority of the Scout in the shop menu.");
    g_cM4_Prio = AutoExecConfig_CreateConVar("m4a1_sort_prio", "0", "The sorting priority of the M4A1-S in the shop menu.");
    g_cAWP_Prio = AutoExecConfig_CreateConVar("awp_sort_prio", "0", "The sorting priority of the AWP in the shop menu.");
    g_cBreachCharge_Prio = AutoExecConfig_CreateConVar("breathcharge_sort_prio", "0", "The sorting priority of the Breachcharge in the shop menu.");
    g_cBumpmine_Prio = AutoExecConfig_CreateConVar("bumpmine_sort_prio", "0", "The sorting priority of the Bumpmine in the shop menu.");
    g_cKnife_Prio = AutoExecConfig_CreateConVar("oneknife_sort_prio", "0", "The sorting priority of the One-Hit Knife in the shop menu.");
    g_cHammer_Prio = AutoExecConfig_CreateConVar("hammer_sort_prio", "0", "The sorting priority of the Hammer in the shop menu.");
    g_cAxe_Prio = AutoExecConfig_CreateConVar("axe_sort_prio", "0", "The sorting priority of the Axe in the shop menu.");
    g_cSpanner_Prio = AutoExecConfig_CreateConVar("spanner_sort_prio", "0", "The sorting priority of the Spanner in the shop menu.");

    g_cKevHelm_Count = AutoExecConfig_CreateConVar("kevhelm_count", "1", "How often this item (Kevlar + Helm) can buy per round ( 0 - Disabled).");
    g_cUSP_Count = AutoExecConfig_CreateConVar("usp_count", "1", "How often this item (USP) can buy per round ( 0 - Disabled).");
    g_cMP5SD_Count = AutoExecConfig_CreateConVar("mp5sd_count", "1", "How often this item (MP5-SD) can buy per round ( 0 - Disabled).");
    g_cM4_Count = AutoExecConfig_CreateConVar("m4a1_count", "1", "How often this item (M4A1) can buy per round ( 0 - Disabled).");
    g_cAWP_Count = AutoExecConfig_CreateConVar("awp_count", "1", "How often this item (AWP) can buy per round ( 0 - Disabled).");
    g_cBreachCharge_Count = AutoExecConfig_CreateConVar("breathcharge_count", "1", "How often this item (Breathcharge) can buy per round ( 0 - Disabled).");
    g_cBumpmine_Count = AutoExecConfig_CreateConVar("bumpmine_count", "1", "How often this item (Bumpmine) can buy per round ( 0 - Disabled).");
    g_cKnife_Count = AutoExecConfig_CreateConVar("oneknife_count", "1", "How often this item (1-Knife) can buy per round ( 0 - Disabled).");
    g_cAK_Count = AutoExecConfig_CreateConVar("ak47_count", "1", "How often this item (AK47) can buy per round ( 0 - Disabled).");
    g_cDeagle_Count = AutoExecConfig_CreateConVar("deagle_count", "1", "How often this item (Deagle) can buy per round ( 0 - Disabled).");
    g_cRevolver_Count = AutoExecConfig_CreateConVar("revolver_count", "1", "How often this item (Revolver) can buy per round ( 0 - Disabled).");
    g_cScout_Count = AutoExecConfig_CreateConVar("scout_count", "1", "How often this item (Scout) can buy per round ( 0 - Disabled).");
    g_cHammer_Count = AutoExecConfig_CreateConVar("hammer_count", "1", "How often this item (Hammer) can buy per round ( 0 - Disabled).");
    g_cAxe_Count = AutoExecConfig_CreateConVar("axe_count", "1", "How often this item (Axe) can buy per round ( 0 - Disabled).");
    g_cSpanner_Count = AutoExecConfig_CreateConVar("spanner_count", "1", "How often this item (Spanner) can buy per round ( 0 - Disabled).");
    g_cKev_Count = AutoExecConfig_CreateConVar("kevlar_count", "1", "How often this item (Kevlar) can buy per round ( 0 - Disabled).");
    g_cHeavy_Count = AutoExecConfig_CreateConVar("heavy_count", "1", "How often this item (Heavy Armor) can buy per round ( 0 - Disabled).");
    g_cHelm_Count = AutoExecConfig_CreateConVar("helm_count", "1", "How often this item (Helm) can buy per round ( 0 - Disabled).");

    g_cAWP_Min_Shots = AutoExecConfig_CreateConVar("awp_min_shots", "1", "The min. amount of shots of traitor awp.");
    g_cAWP_Max_Shots = AutoExecConfig_CreateConVar("awp_max_shots", "3", "The max. amount of shots of traitor awp.");
    g_cBreachCharge_Min = AutoExecConfig_CreateConVar("breathcharge_min", "1", "The min. amount of breachcharges.");
    g_cBreachCharge_Max = AutoExecConfig_CreateConVar("breathcharge_max", "3", "The max. amount of breachcharges.");
    g_cBumpmine_Min = AutoExecConfig_CreateConVar("bumpmine_min", "1", "The min. amount of Bumpmines.");
    g_cBumpmine_Max = AutoExecConfig_CreateConVar("bumpmine_max", "3", "The max. amount of Bumpmines.");
    TTT_EndConfig();

    TTT_LoadTranslations();

    LoopValidClients(i)
    {
        SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
    }
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(KEV_ITEM_SHORT);
        TTT_RemoveShopItem(KEV_T_ITEM_SHORT);
        TTT_RemoveShopItem(KEV_D_ITEM_SHORT);
        TTT_RemoveShopItem(KEV_ITEM_SHORT);
        TTT_RemoveShopItem(HEAVY_ITEM_SHORT);
        TTT_RemoveShopItem(HEAVY_T_ITEM_SHORT);
        TTT_RemoveShopItem(HEAVY_D_ITEM_SHORT);
        TTT_RemoveShopItem(HEAVY_ITEM_SHORT);
        TTT_RemoveShopItem(HELM_ITEM_SHORT);
        TTT_RemoveShopItem(HELM_T_ITEM_SHORT);
        TTT_RemoveShopItem(HELM_D_ITEM_SHORT);
        TTT_RemoveShopItem(HELM_ITEM_SHORT);
        TTT_RemoveShopItem(KEVHELM_ITEM_SHORT);
        TTT_RemoveShopItem(KEVHELM_T_ITEM_SHORT);
        TTT_RemoveShopItem(KEVHELM_D_ITEM_SHORT);
        TTT_RemoveShopItem(HELM_ITEM_SHORT);
        TTT_RemoveShopItem(KF_ITEM_SHORT);
        TTT_RemoveShopItem(M4_ITEM_SHORT);
        TTT_RemoveShopItem(AWP_ITEM_SHORT);
        TTT_RemoveShopItem(BREACHCHARGE_ITEM_SHORT);
        TTT_RemoveShopItem(BUMPMINE_ITEM_SHORT);
        TTT_RemoveShopItem(BUMPMINE_D_ITEM_SHORT);
        TTT_RemoveShopItem(BUMPMINE_T_ITEM_SHORT);
        TTT_RemoveShopItem(USP_ITEM_SHORT);
        TTT_RemoveShopItem(MP5SD_ITEM_SHORT);
        TTT_RemoveShopItem(AK_ITEM_SHORT);
        TTT_RemoveShopItem(DEAGLE_ITEM_SHORT);
        TTT_RemoveShopItem(REVOLVER_ITEM_SHORT);
        TTT_RemoveShopItem(SCOUT_ITEM_SHORT);
        TTT_RemoveShopItem(HAMMER_ITEM_SHORT);
        TTT_RemoveShopItem(HAMMER_D_ITEM_SHORT);
        TTT_RemoveShopItem(HAMMER_T_ITEM_SHORT);
        TTT_RemoveShopItem(AXE_ITEM_SHORT);
        TTT_RemoveShopItem(AXE_T_ITEM_SHORT);
        TTT_RemoveShopItem(AXE_D_ITEM_SHORT);
        TTT_RemoveShopItem(SPANNER_ITEM_SHORT);
        TTT_RemoveShopItem(SPANNER_T_ITEM_SHORT);
        TTT_RemoveShopItem(SPANNER_D_ITEM_SHORT);
    }
}

public void OnConfigsExecuted()
{
    g_cDebugMessages = FindConVar("ttt_show_debug_messages");

    RegisterItem();
}

public void OnMapStart()
{
    PrecacheModel(HEAVY_MODEL, true);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[128];
    
    g_cKev_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cKev_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(KEV_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cKev_Prio.IntValue, g_cKev_Count.IntValue, g_cKev_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cKev_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(KEV_T_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_TRAITOR, g_cKev_Prio.IntValue, g_cKev_Count.IntValue, g_cKev_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(KEV_D_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_DETECTIVE, g_cKev_Prio.IntValue, g_cKev_Count.IntValue, g_cKev_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cKev_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(KEV_ITEM_SHORT, sBuffer, g_cKev_Price.IntValue, TTT_TEAM_TRAITOR, g_cKev_Prio.IntValue, g_cKev_Count.IntValue, g_cKev_Limit.IntValue, OnItemPurchased);
    }

    g_cHeavy_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cHeavy_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(HEAVY_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cHeavy_Prio.IntValue, g_cHeavy_Count.IntValue, g_cHeavy_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHeavy_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(HEAVY_T_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_TRAITOR, g_cHeavy_Prio.IntValue, g_cHeavy_Count.IntValue, g_cHeavy_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(HEAVY_D_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_DETECTIVE, g_cHeavy_Prio.IntValue, g_cHeavy_Count.IntValue, g_cHeavy_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHeavy_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(HEAVY_ITEM_SHORT, sBuffer, g_cHeavy_Price.IntValue, TTT_TEAM_TRAITOR, g_cHeavy_Prio.IntValue, g_cHeavy_Count.IntValue, g_cHeavy_Limit.IntValue, OnItemPurchased);
    }

    g_cHelm_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cHelm_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(HELM_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cHelm_Prio.IntValue, g_cHelm_Count.IntValue, g_cHelm_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHelm_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(HELM_T_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cHelm_Prio.IntValue, g_cHelm_Count.IntValue, g_cHelm_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(HELM_D_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_DETECTIVE, g_cHelm_Prio.IntValue, g_cHelm_Count.IntValue, g_cHelm_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHelm_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(HELM_ITEM_SHORT, sBuffer, g_cHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cHelm_Prio.IntValue, g_cHelm_Count.IntValue, g_cHelm_Limit.IntValue, OnItemPurchased);
    }

    g_cKevHelm_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cKevHelm_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(KEVHELM_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cKevHelm_Prio.IntValue, g_cKevHelm_Count.IntValue, g_cKevHelm_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cKevHelm_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(KEVHELM_T_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cKevHelm_Prio.IntValue, g_cKevHelm_Count.IntValue, g_cKevHelm_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(KEVHELM_D_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_DETECTIVE, g_cKevHelm_Prio.IntValue, g_cKevHelm_Count.IntValue, g_cKevHelm_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cKevHelm_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(HELM_ITEM_SHORT, sBuffer, g_cKevHelm_Price.IntValue, TTT_TEAM_TRAITOR, g_cKevHelm_Prio.IntValue, g_cKevHelm_Count.IntValue, g_cKevHelm_Limit.IntValue, OnItemPurchased);
    }

    g_cKF_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(KF_ITEM_SHORT, sBuffer, g_cKnife_Price.IntValue, TTT_TEAM_TRAITOR, g_cKnife_Prio.IntValue, g_cKnife_Count.IntValue, g_cKnife_Limit.IntValue, OnItemPurchased);

    g_cM4_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(M4_ITEM_SHORT, sBuffer, g_cM4_Price.IntValue, TTT_TEAM_TRAITOR, g_cM4_Prio.IntValue, g_cM4_Count.IntValue, g_cM4_Limit.IntValue, OnItemPurchased);

    g_cAWP_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(AWP_ITEM_SHORT, sBuffer, g_cAWP_Price.IntValue, TTT_TEAM_TRAITOR, g_cAWP_Prio.IntValue, g_cAWP_Count.IntValue, g_cAWP_Limit.IntValue, OnItemPurchased);

    g_cBreachCharge_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(BREACHCHARGE_ITEM_SHORT, sBuffer, g_cBreachCharge_Price.IntValue, TTT_TEAM_TRAITOR, g_cBreachCharge_Prio.IntValue, g_cBreachCharge_Count.IntValue, g_cBreachCharge_Limit.IntValue, OnItemPurchased);

    g_cBumpmine_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cBumpmine_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(BUMPMINE_ITEM_SHORT, sBuffer, g_cBumpmine_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cBumpmine_Prio.IntValue, g_cBumpmine_Count.IntValue, g_cBumpmine_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cBumpmine_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(BUMPMINE_T_ITEM_SHORT, sBuffer, g_cBumpmine_Price.IntValue, TTT_TEAM_TRAITOR, g_cBumpmine_Prio.IntValue, g_cBumpmine_Count.IntValue, g_cBumpmine_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(BUMPMINE_D_ITEM_SHORT, sBuffer, g_cBumpmine_Price.IntValue, TTT_TEAM_DETECTIVE, g_cBumpmine_Prio.IntValue, g_cBumpmine_Count.IntValue, g_cBumpmine_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cBumpmine_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(BUMPMINE_T_ITEM_SHORT, sBuffer, g_cBumpmine_Price.IntValue, TTT_TEAM_TRAITOR, g_cBumpmine_Prio.IntValue, g_cBumpmine_Count.IntValue, g_cBumpmine_Limit.IntValue, OnItemPurchased);
    }

    g_cUSP_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(USP_ITEM_SHORT, sBuffer, g_cUSP_Price.IntValue, TTT_TEAM_TRAITOR, g_cUSP_Prio.IntValue, g_cUSP_Count.IntValue, g_cUSP_Limit.IntValue, OnItemPurchased);

    g_cMP5SD_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(MP5SD_ITEM_SHORT, sBuffer, g_cMP5SD_Price.IntValue, TTT_TEAM_TRAITOR, g_cMP5SD_Prio.IntValue, g_cMP5SD_Count.IntValue, g_cMP5SD_Limit.IntValue, OnItemPurchased);

    g_cAK_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(AK_ITEM_SHORT, sBuffer, g_cAK_Price.IntValue, TTT_TEAM_TRAITOR, g_cAK_Prio.IntValue, g_cAK_Count.IntValue, g_cAK_Limit.IntValue, OnItemPurchased);

    g_cDeagle_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(DEAGLE_ITEM_SHORT, sBuffer, g_cDeagle_Price.IntValue, TTT_TEAM_TRAITOR, g_cDeagle_Prio.IntValue, g_cDeagle_Count.IntValue, g_cDeagle_Limit.IntValue, OnItemPurchased);

    g_cRevolver_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(REVOLVER_ITEM_SHORT, sBuffer, g_cRevolver_Price.IntValue, TTT_TEAM_TRAITOR, g_cRevolver_Prio.IntValue, g_cRevolver_Count.IntValue, g_cRevolver_Limit.IntValue, OnItemPurchased);

    g_cScout_Long.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SCOUT_ITEM_SHORT, sBuffer, g_cScout_Price.IntValue, TTT_TEAM_TRAITOR, g_cScout_Prio.IntValue, g_cScout_Count.IntValue, g_cScout_Limit.IntValue, OnItemPurchased);

    g_cHammer_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cHammer_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(HAMMER_ITEM_SHORT, sBuffer, g_cHammer_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cHammer_Prio.IntValue, g_cHammer_Count.IntValue, g_cHammer_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHammer_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(HAMMER_T_ITEM_SHORT, sBuffer, g_cHammer_Price.IntValue, TTT_TEAM_TRAITOR, g_cHammer_Prio.IntValue, g_cHammer_Count.IntValue, g_cHammer_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(HAMMER_D_ITEM_SHORT, sBuffer, g_cHammer_Price.IntValue, TTT_TEAM_DETECTIVE, g_cHammer_Prio.IntValue, g_cHammer_Count.IntValue, g_cHammer_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cHammer_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(HAMMER_T_ITEM_SHORT, sBuffer, g_cHammer_Price.IntValue, TTT_TEAM_TRAITOR, g_cHammer_Prio.IntValue, g_cHammer_Count.IntValue, g_cHammer_Limit.IntValue, OnItemPurchased);
    }

    g_cAxe_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cAxe_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(AXE_ITEM_SHORT, sBuffer, g_cAxe_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cAxe_Prio.IntValue, g_cAxe_Count.IntValue, g_cAxe_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cAxe_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(AXE_T_ITEM_SHORT, sBuffer, g_cAxe_Price.IntValue, TTT_TEAM_TRAITOR, g_cAxe_Prio.IntValue, g_cAxe_Count.IntValue, g_cAxe_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(AXE_D_ITEM_SHORT, sBuffer, g_cAxe_Price.IntValue, TTT_TEAM_DETECTIVE, g_cAxe_Prio.IntValue, g_cAxe_Count.IntValue, g_cAxe_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cAxe_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(AXE_T_ITEM_SHORT, sBuffer, g_cAxe_Price.IntValue, TTT_TEAM_TRAITOR, g_cAxe_Prio.IntValue, g_cAxe_Count.IntValue, g_cAxe_Limit.IntValue, OnItemPurchased);
    }

    g_cSpanner_Long.GetString(sBuffer, sizeof(sBuffer));
    if (g_cSpanner_Type.IntValue == 0)
    {
        TTT_RegisterShopItem(SPANNER_ITEM_SHORT, sBuffer, g_cSpanner_Price.IntValue, TTT_TEAM_UNASSIGNED, g_cSpanner_Prio.IntValue, g_cSpanner_Count.IntValue, g_cSpanner_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cSpanner_Type.IntValue == 1)
    {
        TTT_RegisterShopItem(SPANNER_T_ITEM_SHORT, sBuffer, g_cSpanner_Price.IntValue, TTT_TEAM_TRAITOR, g_cSpanner_Prio.IntValue, g_cSpanner_Count.IntValue, g_cSpanner_Limit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(SPANNER_D_ITEM_SHORT, sBuffer, g_cSpanner_Price.IntValue, TTT_TEAM_DETECTIVE, g_cSpanner_Prio.IntValue, g_cSpanner_Count.IntValue, g_cSpanner_Limit.IntValue, OnItemPurchased);
    }
    else if (g_cSpanner_Type.IntValue == 2)
    {
        TTT_RegisterShopItem(SPANNER_T_ITEM_SHORT, sBuffer, g_cSpanner_Price.IntValue, TTT_TEAM_TRAITOR, g_cSpanner_Prio.IntValue, g_cSpanner_Count.IntValue, g_cSpanner_Limit.IntValue, OnItemPurchased);
    }
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    ResetStuff();
    return Plugin_Continue;
}

public Action TTT_OnRoundStart_Pre()
{
    ResetStuff();
    return Plugin_Continue;
}

public void TTT_OnRoundStartFailed(int p, int r)
{
    ResetStuff();
}

public void TTT_OnRoundStart(int i, int t, int d, int m)
{
    ResetStuff();
}

public void TTT_OnClientDeath(int v, int a)
{
    g_iPlayer[v].HasKnife = false;
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    char sItem[16];

    if (strcmp(itemshort, USP_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
        }

        GivePlayerItem(client, "weapon_usp_silencer");
    }
    else if (strcmp(itemshort, MP5SD_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        GivePlayerItem(client, "weapon_mp5sd");
    }
    else if (strcmp(itemshort, AK_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        GivePlayerItem(client, "weapon_ak47");
    }
    else if (strcmp(itemshort, DEAGLE_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }

        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
        }

        GivePlayerItem(client, "weapon_deagle");
    }
    else if (strcmp(itemshort, REVOLVER_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY));
        }

        GivePlayerItem(client, "weapon_revolver");
    }
    else if (strcmp(itemshort, SCOUT_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);
        
        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        GivePlayerItem(client, "weapon_ssg08");
    }
    else if (strcmp(itemshort, HAMMER_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR && TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_hammer");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, AXE_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR && TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_axe");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, SPANNER_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR && TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_spanner");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, HAMMER_D_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_hammer");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, AXE_D_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_axe");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, SPANNER_D_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_spanner");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, HAMMER_T_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_hammer");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, AXE_T_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_axe");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, SPANNER_T_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        int iMelee = GivePlayerItem(client, "weapon_spanner");
        EquipPlayerWeapon(client, iMelee);
    }
    else if (strcmp(itemshort, M4_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        GivePlayerItem(client, "weapon_m4a1_silencer");
    }
    else if (strcmp(itemshort, AWP_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        int iAWP = GivePlayerItem(client, "weapon_awp");

        if (iAWP != -1)
        {
            EquipPlayerWeapon(client, iAWP);
            SetEntProp(iAWP, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
            SetEntProp(iAWP, Prop_Data, "m_iClip1", GetRandomInt(g_cAWP_Min_Shots.IntValue, g_cAWP_Max_Shots.IntValue));
        }
        else
        {
            TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cAWP_Price.IntValue);
        }
    }
    else if (strcmp(itemshort, BREACHCHARGE_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
        {
            SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY));
        }

        int iBC = GivePlayerItem(client, "weapon_breachcharge");

        if (iBC != -1)
        {
            EquipPlayerWeapon(client, iBC);
            SetEntProp(iBC, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
            SetEntProp(iBC, Prop_Data, "m_iClip1", GetRandomInt(g_cBreachCharge_Min.IntValue, g_cBreachCharge_Max.IntValue));
        }
        else
        {
            TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cBreachCharge_Price.IntValue);
        }
    }
    else if (strcmp(itemshort, BUMPMINE_ITEM_SHORT, false) == 0 || strcmp(itemshort, BUMPMINE_D_ITEM_SHORT, false) == 0 || strcmp(itemshort, BUMPMINE_T_ITEM_SHORT, false) == 0)
    {
        strcopy(sItem, sizeof(sItem), itemshort);

        if (TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
        {
            if (g_cBumpmine_Type.IntValue == 0)
            {
                GiveBumpmine(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
        {
            if (g_cBumpmine_Type.IntValue == 0 || g_cBumpmine_Type.IntValue == 2)
            {
                GiveBumpmine(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            GiveBumpmine(client);
        }
    }
    else if (strcmp(itemshort, KF_ITEM_SHORT, false) == 0)
    {
        if (TTT_GetClientTeam(client) != TTT_TEAM_TRAITOR)
        {
            return Plugin_Stop;
        }
        
        strcopy(sItem, sizeof(sItem), itemshort);

        g_iPlayer[client].HasKnife = true;
        g_iPlayer[client].Knives++;
    }
    else if ((strcmp(itemshort, KEV_ITEM_SHORT, false) == 0) || (strcmp(itemshort, KEV_T_ITEM_SHORT, false) == 0) || (strcmp(itemshort, KEV_D_ITEM_SHORT, false) == 0))
    {
        strcopy(sItem, sizeof(sItem), itemshort);

        if (TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
        {
            if (g_cKev_Type.IntValue == 0)
            {
                GiveArmor(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
        {
            if (g_cKev_Type.IntValue == 0 || g_cKev_Type.IntValue == 1)
            {
                GiveArmor(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            GiveArmor(client);
        }
    }
    else if ((strcmp(itemshort, KEVHELM_ITEM_SHORT, false) == 0) || (strcmp(itemshort, KEVHELM_T_ITEM_SHORT, false) == 0) || (strcmp(itemshort, KEVHELM_D_ITEM_SHORT, false) == 0))
    {
        strcopy(sItem, sizeof(sItem), itemshort);

        GiveArmor(client);
        GiveHelm(client);
    }
    else if ((strcmp(itemshort, HELM_ITEM_SHORT, false) == 0) || (strcmp(itemshort, HELM_T_ITEM_SHORT, false) == 0) || (strcmp(itemshort, HELM_D_ITEM_SHORT, false) == 0))
    {
        strcopy(sItem, sizeof(sItem), itemshort);

        if (TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
        {
            if (g_cHelm_Type.IntValue == 0)
            {
                GiveHelm(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
        {
            if (g_cHelm_Type.IntValue == 0 || g_cHelm_Type.IntValue == 1)
            {
                GiveHelm(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            GiveArmor(client);
        }
    }
    else if ((strcmp(itemshort, HEAVY_ITEM_SHORT, false) == 0) || (strcmp(itemshort, HEAVY_T_ITEM_SHORT, false) == 0) || (strcmp(itemshort, HEAVY_D_ITEM_SHORT, false) == 0))
    {
        strcopy(sItem, sizeof(sItem), itemshort);

        if (TTT_GetClientTeam(client) == TTT_TEAM_INNOCENT)
        {
            if (g_cHeavy_Type.IntValue == 0)
            {
                GiveHeavy(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
        {
            if (g_cHeavy_Type.IntValue == 0 || g_cHeavy_Type.IntValue == 1)
            {
                GiveHeavy(client);
            }
        }
        if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            GiveHeavy(client);
        }
    }

    if (strlen(sItem) > 2)
    {
        if (g_cDebugMessages != null && g_cDebugMessages.BoolValue)
        {
            CPrintToChat(client, "Item: %s", sItem);
        }
        
        TTT_AddItemUsage(client, sItem);
    }

    return Plugin_Continue;
}

void GiveBumpmine(int client)
{
    if (GetPlayerWeaponSlot(client, CS_SLOT_C4) != -1)
    {
        SDKHooks_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_C4));
    }

    int iBC = GivePlayerItem(client, "weapon_bumpmine");

    if (iBC != -1)
    {
        EquipPlayerWeapon(client, iBC);
        SetEntProp(iBC, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
        SetEntProp(iBC, Prop_Data, "m_iClip1", GetRandomInt(g_cBumpmine_Min.IntValue, g_cBumpmine_Max.IntValue));
    }
    else
    {
        TTT_SetClientCredits(client, TTT_GetClientCredits(client) + g_cBumpmine_Price.IntValue);
    }
}

void GiveArmor(int client, int armor = 100)
{
    g_iPlayer[client].Kevlar++;
    SetEntProp(client, Prop_Data, "m_ArmorValue", armor, 1);
}

void GiveHeavy(int client)
{
    g_iPlayer[client].Heavy++;
    GivePlayerItem(client, "item_heavyassaultsuit");

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

    if (IsValidEntity(weapon))
    {
        char sName[32];
        GetEntityClassname(weapon, sName, sizeof(sName));

        if ((StrContains(sName, "p90", false) == -1) && (StrContains(sName, "m249", false) == -1) &&
            (StrContains(sName, "negev", false) == -1) && (StrContains(sName, "nova", false) == -1) &&
            (StrContains(sName, "xm1014", false) == -1) && (StrContains(sName, "sawedoff", false) == -1) &&
            (StrContains(sName, "mag7", false) == -1) && (StrContains(sName, "mac10", false) == -1) &&
            (StrContains(sName, "mp9", false) == -1) && (StrContains(sName, "mp7", false) == -1) &&
            (StrContains(sName, "ump45", false) == -1) && (StrContains(sName, "bizon", false) == -1))
        {
            SDKHooks_DropWeapon(client, weapon);
        }
    }
}

void GiveHelm(int client)
{
    g_iPlayer[client].Helm++;
    SetEntProp(client, Prop_Send, "m_bHasHelmet", true);
}

void ResetStuff()
{
    LoopValidClients(i)
    {
        g_iPlayer[i].HasKnife = false;
        g_iPlayer[i].Knives = 0;
        g_iPlayer[i].Kevlar = 0;
        g_iPlayer[i].Heavy = 0;
        g_iPlayer[i].Helm = 0;

        SetEntProp(i, Prop_Send, "m_bHasHelmet", false);
        SetEntProp(i, Prop_Send, "m_bHasHeavyArmor", false);
        SetEntProp(i, Prop_Send, "m_bWearingSuit", false);
        SetEntProp(i, Prop_Data, "m_ArmorValue", 0);
    }
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3])
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if (g_iPlayer[iAttacker].HasKnife && IsValidEntity(iWeapon))
    {
        char sWeapon[64];

        GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));

        if ((StrContains(sWeapon, "knife", false) != -1) || (StrContains(sWeapon, "bayonet", false) != -1))
        {
            g_iPlayer[iAttacker].HasKnife = false;
            fDamage = float(GetClientHealth(iVictim) + GetClientArmor(iVictim));
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}
