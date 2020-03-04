#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#undef REQUIRE_PLUGIN
#include <futuristicgrenades>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Futuristic Grenades"

#define BH_SNAME_I "blackhole_i"
#define BH_SNAME_T "blackhole_t"
#define BH_SNAME_D "blackhole_d"
#define FF_SNAME_I "forcefield_i"
#define FF_SNAME_T "forcefield_t"
#define FF_SNAME_D "forcefield_d"
#define FE_SNAME_I "explosion_i"
#define FE_SNAME_T "explosion_t"
#define FE_SNAME_D "explosion_d"
#define FI_SNAME_I "implosion_i"
#define FI_SNAME_T "implosion_t"
#define FI_SNAME_D "implosion_d"
#define FUTURISTIC_I "futuristic_i"
#define FUTURISTIC_T "futuristic_t"
#define FUTURISTIC_D "futuristic_d"

ConVar g_cOneTime = null;
ConVar g_cGiveDecoy = null;
ConVar g_cLongNameF = null;
ConVar g_cPriceFI = null;
ConVar g_cLimitFI = null;
ConVar g_cPriceFT = null;
ConVar g_cLimitFT = null;
ConVar g_cPriceFD = null;
ConVar g_cLimitFD = null;
ConVar g_cPrioFI = null;
ConVar g_cPrioFT = null;
ConVar g_cPrioFD = null;
ConVar g_cCountFI = null;
ConVar g_cCountFT = null;
ConVar g_cCountFD = null;
ConVar g_cLongNameBH = null;
ConVar g_cPriceBHI = null;
ConVar g_cLimitBHI = null;
ConVar g_cPriceBHT = null;
ConVar g_cLimitBHT = null;
ConVar g_cPriceBHD = null;
ConVar g_cLimitBHD = null;
ConVar g_cPrioBHI = null;
ConVar g_cPrioBHT = null;
ConVar g_cPrioBHD = null;
ConVar g_cCountBHI = null;
ConVar g_cCountBHT = null;
ConVar g_cCountBHD = null;
ConVar g_cLongNameFF = null;
ConVar g_cPriceFFI = null;
ConVar g_cLimitFFI = null;
ConVar g_cPriceFFT = null;
ConVar g_cLimitFFT = null;
ConVar g_cPriceFFD = null;
ConVar g_cLimitFFD = null;
ConVar g_cPrioFFI = null;
ConVar g_cPrioFFT = null;
ConVar g_cPrioFFD = null;
ConVar g_cCountFFI = null;
ConVar g_cCountFFT = null;
ConVar g_cCountFFD = null;
ConVar g_cLongNameFE = null;
ConVar g_cPriceFEI = null;
ConVar g_cLimitFEI = null;
ConVar g_cPriceFET = null;
ConVar g_cLimitFET = null;
ConVar g_cPriceFED = null;
ConVar g_cLimitFED = null;
ConVar g_cPrioFEI = null;
ConVar g_cPrioFET = null;
ConVar g_cPrioFED = null;
ConVar g_cCountFEI = null;
ConVar g_cCountFET = null;
ConVar g_cCountFED = null;
ConVar g_cLongNameFI = null;
ConVar g_cPriceFII = null;
ConVar g_cLimitFII = null;
ConVar g_cPriceFIT = null;
ConVar g_cLimitFIT = null;
ConVar g_cPriceFID = null;
ConVar g_cLimitFID = null;
ConVar g_cPrioFII = null;
ConVar g_cPrioFIT = null;
ConVar g_cPrioFID = null;
ConVar g_cCountFII = null;
ConVar g_cCountFIT = null;
ConVar g_cCountFID = null;

enum struct PlayerData {
    bool HasAll;
    DecoyMode Mode;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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

    TTT_LoadTranslations();

