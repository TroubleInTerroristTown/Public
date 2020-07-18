#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <ttt_bodies>
#include <ttt_inventory>
#include <ttt_grabbermod>
#include <colorlib>

#pragma newdecls required

#define SHORT_NAME_D "revive_d"
#define SHORT_NAME_T "revive_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Revive"

ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cLongName = null;
ConVar g_cReviveT = null;
ConVar g_cReviveD = null;
ConVar g_cHealthT = null;
ConVar g_cHealthD = null;
ConVar g_cTimeToAccept = null;
ConVar g_cTimeToNextMessage = null;
ConVar g_cStopMovement = null;
ConVar g_cReviveDistance = null;
ConVar g_cLineOfSight = null;

ConVar g_cDebug = null;
ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

Handle g_hSyncT = null;
Handle g_hSyncB = null;

enum struct PlayerData {
    int Ragdoll;
    int Countdown;
    int StartTime;
    int EndTime;
    int LastMessage;

    bool InUse;
    bool Wait;
    bool Menu;

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

    TTT_LoadTranslations();

    TTT_StartConfig("revive");
    CreateConVar("ttt2_revive_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("revive_name", "Revive", "The name of the Revive in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("revive_traitor_price", "9000", "The amount of credits for Revive costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("revive_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("revive_detective_price", "0", "The amount of credits for Revive costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("revive_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTPrio = AutoExecConfig_CreateConVar("revive_traitor_sort_prio", "0", "The sorting priority of the Revive (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("revive_detective_sort_prio", "0", "The sorting priority of the Revive (Detective) in the shop menu.");
    g_cTCount = AutoExecConfig_CreateConVar("revive_traitor_count", "1", "The amount of usages for Revive per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("revive_detective_count", "1", "The amount of usages for Revive per round as detective. 0 to disable.");
    g_cReviveT = AutoExecConfig_CreateConVar("revive_time_traitor", "10", "Revive time for traitors?", _, true, 3.0);
    g_cReviveD = AutoExecConfig_CreateConVar("revive_time_detective", "10", "Revive time for detectives?", _, true, 3.0);
    g_cHealthT = AutoExecConfig_CreateConVar("revive_health_traitor", "50", "Traitor health after reviving?", _, true, 1.0);
    g_cHealthD = AutoExecConfig_CreateConVar("revive_health_detective", "50", "Detective health after reviving?", _, true, 1.0);
    g_cTimeToAccept = AutoExecConfig_CreateConVar("revive_time_to_accept", "10", "Time in seconds to accept the revive request.", _, true, 5.0);
    g_cTimeToNextMessage = AutoExecConfig_CreateConVar("revive_time_to_next_message", "1", "Show just 1 message every x second when you try to revive someone. Why? -> Move during revive and you can spam the chat. 0 - Disabled");
    g_cStopMovement = AutoExecConfig_CreateConVar("revive_stop_on_movement", "0", "Stop revive countdown on movement?", _, true, 0.0, true, 1.0);
    g_cReviveDistance = AutoExecConfig_CreateConVar("revive_distance", "95.0", "Max. distance in units to revive the target (0.0 = Disabled)");
    g_cLineOfSight = AutoExecConfig_CreateConVar("revive_check_line_of_sight", "1", "Target must be in line of sight during revive process", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    g_hSyncT = CreateHudSynchronizer();
    g_hSyncB = CreateHudSynchronizer();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnClientDisconnect(int client)
{
    ResetItem(client);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cDebug = FindConVar("ttt_debug_mode");

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
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    TTT_AddInventoryItem(client, itemshort);
    return Plugin_Continue;
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    LoopValidClients(i)
    {
        ResetItem(i);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetItem(client);
    }
}

public Action TTT_OnGrabbing(int client, int entity)
{
    if (HasReviveItem(client) && !g_iPlayer[client].Wait && IsValidEntity(entity))
    {
        int target = TTT_GetClientByRagdollID(entity);

        if (!TTT_IsClientValid(target))
        {
            return Plugin_Continue;
        }

        if (g_cDebug == null)
        {
            g_cDebug = FindConVar("ttt_debug_mode");
        }

        if (!g_cDebug.BoolValue && IsFakeClient(target))
        {
            return Plugin_Continue;
        }

        if (TTT_GetClientRole(target) != TTT_TEAM_TRAITOR && TTT_GetClientRole(target) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Continue;
        }

        int iRole = TTT_GetClientRole(client);

        if (iRole != TTT_GetClientRole(target))
        {
            return Plugin_Continue;
        }

        if (!g_cLineOfSight.BoolValue && g_cReviveDistance.FloatValue > 0.0 && !CheckDistance(client, entity))
        {
            return Plugin_Continue;
        }

        if (g_cLineOfSight.BoolValue && !TTT_TargetInSightOfClient(client, entity, g_cReviveDistance.FloatValue))
        {
            return Plugin_Continue;
        }

        if (g_iPlayer[client].InUse || g_iPlayer[client].Timer || g_iPlayer[target].Menu)
        {
            return Plugin_Stop;
        }

        char sClass[32];
        if (!GetEntityClassname(entity, sClass, sizeof(sClass)))
        {
            return Plugin_Continue;
        }

        char sName[32];
        GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

        if (StrEqual(sClass, "prop_ragdoll", false) || (StrContains(sClass, "prop_physics_multiplayer", false) != -1 && StrContains(sName, "ragdoll_", false) != -1))
        {
            g_iPlayer[client].InUse = true;
            g_iPlayer[client].Ragdoll = EntIndexToEntRef(entity);

            DataPack pack = new DataPack();
            g_iPlayer[client].Timer = CreateTimer(1.0, Timer_Revive, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(EntIndexToEntRef(entity));

            g_iPlayer[client].StartTime = GetTime();
            
            char sMessage[MAX_NAME_LENGTH + 32], sPlayerName[MAX_NAME_LENGTH];
            TTT_GetClientName(target, sPlayerName, sizeof(sPlayerName));
            Format(sMessage, sizeof(sMessage), "Reviving %s...", sPlayerName);

            if (iRole == TTT_TEAM_TRAITOR)
            {
                g_iPlayer[client].EndTime = (g_iPlayer[client].StartTime + g_cReviveT.IntValue);
                g_iPlayer[client].Countdown = g_cReviveT.IntValue;
            }
            else if (iRole == TTT_TEAM_DETECTIVE)
            {
                g_iPlayer[client].EndTime = (g_iPlayer[client].StartTime + g_cReviveD.IntValue);
                g_iPlayer[client].Countdown = g_cReviveD.IntValue;
            }

            if (g_iPlayer[client].LastMessage == -1 || ((g_iPlayer[client].LastMessage + g_cTimeToNextMessage.IntValue) < GetTime()))
            {
                g_iPlayer[client].LastMessage = GetTime();

                char sClientName[MAX_NAME_LENGTH], sTargetName[MAX_NAME_LENGTH];
                TTT_GetClientName(client, sClientName, sizeof(sClientName));
                TTT_GetClientName(target, sTargetName, sizeof(sTargetName));

                CPrintToChat(target, "%s %T", g_sPluginTag, "Revive: Before to Target", target, sClientName, g_iPlayer[client].Countdown);
                CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Before to Player", client, sTargetName);
            }
            
            TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iPlayer[client].StartTime, g_iPlayer[client].EndTime, sMessage);
            g_iPlayer[client].Countdown--;

            return Plugin_Stop;
        }
    }

    if (g_iPlayer[client].Wait)
    {
        return Plugin_Stop;
    }

    if (IsValidEntity(entity))
    {
        int target = TTT_GetClientByRagdollID(entity);

        if (!TTT_IsClientValid(target))
        {
            return Plugin_Continue;
        }

        if (g_iPlayer[target].Menu)
        {
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_Revive(Handle timer, DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());
    int entity = EntRefToEntIndex(pack.ReadCell());

    if (!TTT_IsClientValid(client) || !HasReviveItem(client))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (g_iPlayer[client].Timer == null)
    {
        return Plugin_Stop;
    }

    if (g_iPlayer[client].EndTime == -1 || g_iPlayer[client].StartTime == -1 || g_iPlayer[client].Countdown == -1)
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (!IsValidEntity(entity))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (!g_iPlayer[client].InUse)
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (g_iPlayer[client].Ragdoll == TTT_GetGrabEntity(client))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    if (g_cReviveDistance.FloatValue > 0.0 && !CheckDistance(client, entity))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    if (g_cLineOfSight.BoolValue && !TTT_TargetInSightOfClient(client, entity))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    int target = TTT_GetClientByRagdollID(entity);

    if (!TTT_IsClientValid(target))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    if (TTT_GetClientRole(target) != TTT_TEAM_TRAITOR && TTT_GetClientRole(target) != TTT_TEAM_DETECTIVE)
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    if (TTT_GetClientRole(client) != TTT_GetClientRole(target))
    {
        g_iPlayer[client].Timer = null;
        delete pack;
        return Plugin_Stop;
    }

    char sMessage[MAX_NAME_LENGTH + 32], sPlayerName[MAX_NAME_LENGTH];
    TTT_GetClientName(target, sPlayerName, sizeof(sPlayerName));
    Format(sMessage, sizeof(sMessage), "Reviving %s...", sPlayerName);

    if (g_iPlayer[client].Countdown == 0)
    {
        TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iPlayer[client].StartTime, g_iPlayer[client].EndTime, sMessage);
        
        if (g_cDebug.BoolValue && IsFakeClient(target))
        {
            RevivePlayer(client, target);
        }
        else
        {
            ShowReviveMenu(client, target);
        }
    }

    if (g_iPlayer[client].Countdown > 0)
    {
        g_iPlayer[client].Countdown--;
        TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iPlayer[client].StartTime, g_iPlayer[client].EndTime, sMessage);
        return Plugin_Continue;
    }

    g_iPlayer[client].Timer = null;
    delete pack;
    return Plugin_Stop;
}

void ShowReviveMenu(int client, int target)
{
    if (!HasReviveItem(client) || g_iPlayer[client].Wait || g_iPlayer[target].Menu)
    {
        if (g_cDebug.BoolValue)
        {
            CPrintToChat(client, "HasReviveItem: %d, client.Wait: %d, target.Menu: %d", HasReviveItem(client), g_iPlayer[client].Wait, g_iPlayer[target].Menu);
        }
        return;
    }

    g_iPlayer[client].Wait = true;
    g_iPlayer[target].Menu = true;

    char sClientName[MAX_NAME_LENGTH], sTargetName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sClientName, sizeof(sClientName));
    TTT_GetClientName(target, sTargetName, sizeof(sTargetName));
    CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Waiting of accepting", client, sTargetName);

    Menu menu = new Menu(Menu_ReviveRequest);
    menu.SetTitle("%T", "Revive: Menu - Title", target, sClientName, g_cTimeToAccept.IntValue);
    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "%T", "Revive: Menu - Yes", target);
    menu.AddItem("yes", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "%T", "Revive: Menu - No", target);
    menu.AddItem("no", sBuffer);
    IntToString(GetClientUserId(client), sBuffer, sizeof(sBuffer));
    menu.AddItem("client", sBuffer, ITEMDRAW_IGNORE);
    menu.ExitBackButton = false;
    menu.ExitButton = false;

    menu.Display(target, g_cTimeToAccept.IntValue);
}

public int Menu_ReviveRequest(Menu menu, MenuAction action, int target, int param)
{
    if (action == MenuAction_Select)
    {
        if (TTT_GetRoundStatus() != Round_Active || IsPlayerAlive(target))
        {
            return;
        }

        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));

        int client = -1;
        int iCount = menu.ItemCount;
        char sInfo[32], sBuffer[32];

        for (int i = 0; i < iCount; i++)
        {
            menu.GetItem(i, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

            if (StrEqual(sInfo, "client"))
            {
                client = GetClientOfUserId(StringToInt(sBuffer));
            }
        }

        if (!IsPlayerAlive(client) || !HasReviveItem(client))
        {
            return;
        }

        if (TTT_GetClientRole(target) != TTT_TEAM_TRAITOR && TTT_GetClientRole(target) != TTT_TEAM_DETECTIVE)
        {
            return;
        }

        if (TTT_GetClientRole(client) != TTT_GetClientRole(target))
        {
            return;
        }

        if (StrEqual(sParam, "yes", false))
        {
            RevivePlayer(client, target);
        }
        else if (StrEqual(sParam, "no", false))
        {
            char sName[MAX_NAME_LENGTH];
            TTT_GetClientName(target, sName, sizeof(sName));
            CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - Declined", client, sName);
        }

        g_iPlayer[client].Wait = false;
        g_iPlayer[target].Menu = false;
    }
    else if (action == MenuAction_Cancel && (param == MenuCancel_Timeout || param == MenuCancel_NoDisplay))
    {
        int client = -1;
        int iCount = menu.ItemCount;
        char sInfo[32], sBuffer[32];

        for (int i = 0; i < iCount; i++)
        {
            menu.GetItem(i, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));

            if (StrEqual(sInfo, "client"))
            {
                client = GetClientOfUserId(StringToInt(sBuffer));
            }
        }

        if (TTT_IsClientValid(client))
        {
            g_iPlayer[client].Wait = false;
            char sName[MAX_NAME_LENGTH];
            TTT_GetClientName(target, sName, sizeof(sName));
            CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - No response", client, sName);
        }
        
        g_iPlayer[target].Menu = false;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int TTT_OnButtonPress(int client, int button)
{
    if (g_cStopMovement.BoolValue && HasReviveItem(client) && g_iPlayer[client].InUse && (button &= ~IN_USE))
    {
        g_iPlayer[client].InUse = false;

        if (g_iPlayer[client].Timer != null)
        {
            KillTimer(g_iPlayer[client].Timer);
            g_iPlayer[client].Timer = null;
        }
    }
}

public int TTT_OnButtonRelease(int client, int button)
{
    if (button & IN_USE)
    {
        g_iPlayer[client].InUse = false;

        if (g_iPlayer[client].Timer != null)
        {
            KillTimer(g_iPlayer[client].Timer);
            g_iPlayer[client].Timer = null;
        }
    }
}

void ResetItem(int client)
{
    g_iPlayer[client].Wait = false;
    g_iPlayer[client].Menu = false;

    g_iPlayer[client].InUse = false;
    g_iPlayer[client].Ragdoll = -1;

    g_iPlayer[client].Countdown = -1;
    g_iPlayer[client].StartTime = -1;
    g_iPlayer[client].EndTime = -1;
    g_iPlayer[client].LastMessage = -1;

    if (g_iPlayer[client].Timer != null)
    {
        KillTimer(g_iPlayer[client].Timer);
        g_iPlayer[client].Timer = null;
    }
}

bool HasReviveItem(int client)
{
    if (TTT_IsItemInInventory(client, SHORT_NAME_D) || TTT_IsItemInInventory(client, SHORT_NAME_T))
    {
        return true;
    }

    return false;
}

bool CheckDistance(int client, int entity)
{
    float fEntityPos[3], fClientPos[3];

    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fEntityPos);
    GetClientEyePosition(client, fClientPos);

    float fDistance = GetVectorDistance(fEntityPos, fClientPos, false);

    if (fDistance > g_cReviveDistance.FloatValue)
    {
        return false;
    }

    return true;
}

void RevivePlayer(int client, int target)
{
    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(target, sName, sizeof(sName));
    CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - Accepted", client, sName);
    TTT_RespawnPlayer(target);

    int iRole = TTT_GetClientRole(client);
    
    if (iRole == TTT_TEAM_TRAITOR)
    {
        TTT_RemoveInventoryItem(client, SHORT_NAME_T);
        TTT_AddItemUsage(client, SHORT_NAME_T);
        SetEntityHealth(target, g_cHealthT.IntValue);

    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        TTT_RemoveInventoryItem(client, SHORT_NAME_D);
        TTT_AddItemUsage(client, SHORT_NAME_D);
        SetEntityHealth(target, g_cHealthD.IntValue);
    }
}
