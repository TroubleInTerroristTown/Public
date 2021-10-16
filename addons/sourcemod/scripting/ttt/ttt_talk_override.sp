#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Talk Override"

ConVar g_cEnableTVoice = null;
ConVar g_cDeadTalk = null;
ConVar g_cAdminFlags = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[128];

enum struct PlayerData {
    bool TraitorVoice;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

GlobalForward g_fwOnTraitorVoice = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnTraitorVoice = new GlobalForward("TTT_OnTraitorVoice", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef);

    CreateNative("TTT_GetTraitorVoice", Native_GetTraitorVoice);
    CreateNative("TTT_SetTraitorVoice", Native_SetTraitorVoice);
    
    RegPluginLibrary("ttt_talk_override");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("talk_override");
    CreateConVar("ttt2_talk_override_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cEnableTVoice = AutoExecConfig_CreateConVar("tor_traitor_voice_chat", "1", "Enable traitor voice chat (command for players: sm_tvoice)?", _, true, 0.0, true, 1.0);
    g_cDeadTalk = AutoExecConfig_CreateConVar("ttt_enable_dead_talk", "1", "Allows dead players to talk with other dead players.", _, true, 0.0, true, 1.0);
    g_cAdminFlags = AutoExecConfig_CreateConVar("ttt_dead_admin_flags", "b", "Admin flags to get access to 'immortal voice'. \"\" for no immunity.");
    TTT_EndConfig();

    if (g_cEnableTVoice.BoolValue)
    {
        RegConsoleCmd("sm_tvoice", Command_TVoice);
    }

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);

    TTT_LoadTranslations();
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].TraitorVoice = false;
}

public void OnClientPostAdminCheck(int client)
{
    RequestFrame(Frame_PostAdminCheck, GetClientUserId(client));
}

public void Frame_PostAdminCheck(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        SetListen(client);
    }
}

public void OnClientDisconnect(int client)
{
    g_iPlayer[client].TraitorVoice = false;
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

public Action Command_TVoice(int client, int args)
{
    if (!g_cEnableTVoice.BoolValue || TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }
    
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    SetTVoice(client, !g_iPlayer[client].TraitorVoice);

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        SetTVoice(client, false, false);

        LoopValidClients(i)
        {
            SetListenOverride(i, client, Listen_Yes);
        }
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(victim))
    {
        SetTVoice(victim, false, false);
        SetListen(victim);
    }
}

public void TTT_OnClientGetRole(int client, int role)
{
    SetTVoice(client, false, false);
    SetListen(client);
}

public void TTT_OnPlayerRespawn(int client)
{
    SetTVoice(client, false, false);
    SetListen(client);
}

public int TTT_OnRoundSlay(int client, int remaining)
{
    SetTVoice(client, false, false);
    SetListen(client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        SetTVoice(client, false, false);
        SetListen(client);
    }
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    LoopValidClients(i)
    {
        SetTVoice(i, false, false);

        LoopValidClients(j)
        {
            SetListenOverride(i, j, Listen_Default);
        }
    }
}

void SetListen(int client)
{
    char sBuffer[18];
    g_cAdminFlags.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) < 1 || !TTT_CheckCommandAccess(client, "ttt_talk_override", g_cAdminFlags, true))
    {
        LoopValidClients(i)
        {
            if (!TTT_IsPlayerAlive(client))
            {
                if (TTT_IsPlayerAlive(i))
                {
                    SetListenOverride(i, client, Listen_No);
                    SetListenOverride(client, i, Listen_Yes);
                }
                else
                {
                    if (g_cDeadTalk.BoolValue)
                    {
                        SetListenOverride(i, client, Listen_Yes);
                        SetListenOverride(client, i, Listen_Yes);
                    }
                    else
                    {
                        SetListenOverride(i, client, Listen_No);
                        SetListenOverride(client, i, Listen_No);
                    }
                }
            }
            else
            {
                SetListenOverride(client, i, Listen_Yes);
                SetListenOverride(i, client, Listen_Yes);
            }
        }
    }
}

bool SetTVoice(int client, bool status, bool message = true)
{
    if (TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
    {
        return false;
    }

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnTraitorVoice);
    Call_PushCell(client);
    Call_PushCellRef(status);
    Call_PushCellRef(message);
    Call_Finish();

    if (res >= Plugin_Handled)
    {
        return false;
    }

    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sName, sizeof(sName));

    if (!status)
    {
        if (message)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Disabled!", client);
        }

        g_iPlayer[client].TraitorVoice = false;

        LoopValidClients(i)
        {
            SetListenOverride(i, client, Listen_Yes);

            if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
            {
                if (message)
                {
                    CPrintToChat(i, "%s %T", g_sPluginTag, "stopped talking in Traitor Voice Chat", i, sName);
                }
            }
        }
    }
    else
    {
        g_iPlayer[client].TraitorVoice = true;

        if (message)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Traitor Voice Chat: Enabled!", client);
        }

        LoopValidClients(i)
        {
            if (TTT_GetClientRole(i) != TTT_TEAM_TRAITOR)
            {
                SetListenOverride(i, client, Listen_No);
            }
            else
            {
                if (message)
                {
                    CPrintToChat(i, "%s %T", g_sPluginTag, "is now talking in Traitor Voice Chat", i, sName);
                }
            }
        }
    }

    return g_iPlayer[client].TraitorVoice;
}

public int Native_GetTraitorVoice(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    return g_iPlayer[client].TraitorVoice;
}

public int Native_SetTraitorVoice(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    bool status = view_as<bool>(GetNativeCell(2));
    bool message = view_as<bool>(GetNativeCell(3));

    return SetTVoice(client, status, message);
}
