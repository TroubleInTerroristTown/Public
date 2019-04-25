#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <ttt_grabbermod>
#include <multicolors>

#pragma newdecls required

#define SHORT_NAME_D "revive_d"
#define SHORT_NAME_T "revive_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Revive"

ConVar g_cTPrice = null;
ConVar g_cDPrice = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cLongName = null;
ConVar g_cReviveT = null;
ConVar g_cReviveD = null;
ConVar g_cTimeToAccept = null;
ConVar g_cTimeToNextMessage = null;

int g_iTPCount[MAXPLAYERS + 1] = { -1, ... };
int g_iDPCount[MAXPLAYERS + 1] = { -1, ... };
int g_iRagdoll[MAXPLAYERS + 1] = { -1, ... };
int g_iCountdown[MAXPLAYERS + 1] = { -1, ... };
int g_iStartTime[MAXPLAYERS + 1] = { -1, ... };
int g_iEndTime[MAXPLAYERS + 1] = { -1, ... };
int g_iLastMessage[MAXPLAYERS + 1] = { -1, ... };

bool g_bHasRevive[MAXPLAYERS + 1] = { false, ... };
bool g_bInUse[MAXPLAYERS + 1] = { false, ... };
bool g_bWait[MAXPLAYERS + 1] = { false, ... };
bool g_bMenu[MAXPLAYERS + 1] = { false, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

Handle g_hTimer[MAXPLAYERS + 1] = { null, ...};

Handle g_hSyncT = null;
Handle g_hSyncB = null;

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
    g_cTPrice = AutoExecConfig_CreateConVar("revive_traitor_price", "0", "The amount of credits for Revive costs as traitor. 0 to disable.");
    g_cDPrice = AutoExecConfig_CreateConVar("revive_detective_price", "0", "The amount of credits for Revive costs as detective. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("revive_traitor_sort_prio", "0", "The sorting priority of the Revive (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("revive_detective_sort_prio", "0", "The sorting priority of the Revive (Detective) in the shop menu.");
    g_cTCount = AutoExecConfig_CreateConVar("revive_traitor_count", "1", "The amount of usages for Revive per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("revive_detective_count", "1", "The amount of usages for Revive per round as detective. 0 to disable.");
    g_cReviveT = AutoExecConfig_CreateConVar("revive_time_traitor", "10", "Revive time for traitors?", _, true, 3.0);
    g_cReviveD = AutoExecConfig_CreateConVar("revive_time_detective", "10", "Revive time for detectives?", _, true, 3.0);
    g_cTimeToAccept = AutoExecConfig_CreateConVar("revive_time_to_accept", "10", "Time in seconds to accept the revive request.", _, true, 5.0);
    g_cTimeToNextMessage = AutoExecConfig_CreateConVar("revive_time_to_next_message", "1", "Show just 1 message every x second when you try to revive someone. Why? -> Move during revive and you can spam the chat. 0 - Disabled");
    TTT_EndConfig();

    g_hSyncT = CreateHudSynchronizer();
    g_hSyncB = CreateHudSynchronizer();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
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
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
    TTT_RegisterCustomItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME_T, false) || StrEqual(itemshort, SHORT_NAME_D, false))
        {
            if (g_bHasRevive[client])
            {
                return Plugin_Stop;
            }

            int role = TTT_GetClientRole(client);
            
            char sBuffer[MAX_ITEM_LENGTH];
            g_cLongName.GetString(sBuffer, sizeof(sBuffer));

            if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cTCount.IntValue);
                return Plugin_Stop;
            }
            else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cDCount.IntValue);
                return Plugin_Stop;
            }

            g_bHasRevive[client] = true;

            if (count)
            {
                if (role == TTT_TEAM_TRAITOR)
                {
                    g_iTPCount[client]++;
                }
                else if (role == TTT_TEAM_DETECTIVE)
                {
                    g_iDPCount[client]++;
                }
            }
        }
    }
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
    if (g_bHasRevive[client] && !g_bWait[client] && IsValidEntity(entity))
    {
        int target = TTT_GetClientByRagdollID(entity);

        if (!TTT_IsClientValid(target))
        {
            return Plugin_Continue;
        }

        if (TTT_GetClientRole(target) != TTT_TEAM_TRAITOR && TTT_GetClientRole(target) != TTT_TEAM_DETECTIVE)
        {
            return Plugin_Continue;
        }

        if (TTT_GetClientRole(client) != TTT_GetClientRole(target))
        {
            return Plugin_Continue;
        }

        if (g_bInUse[client] || g_hTimer[client] || g_bMenu[target])
        {
            return Plugin_Stop;
        }

        char sClass[32];
        GetEntityClassname(entity, sClass, sizeof(sClass));

        if (StrEqual(sClass, "prop_ragdoll", false))
        {
            g_bInUse[client] = true;
            g_iRagdoll[client] = entity;

            DataPack pack = new DataPack();
            g_hTimer[client] = CreateTimer(1.0, Timer_Revive, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(EntIndexToEntRef(entity));

            g_iStartTime[client] = GetTime();
            char sMessage[MAX_NAME_LENGTH + 32];
            Format(sMessage, sizeof(sMessage), "Reviving %N...", target);

            if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
            {
                g_iEndTime[client] = (g_iStartTime[client] + g_cReviveT.IntValue);
                g_iCountdown[client] = g_cReviveT.IntValue;
            }
            else if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
            {
                g_iEndTime[client] = (g_iStartTime[client] + g_cReviveD.IntValue);
                g_iCountdown[client] = g_cReviveD.IntValue;
            }

            if (g_iLastMessage[client] == -1 || ((g_iLastMessage[client] + g_cTimeToNextMessage.IntValue) < GetTime()))
            {
                g_iLastMessage[client] = GetTime();
                CPrintToChat(target, "%s %T", g_sPluginTag, "Revive: Before to Target", target, client, g_iCountdown[client]);
                CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Before to Player", client, target);
            }
            
            TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iStartTime[client], g_iEndTime[client], sMessage);
            g_iCountdown[client]--;

            return Plugin_Stop;
        }
    }

    if (g_bWait[client])
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

        if (g_bMenu[target])
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

    if (!TTT_IsClientValid(client) || !g_bHasRevive[client])
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (g_hTimer[client] == null)
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }

    if (g_iEndTime[client] == -1 || g_iStartTime[client] == -1 || g_iCountdown[client] == -1)
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (!IsValidEntity(entity))
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (!g_bInUse[client])
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }
    
    if (g_iRagdoll[client] == TTT_GetGrabEntity(client))
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }

    int target = TTT_GetClientByRagdollID(entity);

    if (!TTT_IsClientValid(target))
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }

    if (TTT_GetClientRole(target) != TTT_TEAM_TRAITOR && TTT_GetClientRole(target) != TTT_TEAM_DETECTIVE)
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }

    if (TTT_GetClientRole(client) != TTT_GetClientRole(target))
    {
        g_hTimer[client] = null;
        delete pack;
        return Plugin_Stop;
    }

    char sMessage[MAX_NAME_LENGTH + 32];
    Format(sMessage, sizeof(sMessage), "Reviving %N...", target);

    if (g_iCountdown[client] == 0)
    {
        TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iStartTime[client], g_iEndTime[client], sMessage);
        ShowReviveMenu(client, target);
    }

    if (g_iCountdown[client] > 0)
    {
        g_iCountdown[client]--;
        TTT_ShowProgressbar(client, g_hSyncB, g_hSyncT, g_iStartTime[client], g_iEndTime[client], sMessage);
        return Plugin_Continue;
    }

    g_hTimer[client] = null;
    delete pack;
    return Plugin_Stop;
}

