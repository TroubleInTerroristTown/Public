#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Spec Menu"

#define SPECMODE_NONE 0
#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define SPECMODE_FREELOOK 6

ConVar g_cMenuTime = null;
ConVar g_cAutoOpen = null;
ConVar g_cEnableNextPrev = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

enum struct PlayerData {
    bool MutedAlive;
    bool MutedDead;
    bool Search;
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

    TTT_StartConfig("spec_menu");
    CreateConVar("ttt2_spec_menu_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cAutoOpen = AutoExecConfig_CreateConVar("specmenu_auto_open", "1", "Show spec menu automatically after death?", _, true, 0.0, true, 1.0);
    g_cMenuTime = AutoExecConfig_CreateConVar("specmenu_menu_time", "0", "Time (in seconds) to autoclose the menu (0 - FOREVER)");
    g_cEnableNextPrev = AutoExecConfig_CreateConVar("specmenu_enable_new_spec_nextprev", "1", "Enables the new method for spec_next and spec_prev", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    TTT_LoadTranslations();

    RegConsoleCmd("sm_specmenu", Command_SpecMenu);
    RegConsoleCmd("sm_spm", Command_SpecMenu);

    AddCommandListener(Command_SpecNext, "spec_next");
    AddCommandListener(Command_SpecPrev, "spec_prev");
    AddCommandListener(Command_SpecPlayer, "spec_player");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    g_iPlayer[client].MutedAlive = false;
    g_iPlayer[client].MutedDead = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (TTT_GetRoundStatus() == Round_Active)
    {
        int client = GetClientOfUserId(event.GetInt("userid"));

        if (TTT_IsClientValid(client) && !IsFakeClient(client))
        {
            LoopValidClients(i)
            {
                if (g_iPlayer[i].MutedDead)
                {
                    SetListenOverride(i, client, Listen_No);
                }
            }

            if (g_cAutoOpen.BoolValue)
            {
                ShowSpecMenu(client);
            }
        }
    }
}

public Action Command_SpecNext(int client, const char[] command, int argc)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (!g_cEnableNextPrev.BoolValue || !TTT_IsClientReady(client) || IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

    if (iMode == SPECMODE_FREELOOK)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Freelook", client);
        return Plugin_Continue;
    }
    
    int target = GetObservTarget(client);

    if (!IsValidTarget(target))
    {
        target = 0;
    }

    if (g_iPlayer[client].Search)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Searching", client);
        return Plugin_Continue;
    }

    int nextTarget = GetNextClient(client, target, true);
    
    if (nextTarget > 0)
    {
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", nextTarget);
    }
    
    return Plugin_Handled;
}

public Action Command_SpecPrev(int client, const char[] command, int argc)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (!g_cEnableNextPrev.BoolValue || !TTT_IsClientReady(client) || IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

    if (iMode == SPECMODE_FREELOOK)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Freelook", client);
        return Plugin_Continue;
    }
    
    int target = GetObservTarget(client);

    if (!IsValidTarget(target))
    {
        target = 0;
    }

    if (g_iPlayer[client].Search)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Searching", client);
        return Plugin_Continue;
    }

    int nextTarget = GetNextClient(client, target, false);
    
    if (nextTarget > 0)
    {
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", nextTarget);
    }
    
    return Plugin_Handled;
}

public Action Command_SpecPlayer(int client, const char[] command, int argc)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (!g_cEnableNextPrev.BoolValue || !TTT_IsClientReady(client) || IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

    if (iMode == SPECMODE_FREELOOK)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Freelook", client);
        return Plugin_Continue;
    }
    
    char arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    if (arg[0])
    {
        char targetName[128];
        int targets[MAXPLAYERS];
        bool tn_is_ml;
        int numTargets = ProcessTargetString(arg, client, targets, MaxClients, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tn_is_ml);
        
        if (numTargets <= 0)
        {
            int target = GetObservTarget(client);

            if (!IsValidTarget(target))
            {
                target = 0;
            }

            if (g_iPlayer[client].Search)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Searching", client);
                return Plugin_Continue;
            }

            int nextTarget = GetNextClient(client, target, true);
            
            if (nextTarget > 0)
            {
                SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", nextTarget);
            }

            return Plugin_Handled;
        }
        
        if (numTargets != 1)
        {
            int target = GetObservTarget(client);

            if (!IsValidTarget(target))
            {
                target = 0;
            }

            if (g_iPlayer[client].Search)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Searching", client);
                return Plugin_Continue;
            }

            int nextTarget = GetNextClient(client, target, true);
            
            if (nextTarget > 0)
            {
                SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", nextTarget);
            }

            return Plugin_Handled;
        }
        
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", TTT_GetRandomPlayer(true));
    }
    
    return Plugin_Handled;
}

public Action Command_SpecMenu(int client, int args)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client) && !IsFakeClient(client))
    {
        return Plugin_Handled;
    }

    ShowSpecMenu(client);

    return Plugin_Continue;
}

