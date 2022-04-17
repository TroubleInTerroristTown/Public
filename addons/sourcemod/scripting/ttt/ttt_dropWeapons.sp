#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Drop Weapons"

#define SHORT_NAME "dropW"

ConVar g_cLongName = null;
ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;
ConVar g_cDistance = null;
ConVar g_cDropMode = null;
ConVar g_cCooldown = null;
ConVar g_cDropTraitorWeapons = null;
ConVar g_cActivation = null;

int g_iBeamSprite = -1;
int g_iBeamHaloSprite = -1;

enum struct PlayerData {
    bool Cooldown;
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

    TTT_StartConfig("drop");
    CreateConVar("ttt2_drop_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("drop_name", "Drop", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("drop_price", "9000", "The amount of credits a Drop costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("drop_sort_prio", "0", "The sorting priority of the Drop in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("drop_max_usage", "1", "Usages per round", _, true, 1.0);
    g_cLimit = AutoExecConfig_CreateConVar("drop_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDistance = AutoExecConfig_CreateConVar("drop_distance", "500", "Distance between client and target");
    g_cDropMode = AutoExecConfig_CreateConVar("drop_mode", "1", "0 - Just drop primary weapons, 1 - Drop primary weapons (no pickup for x seconds)", _, true, 0.0, true, 1.0);
    g_cCooldown = AutoExecConfig_CreateConVar("drop_cooldown", "9", "Cooldown to allow pickup again (drop_drop_mode must be higher as 0)");
    g_cDropTraitorWeapons = AutoExecConfig_CreateConVar("drop_traitor_weapons", "0", "Drop all traitor weapons? If it true just the caller does not drop his weapons", _, true, 0.0, true, 1.0);
    g_cActivation = AutoExecConfig_CreateConVar("drop_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    LoopValidClients(client)
    {
        OnClientPutInServer(client);
    }

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void OnMapStart()
{
    g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iBeamHaloSprite = PrecacheModel("materials/sprites/glow.vmt");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeapon);
    SDKHook(client, SDKHook_WeaponEquip, OnWeapon);
    SDKHook(client, SDKHook_WeaponSwitch, OnWeapon);
}

public Action OnWeapon(int client, int weapon)
{
    if (g_iPlayer[client].Cooldown && TTT_IsPrimaryWeapon(weapon))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    if (g_cActivation.IntValue == 0)
    {
        TTT_AddInventoryItem(client, SHORT_NAME);
    }
    else if (g_cActivation.IntValue == 1)
    {
        TTT_AddItemUsage(client, SHORT_NAME);
        Start_DropWeapons(client);
    }
    
    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client) && StrEqual(itemshort, SHORT_NAME))
    {
        if (TTT_IsItemInInventory(client, SHORT_NAME))
        {
            TTT_RemoveInventoryItem(client, SHORT_NAME);
            TTT_AddItemUsage(client, SHORT_NAME);

            Start_DropWeapons(client);
        }
    }
}

void Start_DropWeapons(int client)
{
    // Create Beam Ring for checking range
    ConVar cDebug = FindConVar("ttt_debug_mode");
    if (cDebug != null && cDebug.BoolValue)
    {
        PrintToChatAll("Beacon Test");
        float fClientPos[3];
        GetClientAbsOrigin(client, fClientPos);
        TE_SetupBeamRingPoint(fClientPos, 1000.0, 999.9, g_iBeamSprite, g_iBeamHaloSprite, 65, 60, 10.0, 2.0, 0.5, {0, 255, 0, 255}, 5, 0);
        TE_SendToAll();
    }

    LoopValidClients(i)
    {
        if (IsClientInRange(client, i))
        {
            if (client == i)
            {
                continue;
            }

            if (TTT_GetClientTeam(i) == TTT_TEAM_TRAITOR && !g_cDropTraitorWeapons.BoolValue)
            {
                continue;
            }

            DropWeapons(i);

            if (g_cDropMode.IntValue == 1)
            {
                g_iPlayer[i].Cooldown = true;
            }

            // Print all players in client chat which are in range
            if (cDebug != null && cDebug.BoolValue)
            {
                CPrintToChat(client, "%N is in range", i);
            }
        }
    }

    CreateTimer(g_cCooldown.FloatValue, Timer_Cooldown);
}

public Action Timer_Cooldown(Handle timer)
{
    LoopValidClients(client)
    {
        g_iPlayer[client].Cooldown = false;
    }
    
    return Plugin_Handled;
}

void DropWeapons(int client)
{
    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (weapon != -1)
    {
        SDKHooks_DropWeapon(client, weapon);
    }
}

public void OnClientDisconnect(int client)
{
    ResetDrop(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetDrop(client);
    }
    
    return Plugin_Continue;
}

void ResetDrop(int client)
{
    g_iPlayer[client].Cooldown = false;
}

bool IsClientInRange(int client, int target)
{
    float fCOrigin[3], fTOrigin[3];

    GetEntPropVector(client, Prop_Send, "m_vecOrigin", fCOrigin);
    GetEntPropVector(target, Prop_Send, "m_vecOrigin", fTOrigin);

    if (GetVectorDistance(fCOrigin, fTOrigin) > g_cDistance.FloatValue)
    {
        return false;
    }

    return true;
}
