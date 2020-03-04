#pragma semicolon 1

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Secrets"

#include <sourcemod>
#include <sdktools>
#include <ttt>

#undef REQUIRE_PLUGIN
#include <customkeyvalues>
#define REQUIRE_PLUGIN

#pragma newdecls required

ConVar g_cDebug = null;
ConVar g_cLogUse = null;
ConVar g_cAddLogs = null;
ConVar g_cLogFormat = null;
ConVar g_cDistance = null;

ArrayList g_aButtonNames = null;
ArrayList g_aButtons = null;

bool g_bCustomKeyValues = false;

bool g_bUse[MAXPLAYERS + 1] = { false, ... };

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

    TTT_StartConfig("traitor_secrets");
    CreateConVar("ttt2_traitor_secrets_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cDebug = AutoExecConfig_CreateConVar("traitor_secrets_debug", "0", "Enable debug mode?", _, true, 0.0, true, 1.0);
    g_cLogUse = AutoExecConfig_CreateConVar("traitor_secrets_log_use", "1", "Log use of traitor buttons?", _, true, 0.0, true, 1.0);
    g_cDistance = AutoExecConfig_CreateConVar("traitor_secrets_distance", "90.0", "Maximal distance from player to the button. 0 to disable it");
    TTT_EndConfig();

    g_aButtons = new ArrayList();
    g_aButtonNames = new ArrayList(64);
    
    LoadTraitorButtons();
    LoadButtons();
    
    RegAdminCmd("sm_reloadbuttons", Command_Reload, ADMFLAG_ROOT);

    g_bCustomKeyValues = LibraryExists("CustomKeyValues");
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = false;
    }
}

public void OnMapStart()
{
    LoadButtons();
}

public void OnConfigsExecuted()
{
    g_cAddLogs = FindConVar("ttt_steamid_add_to_logs");
    g_cLogFormat = FindConVar("ttt_steamid_log_format");
}

public Action Command_Reload(int client, int args)
{
    ReplyToCommand(client, "Reloading buttons...");

    g_aButtonNames.Clear();

    LoadTraitorButtons();
    LoadButtons();

    return Plugin_Handled;
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    char sClass[64];
    char sName[64];

    HookEntityOutput("func_button", "OnPressed", ButtonPressed);

    for (int i = MaxClients; i < GetMaxEntities(); i++)
    {
        if (IsValidEdict(i) && IsValidEntity(i))
        {
            GetEdictClassname(i, sClass, sizeof(sClass));
            GetEntPropString(i, Prop_Data, "m_iName", sName, sizeof(sName));

            if ((StrContains(sClass, "_door", false) != -1 || StrContains(sClass, "_room", false) != -1) && StrContains(sName, "traitor", false) != -1)
            {
                AcceptEntityInput(i, "Lock");

                HookSingleEntityOutput(i, "OnLockedUse", OnLockedUse);
            }
        }
    }

    for (int i = 0; i < g_aButtons.Length; i++)
    {
        SetEntProp(g_aButtons.Get(i), Prop_Data, "m_bLocked", 1, 1);
    }

    LoopValidClients(i)
    {
        g_bUse[i] = false;
    }
}

public int TTT_OnButtonPress(int client, int button)
{
    if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR && button & IN_USE)
    {
        if (IsClientInGame(client) && !g_bUse[client] && IsPlayerAlive(client))
        {
            g_bUse[client] = true;
            GetClientTraceTarget(client);
        }
    }
}

public int TTT_OnButtonRelease(int client, int button)
{
    if (button & IN_USE)
    {
        g_bUse[client] = false;
    }
}

public void ButtonPressed(const char[] output, int caller, int activator, float delay)
{
    OnButtonPressed(activator, caller);
}

public void OnButtonPressed(int activator, int caller) 
{
    if(TTT_GetClientRole(activator) == TTT_TEAM_TRAITOR)
    {
        if(g_aButtons.FindValue(caller) !=  -1)
        {
            SetEntProp(caller, Prop_Data, "m_bLocked", 0, 1);

            if (g_cLogUse != null && g_cLogUse.BoolValue)
            {
                char sClientID[32];

                if (g_cAddLogs != null && g_cAddLogs.BoolValue)
                {
                    if (g_cLogFormat.IntValue == 1)
                    {
                        GetClientAuthId(activator, AuthId_Steam2, sClientID, sizeof(sClientID));
                    }
                    else if (g_cLogFormat.IntValue == 2)
                    {
                        GetClientAuthId(activator, AuthId_Steam3, sClientID, sizeof(sClientID));
                    }
                    else if (g_cLogFormat.IntValue == 3)
                    {
                        GetClientAuthId(activator, AuthId_SteamID64, sClientID, sizeof(sClientID));
                    }
                    
                    if (strlen(sClientID) > 2)
                    {
                        Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
                    }
                }

                char sName[64];
                GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));
                
                TTT_LogString("-> [%N%s (Traitor) used traitor secret: %s]", activator, sClientID, sName);
            }

            CreateTimer(1.0, Timer_Button, caller);
        }
    }
}

public Action Timer_Button(Handle timer, int entity)
{
    SetEntProp(entity, Prop_Data, "m_bLocked", 1, 1);
}

stock int GetClientTraceTarget(int client)
{
    float fPosition[3];
    GetClientEyePosition(client, fPosition);

    float fAngles[3];
    GetClientEyeAngles(client, fAngles);

    TR_EnumerateEntities(fPosition, fAngles, PARTITION_SOLID_EDICTS, RayType_Infinite, TR_Callback, client);

    return -1;
}

