#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#pragma newdecls required

#define SHORT_NAME_I "md_i"
#define SHORT_NAME_T "md_t"
#define SHORT_NAME_D "md_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Martydom"

ConVar g_cLongName = null;
ConVar g_cGrenadeDelay = null;
ConVar g_cDamage = null;
ConVar g_cExplosionSize = null;
ConVar g_cIPrice = null;
ConVar g_cILimit = null;
ConVar g_cIPrio = null;
ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cDPrio = null;
ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cTPrio = null;
ConVar g_cCountI = null;
ConVar g_cCountT = null;
ConVar g_cCountD = null;

enum struct PlayerData {
    float Location[3];
}

PlayerData g_iPlayer[MAXPLAYERS + 1];


/* Drops a live high explosive grenade on a players body */

public Plugin myinfo = 
{
    name = PLUGIN_NAME, 
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION, 
    version = TTT_PLUGIN_VERSION, 
    url = TTT_PLUGIN_URL
};

public void OnPluginStart() {

    TTT_IsGameCSGO();
    
    TTT_LoadTranslations();

    TTT_StartConfig("martydom");
    CreateConVar("ttt2_martydom_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("martydom_name", "Martydom", "The name of this item in the shop.");
    g_cIPrice = AutoExecConfig_CreateConVar("martydom_price_innocent", "2000", "The amount of credits martydom costs as innocent. 0 to disable.");    
    g_cILimit = AutoExecConfig_CreateConVar("martydom_limit_innocent", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTPrice = AutoExecConfig_CreateConVar("martydom_price_traitor", "2000", "The amount of credits martydom costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("martydom_limit_traitor", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("martydom_price_detective", "2000", "The amount of credits martydom costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("martydom_limit_detective", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIPrio = AutoExecConfig_CreateConVar("martydom_sort_prio_innocent", "0", "The sorting priority of the martydom in the shop menu for innocents.");
    g_cTPrio = AutoExecConfig_CreateConVar("martydom_sort_prio_traitor", "0", "The sorting priority of the martydom in the shop menu for traitors.");
    g_cDPrio = AutoExecConfig_CreateConVar("martydom_sort_prio_detective", "0", "The sorting priority of the martydom in the shop menu for detectives.");
    g_cCountI = AutoExecConfig_CreateConVar("martydom_count_innocent", "1", "How often the item (Martydom) can be bought per round as an innocent (0 - Disabled)."); // These seem pointless less someone get respawned
    g_cCountT = AutoExecConfig_CreateConVar("martydom_count_traitor", "1", "How often the item (Martydom) can be bought per round as a traitor (0 - Disabled).");
    g_cCountD = AutoExecConfig_CreateConVar("martydom_count_detective", "1", "How often the item (Martydom) can be bought per round as a detective (0 - Disabled).");
    g_cGrenadeDelay = AutoExecConfig_CreateConVar("martydom_grenade_delay", "0.25", "The time delay it takes for the grenade to spawn after a player dies. Decimals allowed. (Def. 0.25)");
    g_cDamage = AutoExecConfig_CreateConVar("martydom_grenade_damage", "99.0", "The damage the grenade does at the explosions center point. Decimals allowed. (Def. 99.0)");
    g_cExplosionSize = AutoExecConfig_CreateConVar("martydom_explosion_size", "350.0", "The size of the explosion. Decimals allowed. (Def. 350.0)");
    TTT_EndConfig();

    HookEvent("player_death", Event_PlayerDeath);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_I);
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
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
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME_I, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cCountI.IntValue, g_cILimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cCountT.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cCountD.IntValue, g_cDLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (TTT_IsItemInInventory(client, itemshort))
    {
        return Plugin_Stop;
    }

    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public Action Timer_CreateGrenade(Handle timer, any client)
{
    if(TTT_IsClientValid(client))
    {
        CreateGrenade(client);
    }
    
    return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool inrestart)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if(!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }
        
    if(!TTT_IsItemInInventory(client, SHORT_NAME_I) && !TTT_IsItemInInventory(client, SHORT_NAME_T) && !TTT_IsItemInInventory(client, SHORT_NAME_D))
    {
        return Plugin_Continue;
    }
    
    GetClientAbsOrigin(client, g_iPlayer[client].Location);
    CreateTimer(g_cGrenadeDelay.FloatValue, Timer_CreateGrenade, event.GetInt("userid"));
    
    if (TTT_RemoveInventoryItem(client, SHORT_NAME_I))
    {
        TTT_AddItemUsage(client, SHORT_NAME_I);
    }

    if (TTT_RemoveInventoryItem(client, SHORT_NAME_T))
    {
        TTT_AddItemUsage(client, SHORT_NAME_T);
    }

    if (TTT_RemoveInventoryItem(client, SHORT_NAME_D))
    {
        TTT_AddItemUsage(client, SHORT_NAME_D);
    }

    
    return Plugin_Continue;
    
}

public void CreateGrenade(int userid)
{
    int client = GetClientOfUserId(userid);

    if (!TTT_IsClientValid(client))
    {
        return;
    }

    int iEntity = CreateEntityByName("hegrenade_projectile");

    // Make sure the grenade doesn't spawn in the ground
    g_iPlayer[client].Location[2] += 30;
    TeleportEntity(iEntity, g_iPlayer[client].Location, NULL_VECTOR, NULL_VECTOR);

    if (DispatchSpawn(iEntity))
    {
        AcceptEntityInput(iEntity, "InitializeSpawnFromWorld");
        
        SetEntPropEnt(iEntity, Prop_Data, "m_hThrower", client);
        SetEntProp(iEntity, Prop_Data, "m_iTeamNum", GetClientTeam(client));
        SetEntPropFloat(iEntity, Prop_Data, "m_flDamage", g_cDamage.FloatValue);
        SetEntPropFloat(iEntity, Prop_Data, "m_DmgRadius", g_cExplosionSize.FloatValue); 
    }
}
