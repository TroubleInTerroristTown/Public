#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Blackout"
#define SHORT_NAME "blackout"

#define DEFAULT_START 0.0
#define DEFAULT_END 150.0
#define DEFAULT_DENSITY 0.999

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cStart = null;
ConVar g_cEnd = null;
ConVar g_cDensity = null;
ConVar g_cTime = null;
ConVar g_cDelay = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;
ConVar g_cActivation = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH];

int g_iFog = -1;

bool g_bActive = false;

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
    
    TTT_StartConfig("blackout");
    CreateConVar("ttt2_blackout_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("blackout_name", "Blackout", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("blackout_price", "9000", "The amount of credits blackout costs as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("blackout_sort_prio", "0", "The sorting priority of the blackout in the shop menu.");
    g_cStart = AutoExecConfig_CreateConVar("blackout_fog_start", "0", "0 Should be the middle of player(?))");
    g_cEnd = AutoExecConfig_CreateConVar("blackout_fog_end", "150", "Distance from fog_start until the end (visible field for players)");
    g_cDensity = AutoExecConfig_CreateConVar("blackout_fog_density", "0.999", "Density of the fog", _, true, 0.0);
    g_cTime = AutoExecConfig_CreateConVar("blackout_time", "10", "How long persists the blackout?", _, true, 1.0);
    g_cDelay = AutoExecConfig_CreateConVar("blackout_delay", "3", "Time in seconds until the blackout starts (from inventory click).");
    g_cCount = AutoExecConfig_CreateConVar("blackout_count", "2", "Max usages for blackout per round/player. 0 - Disabled");
    g_cLimit = AutoExecConfig_CreateConVar("blackout_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cActivation = AutoExecConfig_CreateConVar("blackout_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    HookEvent("round_end", Event_RoundEnd);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    // Get some values from ttt.cfg
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    RegisterItem();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnMapStart()
{
    int iEnt = -1;
    iEnt = FindEntityByClassname(-1, "env_fog_controller");
    
    if (IsValidEntity(iEnt)) 
    {
        g_iFog = iEnt;
    }
    else
    {
        g_iFog = CreateEntityByName("env_fog_controller");
        DispatchSpawn(g_iFog);
    }
    
    SetupBlackout();
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (g_bActive)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Blackout: Already Active", client);
        return Plugin_Stop;
    }

    int role = TTT_GetClientRole(client);

    if (role != TTT_TEAM_TRAITOR)
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
        Start_Blackout(client);
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
            
            Start_Blackout(client);
        }
    }
}

void Start_Blackout(int client)
{
    CPrintToChat(client, "%s %T", g_sPluginTag, "Blackout: Starting in", client, g_cDelay.IntValue);
    CreateTimer(g_cDelay.FloatValue, Timer_StartBlackout, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetBlackout();
}

void ResetBlackout()
{
    StopBlackout();
}

void SetupBlackout()
{
    if(IsValidEntity(g_iFog))
    {
        DispatchKeyValue(g_iFog, "fogblend", "0");
        DispatchKeyValue(g_iFog, "fogcolor", "0 0 0");
        DispatchKeyValue(g_iFog, "fogcolor2", "0 0 0");
        
        if (g_cStart != null && g_cStart.FloatValue != DEFAULT_START)
        {
            DispatchKeyValueFloat(g_iFog, "fogstart", g_cStart.FloatValue);
        }
        else
        {
            DispatchKeyValueFloat(g_iFog, "fogstart", DEFAULT_START);
        }
        
        if (g_cEnd != null && g_cEnd.FloatValue != DEFAULT_END)
        {
            DispatchKeyValueFloat(g_iFog, "fogend", g_cEnd.FloatValue);
        }
        else
        {
            DispatchKeyValueFloat(g_iFog, "fogend", DEFAULT_END);
        }
        
        if (g_cDensity != null && g_cDensity.FloatValue != DEFAULT_DENSITY)
        {
            DispatchKeyValueFloat(g_iFog, "fogmaxdensity", g_cDensity.FloatValue);
        }
        else
        {
            DispatchKeyValueFloat(g_iFog, "fogmaxdensity", DEFAULT_DENSITY);
        }
        
        AcceptEntityInput(g_iFog, "TurnOff");
    }
}

public Action Timer_StartBlackout(Handle timer)
{
    StartBlackout();
    
    return Plugin_Stop;
}

void StartBlackout()
{
    AcceptEntityInput(g_iFog, "TurnOn");
    g_bActive = true;
    
    CreateTimer(g_cTime.FloatValue, Timer_StopBlackout, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_StopBlackout(Handle timer)
{
    StopBlackout();
    
    return Plugin_Stop;
}

void StopBlackout()
{
    AcceptEntityInput(g_iFog, "TurnOff");
    g_bActive = false;
}

