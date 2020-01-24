#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#pragma newdecls required

bool g_bInTester[MAXPLAYERS + 1] = { false, ... };

int g_iGreenLight = -1;
int g_iRedLight = -1;
int g_iButton = -1;

ConVar g_cDebug = null;

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerSpawn);
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_show_debug_messages");
}

public void OnClientDisconnect(int client)
{
    g_bInTester[client] = false;
    
    if (g_cDebug.BoolValue)
    {
        PrintToChat(client, "g_bInTester -> %d", g_bInTester[client]);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientInGame(client))
    {
        g_bInTester[client] = false;
        if (g_cDebug != null && g_cDebug.BoolValue)
        {
            PrintToChat(client, "g_bInTester -> %d", g_bInTester[client]);
        }
    }
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    g_iGreenLight = -1;
    g_iRedLight = -1;
    g_iButton = -1;

    char sName[64];

    int iEnt = -1;

    while ((iEnt = FindEntityByClassname(iEnt, "func_button")) != -1)
    {
        GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_button", false))
        {
            if (g_cDebug.BoolValue)
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

        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_zone", false))
        {
            if (g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Zone (%d)", iEnt);
            }

            SDKHook(iEnt, SDKHook_StartTouch, StartTouchTester);
            SDKHook(iEnt, SDKHook_EndTouch, EndTouchTester);
        }
    }

    while ((iEnt = FindEntityByClassname(iEnt, "light")) != -1)
    {
        GetEntPropString(iEnt, Prop_Data, "m_iName", sName, sizeof(sName));

        if (g_cDebug.BoolValue)
        {
            PrintToChatAll("Name: %s", sName);
        }

        if (StrEqual(sName, "traitor_tester_green", false))
        {
            if (g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Green Light (%d)", iEnt);
            }

            g_iGreenLight = iEnt;
        }
        else if (StrEqual(sName, "traitor_tester_red", false))
        {
            if (g_cDebug.BoolValue)
            {
                PrintToChatAll("Found Red Light (%d)", iEnt);
            }

            g_iRedLight = iEnt;
        }
    }
}

public Action StartTouchTester(int entity, int client)
{
    if (IsClientInGame(client))
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
    if (IsClientInGame(client))
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
    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("OnButtonPress");
    }
    
    bool bRed = false;
    int iCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bInTester[i])
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

        CreateTimer(3.0, Timer_DisableLight);

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

public Action Timer_DisableLight(Handle timer)
{
    AcceptEntityInput(g_iGreenLight, "TurnOff");
    AcceptEntityInput(g_iRedLight, "TurnOff");
    AcceptEntityInput(g_iButton, "PressOut");
    AcceptEntityInput(g_iButton, "Unlock");

    if (g_cDebug.BoolValue)
    {
        PrintToChatAll("Reset. Green: %d, Red: %d", g_iGreenLight, g_iRedLight);
    }
}
