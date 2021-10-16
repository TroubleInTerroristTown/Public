#pragma semicolon 1

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Tester"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorlib>
#include <ttt>

#pragma newdecls required

ConVar g_cBlockTester = null;
ConVar g_cBlockTesterTime = null;
ConVar g_cBlockTesterMessage = null;
ConVar g_cLightTime = null;
ConVar g_cLightDelayTime = null;
ConVar g_cMaxPlayers = null;
ConVar g_cDebug = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

bool g_bInTester[MAXPLAYERS + 1] = { false, ... };

int g_iGreenLight = -1;
int g_iRedLight = -1;
int g_iButton = -1;

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

    TTT_StartConfig("traitor_tester");
    CreateConVar("ttt2_traitor_tester_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cBlockTester = AutoExecConfig_CreateConVar("traitor_tester_block_tester", "0", "For how long tester button should be disabled after using it. 0 to not block it.", _, true, 0.0, true, 1.0);
    g_cBlockTesterTime = AutoExecConfig_CreateConVar("traitor_tester_block_tester_time", "3", "Determinate for how long tester button should be disabled. 0 to disable tester block.");
    g_cBlockTesterMessage = AutoExecConfig_CreateConVar("traitor_tester_block_tester_message", "1", "If 1 print to client info about tester cooldown. 0 to disable.", _, true, 0.0, true, 1.0);
    g_cLightTime = AutoExecConfig_CreateConVar("traitor_tester_light_time", "3", "For how long the lights should be shown. Min value is 3 seconds.", _, true, 3.0, false, 0.0);
    g_cLightDelayTime = AutoExecConfig_CreateConVar("traitor_tester_light_delay_time", "0", "Determinate if the lights should be shown right away or after few secodns. 0 to disable.");
    g_cMaxPlayers = AutoExecConfig_CreateConVar("traitor_tester_max_players", "0", "Determinate how many players can be checked at one. 0 to disable it.");
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_show_debug_messages");
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(convar == g_cPluginTag)
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detective)
{
    g_iGreenLight = -1;
    g_iRedLight = -1;
    g_iButton = -1;

    char sName[64];

    int iEnt = -1;

    while ((iEnt = FindEntityByClassname(iEnt, "func_button")) != -1)
    {
        GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

        if (g_cDebug != null && g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_button", false))
        {
            if (g_cDebug != null && g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Button (%d)", iEnt);
            }

            g_iButton = iEnt;

            AcceptEntityInput(g_iButton, "PressOut");
            AcceptEntityInput(g_iButton, "Unlock");

            HookSingleEntityOutput(iEnt, "OnPressed", OnButtonPress, false);
        }
    }

    while ((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
    {
        GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

        if (g_cDebug != null && g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_zone", false))
        {
            if (g_cDebug != null && g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Zone (%d)", iEnt);
            }

            // g_iZone = iEnt;

            SDKHook(iEnt, SDKHook_StartTouch, StartTouchTester);
            SDKHook(iEnt, SDKHook_EndTouch, EndTouchTester);
        }
    }

    while ((iEnt = FindEntityByClassname(iEnt, "light")) != -1)
    {
        GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

        if (g_cDebug != null && g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_green", false))
        {
            if (g_cDebug != null && g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Green Light (%d)", iEnt);
            }

            g_iGreenLight = iEnt;
        }
        else if (StrEqual(sName, "traitor_tester_red", false))
        {
            if (g_cDebug != null && g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Red Light (%d)", iEnt);
            }

            g_iRedLight = iEnt;
        }
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        g_bInTester[client] = false;

        if (g_cDebug != null && g_cDebug.BoolValue)
        {
            PrintToChat(client, "g_bInTester -> %d", g_bInTester[client]);
        }
    }
}

public Action StartTouchTester(int entity, int client)
{
    if (TTT_IsClientValid(client))
    {
        g_bInTester[client] = true;

        if (g_cDebug.BoolValue)
        {
            PrintToChat(client, "g_bInTester -> %d", g_bInTester[client]);
        }
    }
}

public Action EndTouchTester(int entity, int client)
{
    if (TTT_IsClientValid(client))
    {
        g_bInTester[client] = false;

        if (g_cDebug.BoolValue)
        {
            PrintToChat(client, "g_bInTester -> %d", g_bInTester[client]);
        }
    }
}

public Action OnButtonPress(const char[] output, int entity, int client, float delay)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("OnButtonPress");
    }
    
    bool bRed = false;
    int iCount = 0;

    LoopValidClients(i)
    {
        if (g_bInTester[i])
        {
            iCount++;

            if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToChatAll("Set bRed to true, Light should be red!");
                }

                bRed = true;
            }
        }
    }

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("iCount %d", iCount);
    }

    if (iCount > 0)
    {
        if (g_cMaxPlayers.BoolValue && iCount > g_cMaxPlayers.IntValue)
        {
            LoopValidClients(i)
            {
                CPrintToChat(i, "%s %T", g_sPluginTag, "Traitor Tester: Too many people", i, g_cMaxPlayers.IntValue);
            }

            return Plugin_Continue;
        }

        AcceptEntityInput(g_iButton, "Lock");

        if (g_cLightDelayTime.FloatValue > 0.0) 
        {
            CreateTimer(g_cLightDelayTime.FloatValue, Timer_EnableLight, bRed);
        }
        else
        {
            enableLights(bRed);
        }

        if (g_cBlockTester.BoolValue && g_cBlockTesterTime.FloatValue > 0.0 && g_cBlockTesterTime.FloatValue >= g_cLightTime.FloatValue)
        {
            CreateTimer(g_cBlockTesterTime.FloatValue, Timer_EnableButton);
        }
        
        CreateTimer(g_cLightTime.FloatValue, Timer_DisableLight);

        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Plugin_Continue");
        }

        return Plugin_Continue;
    }

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("Plugin_Handled");
    }

    return Plugin_Handled;
}

public Action Timer_EnableButton(Handle timer)
{
    AcceptEntityInput(g_iButton, "PressOut");
    AcceptEntityInput(g_iButton, "Unlock");

    if (g_cBlockTesterMessage.BoolValue)
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s %T", g_sPluginTag, "Traitor Tester: Cooldown expired", i);
        }
    }
}

public Action Timer_EnableLight(Handle timer, any bRed)
{
    enableLights(bRed);
}

public Action Timer_DisableLight(Handle timer)
{
    AcceptEntityInput(g_iGreenLight, "TurnOff");
    AcceptEntityInput(g_iRedLight, "TurnOff");

    if (!g_cBlockTester.BoolValue)
    {
        AcceptEntityInput(g_iButton, "PressOut");
        AcceptEntityInput(g_iButton, "Unlock");
    }

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("Reset. Green: %d, Red: %d", g_iGreenLight, g_iRedLight);
    }
}

void enableLights(bool bRed)
{
    if (!bRed)
    {
        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Set green light on");
        }

        AcceptEntityInput(g_iGreenLight, "TurnOn");
    }
    else
    {
        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Set red light on");
        }

        AcceptEntityInput(g_iRedLight, "TurnOn");
    }
}