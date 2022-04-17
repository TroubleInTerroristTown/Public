#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#undef REQUIRE_PLUGIN
#include <ttt_glow>
#include <ttt_glow_light>

#define SHORT_NAME_T "wallhack_t"
#define SHORT_NAME_D "wallhack_d"
#define LONG_NAME "Wallhack"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: " ... LONG_NAME

ConVar g_cTraitorPrice = null;
ConVar g_cTraitorLimit = null;
ConVar g_cDetectivePrice = null;
ConVar g_cDetectiveLimit = null;
ConVar g_cTraitor_Prio = null;
ConVar g_cDetective_Prio = null;
ConVar g_cTraitorCooldown = null;
ConVar g_cDetectiveCooldown = null;
ConVar g_cTraitorActive = null;
ConVar g_cDetectiveActive = null;
ConVar g_cLongName = null;
ConVar g_cColorsT = null;
ConVar g_cColorsD = null;
ConVar g_cDefaultRed = null;
ConVar g_cDefaultGreen = null;
ConVar g_cDefaultBlue = null;
ConVar g_cDefaultAlpha = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;

bool g_bGlow = false;
bool g_bGlowLight = false;

enum struct PlayerData {
    bool HasWH;
    
    Handle Timer;
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

    TTT_StartConfig("wallhack");
    CreateConVar("ttt2_wallhack_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("wallhack_name", "Wallhack", "The name of the Wallhack in the Shop");
    g_cTraitorPrice = AutoExecConfig_CreateConVar("wallhack_traitor_price", "9000", "The amount of credits the Traitor-Wallhack costs. 0 to disable.");
    g_cTraitorLimit = AutoExecConfig_CreateConVar("wallhack_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDetectivePrice = AutoExecConfig_CreateConVar("wallhack_detective_price", "0", "The amount of credits the Dective-Wallhack costs. 0 to disable.\nBy using detective wallhack it will produce some irritation with white glows, when \"wallhack_show_teams_detective\" is 0.");
    g_cDetectiveLimit = AutoExecConfig_CreateConVar("wallhack_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTraitorCooldown = AutoExecConfig_CreateConVar("wallhack_traitor_cooldown", "15.0", "Time of the cooldown for Traitor-Wallhack (time in seconds)");
    g_cDetectiveCooldown = AutoExecConfig_CreateConVar("wallhack_detective_cooldown", "15.0", "Time of the cooldown for Dective-Wallhack (time in seconds)");
    g_cTraitorActive = AutoExecConfig_CreateConVar("wallhack_traitor_active", "3.0", "Active time for Traitor-Wallhack (time in seconds)");
    g_cDetectiveActive = AutoExecConfig_CreateConVar("wallhack_detective_active", "3.0", "Active time for Dective-Wallhack (time in seconds)");
    g_cTraitor_Prio = AutoExecConfig_CreateConVar("wallhack_traitor_sort_prio", "0", "The sorting priority of the Traitor - Wallhack in the shop menu.");
    g_cDetective_Prio = AutoExecConfig_CreateConVar("wallhack_detective_sort_prio", "0", "The sorting priority of the Detective - Wallhack in the shop menu.");
    g_cColorsT = AutoExecConfig_CreateConVar("wallhack_show_teams_traitor", "1", "Show glows as teams colors for traitors?\nAttention: If you set this to 0, it cause into some issues with missing iTeam glow between traitors<->traitors and detective<->detective", _, true, 0.0, true, 1.0);
    g_cColorsD = AutoExecConfig_CreateConVar("wallhack_show_teams_detective", "0", "Show glows as teams colors for detectives?\nAttention: If you set this to 0, it cause into some issues with missing iTeam glow between traitors<->traitors and detective<->detective", _, true, 0.0, true, 1.0);
    g_cDefaultRed = AutoExecConfig_CreateConVar("wallhack_default_color_red", "255", "Red color of default glow");
    g_cDefaultGreen = AutoExecConfig_CreateConVar("wallhack_default_color_green", "255", "Green color of default glow");
    g_cDefaultBlue = AutoExecConfig_CreateConVar("wallhack_default_color_blue", "255", "Blue color of default glow");
    g_cDefaultAlpha = AutoExecConfig_CreateConVar("wallhack_default_color_alpha", "255", "Alpha of default glow");
    g_cTCount = AutoExecConfig_CreateConVar("wallhack_count_traitor", "1", "Amount of wh purchases per round for traitor");
    g_cDCount = AutoExecConfig_CreateConVar("wallhack_count_detective", "1", "Amount of wh purchases per round for detectives");
    TTT_EndConfig();
    
    HookEvent("player_spawn", Event_PlayerReset);
    HookEvent("player_death", Event_PlayerReset);
    HookEvent("round_end", Event_RoundReset);

    g_bGlow = LibraryExists("ttt_glow");
    g_bGlowLight = LibraryExists("ttt_glow_light");
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = true;
    }
    else if(StrEqual(name, "ttt_glow_light"))
    {
        g_bGlowLight = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = false;
    }
    else if(StrEqual(name, "ttt_glow_light"))
    {
        g_bGlowLight = false;
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    if (g_bGlow || g_bGlowLight)
    {
        char sBuffer[MAX_ITEM_LENGTH];
        g_cLongName.GetString(sBuffer, sizeof(sBuffer));
        TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTraitorPrice.IntValue, TTT_TEAM_TRAITOR, g_cTraitor_Prio.IntValue, g_cTCount.IntValue, g_cTraitorLimit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDetectivePrice.IntValue, TTT_TEAM_DETECTIVE, g_cDetective_Prio.IntValue, g_cDCount.IntValue, g_cDetectiveLimit.IntValue, OnItemPurchased);
    }
    else
    {
        if (LibraryExists("ttt_glow"))
        {
            g_bGlow = true;
        }
        else if(LibraryExists("ttt_glow_light"))
        {
            g_bGlowLight = true;
        }
        else
        {
            SetFailState("Neither the TTT Glow or TTT Glow Light is not enabled.");
        }
    }
}

public Action Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (TTT_IsClientValid(client))
    {
        g_iPlayer[client].HasWH = false;
    }
    