public bool TR_Callback(int entity, int client)
{
    if (IsValidEntity(entity) && entity > MaxClients)
    {
        TR_ClipCurrentRayToEntity( MASK_ALL, entity );

        char sClass[64];
        GetEntityClassname(entity, sClass, sizeof(sClass));

        char sName[32];
        GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

        float fEntityPosition[3], fTargetPosition[3];

        GetClientEyePosition(client, fTargetPosition);
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fEntityPosition);

        float fPos[3];
        TR_GetEndPosition(fPos);

        if (g_cDistance.FloatValue > 0.0)
        {
            float fEntityPos[3], fClientPos[3];
            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", fEntityPos);
            GetClientEyePosition(client, fClientPos);

            if (GetVectorDistance(fEntityPos, fClientPos, false) > g_cDistance.FloatValue)
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToChat(client, "(%s) Distance: %f", sName, GetVectorDistance(fEntityPos, fClientPos, false));
                    PrintToChat(client, "Name: %s, Position: X_%.3f, Y_%.3f, Z_%.3f", sName, fPos[0], fPos[1], fPos[2]);
                }

                return true;
            }
        }

        if (g_bCustomKeyValues)
        {
            char sCustom[4];
            bool success = GetCustomKeyValue(entity, "ttt_traitor_only", sCustom, sizeof(sCustom));

            if (success)
            {
                if (view_as<bool>(StringToInt(sCustom)) && TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
                {
                    return false;
                }
            }
        }

        if (
                (StrContains(sName, "traitor_tester_", false) == -1) && 
                (StrContains(sName, "traitor", false) != -1 || StrContains(sName, "secret", false) != -1) &&
                (StrContains(sName, "button", false) != -1 || StrContains(sClass, "_door", false) != -1 || StrContains(sClass, "_room", false) != -1)
            )
        {
            AcceptEntityInput(entity, "Unlock");

            if (StrContains(sName, "button", false) != -1)
            {
                AcceptEntityInput(entity, "Press");
                OnButtonPressed(client, entity);
            }
            else
            {
                AcceptEntityInput(entity, "Open");
            }
            
            AcceptEntityInput(entity, "Lock");

            if (g_cDebug.BoolValue)
            {
                PrintToChat(client, "Name: %s, Position: X_%.3f, Y_%.3f, Z_%.3f", sName, fPos[0], fPos[1], fPos[2]);
            }
            
            return false;
        }
    }

    return true;
}

public int OnLockedUse(const char[] output, int caller, int attacker, float data)
{
    if (TTT_GetClientRole(attacker) != TTT_TEAM_TRAITOR)
    {
        return;
    }

    AcceptEntityInput(caller, "Unlock");
    AcceptEntityInput(caller, "Open");
    AcceptEntityInput(caller, "Lock");

    if (g_cLogUse != null && g_cLogUse.BoolValue)
    {
        char sClientID[32];

        if (g_cAddLogs != null && g_cAddLogs.BoolValue)
        {
            if (g_cLogFormat.IntValue == 1)
            {
                GetClientAuthId(attacker, AuthId_Steam2, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 2)
            {
                GetClientAuthId(attacker, AuthId_Steam3, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 3)
            {
                GetClientAuthId(attacker, AuthId_SteamID64, sClientID, sizeof(sClientID));
            }
            
            if (strlen(sClientID) > 2)
            {
                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
            }
        }

        char sName[64];
        GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

        TTT_LogString("-> [%N%s (Traitor) opened a traitor secret: %s]", attacker, sClientID, sName);
    }
}

void LoadButtons()
{
    g_aButtons.Clear();

    char buffer[64];
    int iEntity = -1;
    //Search for buttons
    while ((iEntity = FindEntityByClassname(iEntity, "func_button")) != -1) 
    {
        GetEntPropString(iEntity, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(iEntity, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(iEntity);
        }
    }
    
    iEntity = -1;
    
    //Search for doors
    while ((iEntity = FindEntityByClassname(iEntity, "func_door")) != -1) 
    {
        GetEntPropString(iEntity, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(iEntity, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(iEntity);
        }
    }
    
    //Search for func_door_rotating
    while ((iEntity = FindEntityByClassname(iEntity, "func_door_rotating")) != -1) 
    {
        GetEntPropString(iEntity, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(iEntity, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(iEntity);
        }
    }
    
    iEntity = -1;
    //Search for prop_door_rotating
    while ((iEntity = FindEntityByClassname(iEntity, "prop_door_rotating")) != -1) 
    {
        GetEntPropString(iEntity, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(iEntity, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(iEntity);
        }
    }
}

void LoadTraitorButtons()
{
    char sBuffer[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/ttt/traitor_buttons.cfg");
    
    KeyValues kv = new KeyValues("Buttons");

    if(!kv.ImportFromFile(sBuffer))
    {
        SetFailState("Couldn't read file %s! Will be built now!", sBuffer);
    }
    
    kv.Rewind();
    
    if (!kv.GotoFirstSubKey())
    {
        return;
    }
    
    char buffer[64];
    do
    {
        if(kv.GetSectionName(buffer, sizeof(buffer)))
        {
            if(kv.GetNum("enabled"))
            {
                g_aButtonNames.PushString(buffer);
            }
        }
    } while (kv.GotoNextKey());
    
    delete kv;
}