void ShowReviveMenu(int client, int target)
{
    if (!g_bHasRevive[client] && !g_bWait[client])
    {
        return;
    }

    g_bWait[client] = true;
    g_bMenu[target] = true;

    CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Waiting of accepting", client, target);

    Menu menu = new Menu(Menu_ReviveRequest);
    menu.SetTitle("%T", "Revive: Menu - Title", target, client, g_cTimeToAccept.IntValue);
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
        if (!TTT_IsRoundActive() || TTT_IsPlayerAlive(target))
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

        if (!TTT_IsPlayerAlive(client) || !g_bHasRevive[client])
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
            CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - Accepted", client, target);
            TTT_RespawnPlayer(target);
            g_bHasRevive[client] = false;
        }
        else if (StrEqual(sParam, "no", false))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - Declined", client, target);
        }

        g_bWait[client] = false;
        g_bMenu[target] = false;
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
            g_bWait[client] = false;
            CPrintToChat(client, "%s %T", g_sPluginTag, "Revive: Menu - No response", client, target);
        }
        
        g_bMenu[target] = false;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int TTT_OnButtonPress(int client, int button)
{
    if (g_bHasRevive[client] && g_bInUse[client] && (button &= ~IN_USE))
    {
        g_bInUse[client] = false;

        if (g_hTimer[client] != null)
        {
            KillTimer(g_hTimer[client]);
            g_hTimer[client] = null;
        }
    }
}

public int TTT_OnButtonRelease(int client, int button)
{
    if (button & IN_USE)
    {
        g_bInUse[client] = false;

        if (g_hTimer[client] != null)
        {
            KillTimer(g_hTimer[client]);
            g_hTimer[client] = null;
        }
    }
}

void ResetItem(int client)
{
    g_iTPCount[client] = 0;
    g_iDPCount[client] = 0;

    g_bHasRevive[client] = false;
    g_bWait[client] = false;
    g_bMenu[client] = false;

    g_bInUse[client] = false;
    g_iRagdoll[client] = -1;

    g_iCountdown[client] = -1;
    g_iStartTime[client] = -1;
    g_iEndTime[client] = -1;
    g_iLastMessage[client] = -1;

    if (g_hTimer[client] != null)
    {
        KillTimer(g_hTimer[client]);
        g_hTimer[client] = null;
    }
}
