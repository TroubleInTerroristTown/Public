#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

#define HUD_RADAR ( 1<<12 )
#define HUD_ALL 2050

bool g_bRedie[MAXPLAYERS + 1 ] = { false, ... };

public Plugin myinfo =
{
    name = "GhostDeathmatch with Redie",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara/TroubleinTerroristTown"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Redie_GetClientStatus", Native_GetClientStatus);

    RegPluginLibrary("ghostdm");
    
    return APLRes_Success;
}

public int Native_GetClientStatus(Handle plugin, int numParams)
{
    return g_bRedie[GetNativeCell(1)];
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_redie", Command_Redie);

    HookEvent("player_spawn", Event_Player);
    HookEvent("player_death", Event_Player);

    AddNormalSoundHook(view_as<NormalSHook>(OnNormalSoundPlayed));

    LoopClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnClientPutInServer(int client)
{
    ResetClient(client);

    SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
}

public void OnClientDisconnect(int client)
{
    ResetClient(client);
}

public Action Command_Redie(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_bRedie[client])
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_ALL);
    }

    g_bRedie[client] = !g_bRedie[client];

    PrintToChat(client, "Changed redie status to: %s", g_bRedie[client] ? "On" : "Off");

    if (g_bRedie[client])
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_RADAR);
    }

    return Plugin_Handled;
}

public Action Event_Player(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientValid(client))
    {
        ResetClient(client);
    }
}

public Action OnNormalSoundPlayed(int[] clients, int &numClients, char[] sample, int &client, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
    if (IsClientValid(client))
    {
        for (int i = 0; i < 1; i++)
        {
            PrintToConsoleAll(" ");
        }

        int iTemp = numClients;
        numClients = 0;

        LoopClients(i)
        {
            PrintToConsoleAll("[LoopClients Redie Status] Client: %N (Redie: %d) - i: %N (Redie: %d)", client, g_bRedie[client], i, g_bRedie[i]);

            if (g_bRedie[client] == g_bRedie[i])
            {
                clients[numClients] = i;
                numClients++;
            }
        }

        if (numClients == 0)
        {
            numClients = iTemp;
        }

        PrintToConsoleAll("[How many numClients] %N - numClients: %d", client, numClients);
        for (int i = 0; i < numClients; i++)
        {
            PrintToConsoleAll("[numCLients/clients Loop] %N - clients (i - %d): %N (%d)", client, i, clients[i], clients[i]);
        }

        for (int i = 0; i < 1; i++)
        {
            PrintToConsoleAll(" ");
        }

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action OnSetTransmit(int target, int client)
{
    if (!IsClientValid(target) || !IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[target] != g_bRedie[client])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

void ResetClient(int client)
{
    g_bRedie[client] = false;

    if (IsClientInGame(client))
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_ALL);
    }
}

bool IsClientValid(int client, bool nobots = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientConnected(client) || IsClientSourceTV(client) || !IsClientInGame(client))
        {
            return false;
        }
        
        if (nobots && IsFakeClient(client))
        {
            return false;
        }

        return true;
    }

    return false;
}