    return Plugin_Continue;
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(client)
    {
        g_iPlayer[client].HasWH = false;
    }
    
    return Plugin_Continue;
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_TRAITOR && iTeam != TTT_TEAM_DETECTIVE)
    {
        return Plugin_Stop;
    }

    g_iPlayer[client].HasWH = true;
    TTT_AddInventoryItem(client, itemshort);
    
    GlowPlayers(client, iTeam);
    return Plugin_Continue;
}

public Action Timer_WHActive(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && (TTT_IsItemInInventory(client, SHORT_NAME_D) || TTT_IsItemInInventory(client, SHORT_NAME_T)) && g_iPlayer[client].HasWH)
    {
        g_iPlayer[client].HasWH = false;
        g_iPlayer[client].Timer = null;

        if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            g_iPlayer[client].Timer = CreateTimer(g_cTraitorCooldown.FloatValue, Timer_WHCooldown, GetClientUserId(client));
        }
        else if (TTT_GetClientTeam(client) == TTT_TEAM_DETECTIVE)
        {
            g_iPlayer[client].Timer = CreateTimer(g_cDetectiveCooldown.FloatValue, Timer_WHCooldown, GetClientUserId(client));
        }
    }

    return Plugin_Stop;
}

public Action Timer_WHCooldown(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && (TTT_IsItemInInventory(client, SHORT_NAME_D) || TTT_IsItemInInventory(client, SHORT_NAME_T)) && !g_iPlayer[client].HasWH)
    {
        g_iPlayer[client].HasWH = true;
        g_iPlayer[client].Timer = null;
        
        GlowPlayers(client, TTT_GetClientTeam(client));
    }

    return Plugin_Stop;
}

void GlowPlayers(int client, int iTeam)
{
    if (iTeam != TTT_TEAM_TRAITOR && iTeam != TTT_TEAM_DETECTIVE)
    {
        return;
    }

    float fTime = iTeam == TTT_TEAM_TRAITOR ? g_cTraitorActive.FloatValue : g_cDetectiveActive.FloatValue;

    g_iPlayer[client].Timer = CreateTimer(fTime, Timer_WHActive, GetClientUserId(client));

    if ((iTeam == TTT_TEAM_TRAITOR && !g_cColorsT.BoolValue) || (iTeam == TTT_TEAM_DETECTIVE && !g_cColorsD.BoolValue))
    {
        int iColor[4];
        iColor[0] = g_cDefaultRed.IntValue;
        iColor[1] = g_cDefaultGreen.IntValue;
        iColor[2] = g_cDefaultBlue.IntValue;
        iColor[3] = g_cDefaultAlpha.IntValue;

        LoopValidClients(i)
        {
            if (g_bGlowLight)
            {
                TTT_SetGlowColorLight(i, iColor, fTime);
            }
            else if (g_bGlow)
            {
                TTT_SetGlowColor(i, iColor, fTime);
            }
        }
    }

    if (g_bGlowLight)
    {
        TTT_CanSeeAllGlowLight(client, fTime);
    }
    else if (g_bGlow)
    {
        TTT_CanSeeAllGlow(client, fTime);
    }
}