    TTT_StartConfig("futuristicgrenades");
    CreateConVar("ttt2_futuristic_grenades_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cOneTime = AutoExecConfig_CreateConVar("futuristic_one_time", "1", "Effect for just one grenade?", _, true, 0.0, true, 1.0);
    g_cGiveDecoy = AutoExecConfig_CreateConVar("futuristic_give_decoy", "1", "Give decoy on purchase?", _, true, 0.0, true, 1.0);

    g_cLongNameF = AutoExecConfig_CreateConVar("futuristic_name", "Futuristic Grenades", "The name of this in Shop");
    g_cPriceFI = AutoExecConfig_CreateConVar("futuristic_price_innocent", "20000", "The amount of credits futuristic grenades costs as innocent. 0 to disable.");
    g_cLimitFI = AutoExecConfig_CreateConVar("futuristic_limit_innocent", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFT = AutoExecConfig_CreateConVar("futuristic_price_traitor", "20000", "The amount of credits futuristic grenades costs as traitor. 0 to disable.");
    g_cLimitFT = AutoExecConfig_CreateConVar("futuristic_limit_traitor", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFD = AutoExecConfig_CreateConVar("futuristic_price_detective", "20000", "The amount of credits futuristic grenades costs as detective. 0 to disable.");
    g_cLimitFD = AutoExecConfig_CreateConVar("futuristic_limit_detective", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPrioFI = AutoExecConfig_CreateConVar("futuristic_sort_prio_innocent", "0", "The sorting priority of the futuristic grenades in the shop menu for innocents.");
    g_cPrioFT = AutoExecConfig_CreateConVar("futuristic_sort_prio_traitor", "0", "The sorting priority of the futuristic grenades in the shop menu for traitors.");
    g_cPrioFD = AutoExecConfig_CreateConVar("futuristic_sort_prio_detective", "0", "The sorting priority of the futuristic grenades in the shop menu for detectives.");
    g_cCountFI = AutoExecConfig_CreateConVar("futuristic_count_innocent", "1", "How often the item (Futuristic Grenade) can be bought per round as an innocent (0 - Disabled).");
    g_cCountFT = AutoExecConfig_CreateConVar("futuristic_count_traitor", "1", "How often the item (Futuristic Grenade) can be bought per round as a traitor (0 - Disabled).");
    g_cCountFD = AutoExecConfig_CreateConVar("futuristic_count_detective", "1", "How often the item (Futuristic Grenade) can be bought per round as a detective (0 - Disabled).");

    g_cLongNameFF = AutoExecConfig_CreateConVar("forcefield_name", "Force Field", "The name of this in Shop");
    g_cPriceFFI = AutoExecConfig_CreateConVar("forcefield_price_innocent", "8000", "The amount of credits forcefield grenades costs as innocent. 0 to disable.");
    g_cLimitFFI = AutoExecConfig_CreateConVar("forcefield_limit_innocent", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFFT = AutoExecConfig_CreateConVar("forcefield_price_traitor", "8000", "The amount of credits forcefield grenades costs as traitor. 0 to disable.");
    g_cLimitFFT = AutoExecConfig_CreateConVar("forcefield_limit_traitor", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFFD = AutoExecConfig_CreateConVar("forcefield_price_detective", "8000", "The amount of credits forcefield grenades costs as detective. 0 to disable.");
    g_cLimitFFD = AutoExecConfig_CreateConVar("forcefield_limit_detective", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPrioFFI = AutoExecConfig_CreateConVar("forcefield_sort_prio_innocent", "0", "The sorting priority of the forcefield grenades in the shop menu for innocents.");
    g_cPrioFFT = AutoExecConfig_CreateConVar("forcefield_sort_prio_traitor", "0", "The sorting priority of the forcefield grenades in the shop menu for traitors.");
    g_cPrioFFD = AutoExecConfig_CreateConVar("forcefield_sort_prio_detective", "0", "The sorting priority of the forcefield grenades in the shop menu for detectives.");
    g_cCountFFI = AutoExecConfig_CreateConVar("forcefield_count_innocent", "1", "How often the item (Force Field) can be bought per round as an innocent (0 - Disabled).");
    g_cCountFFT = AutoExecConfig_CreateConVar("forcefield_count_traitor", "1", "How often the item (Force Field) can be bought per round as a traitor (0 - Disabled).");
    g_cCountFFD = AutoExecConfig_CreateConVar("forcefield_count_detective", "1", "How often the item (Force Field) can be bought per round as a detective (0 - Disabled).");

    g_cLongNameBH = AutoExecConfig_CreateConVar("blackhole_name", "Blackhole", "The name of this in Shop");
    g_cPriceBHI = AutoExecConfig_CreateConVar("blackhole_price_innocent", "8000", "The amount of credits blackhole grenades costs as innocent. 0 to disable.");
    g_cLimitBHI = AutoExecConfig_CreateConVar("blackhole_limit_innocent", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceBHT = AutoExecConfig_CreateConVar("blackhole_price_traitor", "8000", "The amount of credits blackhole grenades costs as traitor. 0 to disable.");
    g_cLimitBHT = AutoExecConfig_CreateConVar("blackhole_limit_traitor", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceBHD = AutoExecConfig_CreateConVar("blackhole_price_detective", "8000", "The amount of credits blackhole grenades costs as detective. 0 to disable.");
    g_cLimitBHD = AutoExecConfig_CreateConVar("blackhole_limit_detective", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPrioBHI = AutoExecConfig_CreateConVar("blackhole_sort_prio_innocent", "0", "The sorting priority of the blackhole grenades in the shop menu for innocents.");
    g_cPrioBHT = AutoExecConfig_CreateConVar("blackhole_sort_prio_traitor", "0", "The sorting priority of the blackhole grenades in the shop menu for traitors.");
    g_cPrioBHD = AutoExecConfig_CreateConVar("blackhole_sort_prio_detective", "0", "The sorting priority of the blackhole grenades in the shop menu for detectives.");
    g_cCountBHI = AutoExecConfig_CreateConVar("blackhole_count_innocent", "1", "How often the item (Blackhole Grenade) can be bought per round as an innocent (0 - Disabled).");
    g_cCountBHT = AutoExecConfig_CreateConVar("blackhole_count_traitor", "1", "How often the item (Blackhole Grenade) can be bought per round as a traitor (0 - Disabled).");
    g_cCountBHD = AutoExecConfig_CreateConVar("blackhole_count_detective", "1", "How often the item (Blackhole Grenade) can be bought per round as a detective (0 - Disabled).");

    g_cLongNameFE = AutoExecConfig_CreateConVar("explosion_name", "Force Explosion", "The name of this in Shop");
    g_cPriceFEI = AutoExecConfig_CreateConVar("explosion_price_innocent", "8000", "The amount of credits explosion grenades costs as innocent. 0 to disable.");
    g_cLimitFEI = AutoExecConfig_CreateConVar("explosion_limit_innocent", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFET = AutoExecConfig_CreateConVar("explosion_price_traitor", "8000", "The amount of credits explosion grenades costs as traitor. 0 to disable.");
    g_cLimitFET = AutoExecConfig_CreateConVar("explosion_limit_traitor", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFED = AutoExecConfig_CreateConVar("explosion_price_detective", "8000", "The amount of credits explosion grenades costs as detective. 0 to disable.");
    g_cLimitFED = AutoExecConfig_CreateConVar("explosion_limit_detective", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPrioFEI = AutoExecConfig_CreateConVar("explosion_sort_prio_innocent", "0", "The sorting priority of the explosion grenades in the shop menu for innocents.");
    g_cPrioFET = AutoExecConfig_CreateConVar("explosion_sort_prio_traitor", "0", "The sorting priority of the explosion grenades in the shop menu for traitors.");
    g_cPrioFED = AutoExecConfig_CreateConVar("explosion_sort_prio_detective", "0", "The sorting priority of the explosion grenades in the shop menu for detectives.");
    g_cCountFEI = AutoExecConfig_CreateConVar("explosion_count_innocent", "1", "How often the item (Explosion Grenade) can be bought per round as an innocent (0 - Disabled).");
    g_cCountFET = AutoExecConfig_CreateConVar("explosion_count_traitor", "1", "How often the item (Explosion Grenade) can be bought per round as a traitor (0 - Disabled).");
    g_cCountFED = AutoExecConfig_CreateConVar("explosion_count_detective", "1", "How often the item (Explosion Grenade) can be bought per round as a detective (0 - Disabled).");

    g_cLongNameFI = AutoExecConfig_CreateConVar("implosion_name", "Force Implosion", "The name of this in Shop");
    g_cPriceFII = AutoExecConfig_CreateConVar("implosion_price_innocent", "8000", "The amount of credits implosion grenades costs as innocent. 0 to disable.");
    g_cLimitFII = AutoExecConfig_CreateConVar("implosion_limit_innocent", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFIT = AutoExecConfig_CreateConVar("implosion_price_traitor", "8000", "The amount of credits implosion grenades costs as traitor. 0 to disable.");
    g_cLimitFIT = AutoExecConfig_CreateConVar("implosion_limit_traitor", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPriceFID = AutoExecConfig_CreateConVar("implosion_price_detective", "8000", "The amount of credits implosion grenades costs as detective. 0 to disable.");
    g_cLimitFID = AutoExecConfig_CreateConVar("implosion_limit_detective", "0", "The amount of purchases for all players during a round (0 - no limit).", _, true, 0.0);
    g_cPrioFII = AutoExecConfig_CreateConVar("implosion_sort_prio_innocent", "0", "The sorting priority of the implosion grenades in the shop menu for innocents.");
    g_cPrioFIT = AutoExecConfig_CreateConVar("implosion_sort_prio_traitor", "0", "The sorting priority of the implosion grenades in the shop menu for traitors.");
    g_cPrioFID = AutoExecConfig_CreateConVar("implosion_sort_prio_detective", "0", "The sorting priority of the implosion grenades in the shop menu for detectives.");
    g_cCountFII = AutoExecConfig_CreateConVar("implosion_count_innocent", "1", "How often the item (Implosion Grenade) can be bought per round as an innocent (0 - Disabled).");
    g_cCountFIT = AutoExecConfig_CreateConVar("implosion_count_traitor", "1", "How often the item (Implosion Grenade) can be bought per round as a traitor (0 - Disabled).");
    g_cCountFID = AutoExecConfig_CreateConVar("implosion_count_detective", "1", "How often the item (Implosion Grenade) can be bought per round as a detective (0 - Disabled).");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(FUTURISTIC_I);
        TTT_RemoveShopItem(FUTURISTIC_T);
        TTT_RemoveShopItem(FUTURISTIC_D);
        TTT_RemoveShopItem(FF_SNAME_I);
        TTT_RemoveShopItem(FF_SNAME_T);
        TTT_RemoveShopItem(FF_SNAME_D);
        TTT_RemoveShopItem(BH_SNAME_I);
        TTT_RemoveShopItem(BH_SNAME_T);
        TTT_RemoveShopItem(BH_SNAME_D);
        TTT_RemoveShopItem(FE_SNAME_I);
        TTT_RemoveShopItem(FE_SNAME_T);
        TTT_RemoveShopItem(FE_SNAME_D);
        TTT_RemoveShopItem(FI_SNAME_I);
        TTT_RemoveShopItem(FI_SNAME_T);
        TTT_RemoveShopItem(FI_SNAME_D);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "futuristicgrenades.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
    {
        TTT_RemoveShopItem(FUTURISTIC_I);
        TTT_RemoveShopItem(FUTURISTIC_T);
        TTT_RemoveShopItem(FUTURISTIC_D);
        TTT_RemoveShopItem(FF_SNAME_I);
        TTT_RemoveShopItem(FF_SNAME_T);
        TTT_RemoveShopItem(FF_SNAME_D);
        TTT_RemoveShopItem(BH_SNAME_I);
        TTT_RemoveShopItem(BH_SNAME_T);
        TTT_RemoveShopItem(BH_SNAME_D);
        TTT_RemoveShopItem(FE_SNAME_I);
        TTT_RemoveShopItem(FE_SNAME_T);
        TTT_RemoveShopItem(FE_SNAME_D);
        TTT_RemoveShopItem(FI_SNAME_I);
        TTT_RemoveShopItem(FI_SNAME_T);
        TTT_RemoveShopItem(FI_SNAME_D);
        SetFailState("You must have this plugin as base plugin for this items: https://forums.alliedmods.net/showthread.php?p=2499362");
        return;
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongNameF.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(FUTURISTIC_I, sBuffer, g_cPriceFI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFI.IntValue, g_cCountFI.IntValue, g_cLimitFI.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FUTURISTIC_T, sBuffer, g_cPriceFT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFT.IntValue, g_cCountFT.IntValue, g_cLimitFT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FUTURISTIC_D, sBuffer, g_cPriceFD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFD.IntValue, g_cCountFD.IntValue, g_cLimitFD.IntValue, OnItemPurchased);
    
    g_cLongNameFF.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(FF_SNAME_I, sBuffer, g_cPriceFFI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFFI.IntValue, g_cCountFFI.IntValue, g_cLimitFFI.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FF_SNAME_T, sBuffer, g_cPriceFFT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFFT.IntValue, g_cCountFFT.IntValue, g_cLimitFFT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FF_SNAME_D, sBuffer, g_cPriceFFD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFFD.IntValue, g_cCountFFD.IntValue, g_cLimitFFD.IntValue, OnItemPurchased);
    
    g_cLongNameBH.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(BH_SNAME_I, sBuffer, g_cPriceBHI.IntValue, TTT_TEAM_INNOCENT, g_cPrioBHI.IntValue, g_cCountBHI.IntValue, g_cLimitBHI.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(BH_SNAME_T, sBuffer, g_cPriceBHT.IntValue, TTT_TEAM_TRAITOR, g_cPrioBHT.IntValue, g_cCountBHT.IntValue, g_cLimitBHT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(BH_SNAME_D, sBuffer, g_cPriceBHD.IntValue, TTT_TEAM_DETECTIVE, g_cPrioBHD.IntValue, g_cCountBHD.IntValue, g_cLimitBHD.IntValue, OnItemPurchased);
    
    g_cLongNameFE.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(FE_SNAME_I, sBuffer, g_cPriceFEI.IntValue, TTT_TEAM_INNOCENT, g_cPrioFEI.IntValue, g_cCountFEI.IntValue, g_cLimitFEI.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FE_SNAME_T, sBuffer, g_cPriceFET.IntValue, TTT_TEAM_TRAITOR, g_cPrioFET.IntValue, g_cCountFET.IntValue, g_cLimitFET.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FE_SNAME_D, sBuffer, g_cPriceFED.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFED.IntValue, g_cCountFED.IntValue, g_cLimitFED.IntValue, OnItemPurchased);
    
    g_cLongNameFI.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(FI_SNAME_I, sBuffer, g_cPriceFII.IntValue, TTT_TEAM_INNOCENT, g_cPrioFII.IntValue, g_cCountFII.IntValue, g_cLimitFII.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FI_SNAME_T, sBuffer, g_cPriceFIT.IntValue, TTT_TEAM_TRAITOR, g_cPrioFIT.IntValue, g_cCountFIT.IntValue, g_cLimitFIT.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(FI_SNAME_D, sBuffer, g_cPriceFID.IntValue, TTT_TEAM_DETECTIVE, g_cPrioFID.IntValue, g_cCountFID.IntValue, g_cLimitFID.IntValue, OnItemPurchased);
}

public void OnClientDisconnect(int client)
{
    ResetFuturistic(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetFuturistic(client);
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientRole(client);
    
    // All grenades
    if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FUTURISTIC_I, false)) ||
        (role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FUTURISTIC_T, false)) ||
        (role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FUTURISTIC_D, false)))
    {
        if (g_iPlayer[client].HasAll || g_iPlayer[client].Mode != DecoyMode_Normal)
        {
            return Plugin_Stop;
        }

        g_iPlayer[client].HasAll = true;
        
        if (g_cGiveDecoy.BoolValue)
        {
            GivePlayerItem(client, "weapon_decoy");
        }

        TTT_AddItemUsage(client, itemshort);
    }
    
    // Forcefield
    if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FF_SNAME_I, false)) ||
        (role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FF_SNAME_T, false)) ||
        (role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FF_SNAME_D, false)))
    {
        if (g_iPlayer[client].HasAll || g_iPlayer[client].Mode != DecoyMode_Normal)
        {
            return Plugin_Stop;
        }
        
        g_iPlayer[client].Mode = DecoyMode_Forcefield;
        FGrenades_SwitchMode(client, DecoyMode_Forcefield);
        
        if (g_cGiveDecoy.BoolValue)
        {
            GivePlayerItem(client, "weapon_decoy");
        }

        TTT_AddItemUsage(client, itemshort);
    }
    
    // Blackhole
    if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, BH_SNAME_I, false)) ||
        (role == TTT_TEAM_TRAITOR && StrEqual(itemshort, BH_SNAME_T, false)) ||
        (role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, BH_SNAME_D, false)))
    {
        if (g_iPlayer[client].HasAll || g_iPlayer[client].Mode != DecoyMode_Normal)
        {
            return Plugin_Stop;
        }
        
        g_iPlayer[client].Mode = DecoyMode_Blackhole;
        FGrenades_SwitchMode(client, DecoyMode_Blackhole);
        
        if (g_cGiveDecoy.BoolValue)
        {
            GivePlayerItem(client, "weapon_decoy");
        }

        TTT_AddItemUsage(client, itemshort);
    }
    
    // Explosion
    if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FE_SNAME_I, false)) ||
        (role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FE_SNAME_T, false)) ||
        (role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FE_SNAME_D, false)))
    {
        if (g_iPlayer[client].HasAll || g_iPlayer[client].Mode != DecoyMode_Normal)
        {
            return Plugin_Stop;
        }
        
        g_iPlayer[client].Mode = DecoyMode_ForceExplosion;
        FGrenades_SwitchMode(client, DecoyMode_ForceExplosion);
        
        if (g_cGiveDecoy.BoolValue)
        {
            GivePlayerItem(client, "weapon_decoy");
        }

        TTT_AddItemUsage(client, itemshort);
    }
    
    // Implosion
    if (role == TTT_TEAM_INNOCENT && (StrEqual(itemshort, FI_SNAME_I, false)) ||
        (role == TTT_TEAM_TRAITOR && StrEqual(itemshort, FI_SNAME_T, false)) ||
        (role == TTT_TEAM_DETECTIVE && StrEqual(itemshort, FI_SNAME_D, false)))
    {
        if (g_iPlayer[client].HasAll || g_iPlayer[client].Mode != DecoyMode_Normal)
        {
            return Plugin_Stop;
        }
        
        g_iPlayer[client].Mode = DecoyMode_ForceImplosion;
        FGrenades_SwitchMode(client, DecoyMode_ForceImplosion);
        
        if (g_cGiveDecoy.BoolValue)
        {
            GivePlayerItem(client, "weapon_decoy");
        }

        TTT_AddItemUsage(client, itemshort);
    }
    
    return Plugin_Continue;
}

public Action FGrenades_OnSwitchMode(int client, DecoyMode previousmode, DecoyMode &newmode, int weapon)
{
    if (!g_iPlayer[client].HasAll && g_iPlayer[client].Mode == DecoyMode_Normal && newmode != DecoyMode_Normal)
    {
        newmode = DecoyMode_Normal;
        return Plugin_Continue;
    }
    
    if (g_iPlayer[client].HasAll)
    {
        return Plugin_Continue;
    }
    
    if (g_iPlayer[client].Mode > DecoyMode_Normal)
    {
        if (newmode != g_iPlayer[client].Mode)
        {
            newmode = g_iPlayer[client].Mode;
        }
        
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}

public void FGrenades_OnGrenadeStart(int owner, int &particle, float pos[3], DecoyMode mode, int duration)
{
    if (g_cOneTime.BoolValue && (g_iPlayer[owner].HasAll || g_iPlayer[owner].Mode != DecoyMode_Normal))
    {
        ResetFuturistic(owner);
    }
}

void ResetFuturistic(int client)
{
    g_iPlayer[client].HasAll = false;
    g_iPlayer[client].Mode = DecoyMode_Normal;
    
    if (IsClientInGame(client))
    {
        FGrenades_SwitchMode(client, DecoyMode_Normal);
    }
}