void ShowSpecMenu(int client)
{
    if (IsPlayerAlive(client))
        return;
    
    int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

    if (iMode == SPECMODE_FREELOOK)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "Spec Menu: Freelook", client);
        return;
    }

    int iTarget = GetObservTarget(client);

    if (iTarget == client)
    {
        FakeClientCommand(client, "spec_next");
    }

    Menu menu = new Menu(Menu_MainMenu);
    menu.SetTitle("%T", "SpecMenu: Title", client);

    if (TTT_IsClientValid(iTarget) && !IsFakeClient(client))
    {
        char sPlayer[MAX_NAME_LENGTH], sName[MAX_NAME_LENGTH];
        TTT_GetClientName(iTarget, sName, sizeof(sName));
        
        Format(sPlayer, sizeof(sPlayer), "%T\n--------------------", "SpecMenu: Player", client, sName);
        menu.AddItem("player", sPlayer, ITEMDRAW_DISABLED);
    }

    char sNext[64], sPrev[64];
    Format(sNext, sizeof(sNext), "%T", "SpecMenu: Next", client);
    Format(sPrev, sizeof(sPrev), "%T\n--------------------", "SpecMenu: Prev", client);

    menu.AddItem("next", sNext);
    menu.AddItem("prev", sPrev);

    char sItem[64];
    if (g_iPlayer[client].MutedAlive)
    {
        Format(sItem, sizeof(sItem), "%T", "SpecMenu: Unmute Alive", client);
    }
    else
    {
        Format(sItem, sizeof(sItem), "%T", "SpecMenu: Mute Alive", client);
    }

    menu.AddItem("alive", sItem);

    if (g_iPlayer[client].MutedDead)
    {
        Format(sItem, sizeof(sItem), "%T", "SpecMenu: Unmute Dead", client);
    }
    else
    {
        Format(sItem, sizeof(sItem), "%T", "SpecMenu: Mute Dead", client);
    }

    menu.AddItem("dead", sItem);

    menu.ExitButton = true;

    menu.Display(client, g_cMenuTime.IntValue);

}

public int Menu_MainMenu(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (!IsPlayerAlive(client) || IsClientObserver(client))
        {
            char sParam[32];
            menu.GetItem(param, sParam, sizeof(sParam));

            if (StrEqual(sParam, "next", false))
            {
                FakeClientCommand(client, "spec_next");
                ShowSpecMenu(client);
            }
            else if (StrEqual(sParam, "prev", false))
            {
                FakeClientCommand(client, "spec_prev");
                ShowSpecMenu(client);
            }
            else if (StrEqual(sParam, "alive", false))
            {
                if (g_iPlayer[client].MutedAlive)
                {
                    LoopValidClients(i)
                    {
                        if (IsPlayerAlive(i))
                        {
                            SetListenOverride(client, i, Listen_Yes);
                        }
                    }

                    g_iPlayer[client].MutedAlive = false;
                }
                else
                {
                    LoopValidClients(i)
                    {
                        if (IsPlayerAlive(i))
                        {
                            SetListenOverride(client, i, Listen_No);
                        }
                    }

                    g_iPlayer[client].MutedAlive = true;
                }

                ShowSpecMenu(client);
            }
            else if (StrEqual(sParam, "dead", false))
            {
                if (g_iPlayer[client].MutedDead)
                {
                    LoopValidClients(i)
                    {
                        if (!IsPlayerAlive(i))
                        {
                            SetListenOverride(client, i, Listen_Yes);
                        }
                    }

                    g_iPlayer[client].MutedDead = false;
                }
                else
                {
                    LoopValidClients(i)
                    {
                        if (!IsPlayerAlive(i))
                        {
                            SetListenOverride(client, i, Listen_No);
                        }
                    }

                    g_iPlayer[client].MutedDead = true;
                }

                ShowSpecMenu(client);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

int GetObservTarget(int client)
{
    if (!IsPlayerAlive(client) || IsClientObserver(client))
    {
        int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        if (iMode == SPECMODE_FIRSTPERSON || iMode == SPECMODE_3RDPERSON)
        {
            int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

            if (!IsValidTarget(target))
            {
                target = 0;
            }

            return target;
        }
    }
    return 0;
}

int GetNextClient(int client, int current, bool next = true)
{
    g_iPlayer[client].Search = true;

    int iNext = -1;
    int iTemp = GetClient(current, next, current, true);

    while (iNext == -1)
    {
        if (iTemp == current)
        {
            break;
        }

        if (iTemp != client && IsValidTarget(iTemp))
        {
            iNext = iTemp;
            break;
        }
        else
        {
            iTemp = GetClient(iTemp, next, current, false);

            if (iTemp == -2)
            {
                g_iPlayer[client].Search = false;
                return -1;
            }
        }
    }

    g_iPlayer[client].Search = false;
    return iNext;
}

int GetClient(int current, bool next, int original, bool skip)
{
    if (next)
    {
        current++;

        if (current > MaxClients)
        {
            current = 1;
        }
    }
    else
    {
        current--;

        if (current <= 0)
        {
            current = MaxClients;
        }
    }

    if (!skip && original == current)
    {
        return -2;
    }

    return current;
}

bool IsValidTarget(int client)
{
    if (TTT_IsClientValid(client) && TTT_IsPlayerAlive(client))
    {
        int iRole = TTT_GetClientRole(client);

        if (iRole == TTT_TEAM_TRAITOR || iRole == TTT_TEAM_INNOCENT || iRole == TTT_TEAM_DETECTIVE)
        {
            return true;
        }
    }

    return false;
}
