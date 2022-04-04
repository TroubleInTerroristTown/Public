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
ConVar g_cDelay = null;

ArrayList g_aButtonNames = null;
ArrayList g_aButtons = null;
ArrayList g_aSpam = null;

bool g_bCustomKeyValues = false;

bool g_bUse[MAXPLAYERS + 1] = { false, ... };

char g_sFindEntities[][] =  {
    "func_button",
    "func_door",
    "func_door_rotating",
    "prop_door_rotating"
};

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
    g_cDelay = AutoExecConfig_CreateConVar("traitor_secrets_spam_protection", "3", "After how many seconds should be a button logged again? (0 - Disabled)", _, true, 0.0);
    TTT_EndConfig();

    g_aButtons = new ArrayList();
    g_aButtonNames = new ArrayList(64);
    
    LoadTraitorButtons();
    LoadButtons();
    
    RegAdminCmd("sm_reloadbuttons", Command_Reload, ADMFLAG_ROOT);

    g_bCustomKeyValues = LibraryExists("CustomKeyValues");
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
    HookEntityOutput("func_breakable", "OnHealthChanged", OnDamage);
    HookEntityOutput("func_breakable", "OnBreak", OnBreak);

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

    delete g_aSpam;
    g_aSpam = new ArrayList();
}

public void TTT_OnButtonPress(int client, int button)
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

public void TTT_OnButtonRelease(int client, int button)
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

public void OnDamage(const char[] output, int entity, int client, float delay)
{
    OnLog(entity, client, "Damage");
}

public void OnBreak(const char[] output, int entity, int client, float delay)
{
    OnLog(entity, client, "Break");
}

void OnLog(int entity, int client, const char[] event)
{
    char sName[32];
    GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

    bool bSkip = false;

    int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

    // This is just a workaround for maps with breakable stuff which should be logged
    if (
        iHammerID == 44443 || // ttt_damons_canyon_b2_2 + ttt_damons_canyon_b2_2_sg
        iHammerID == 276512 || // ttt_community_pool_2017_v1_7
        iHammerID == 110483 || // ttt_community_bowling_csgo_v3
        iHammerID == 174076 // ttt_minecraftcity_sgfix_v9
        )
    {
        bSkip = true;
    }

    if (!bSkip && StrContains(sName, "traitor", false) == -1)
    {
        return;
    }

    if (g_aSpam.FindValue(EntIndexToEntRef(entity)) == -1 && g_cLogUse != null && g_cLogUse.BoolValue)
    {
        char sClientID[32];

        if (g_cAddLogs != null && g_cAddLogs.BoolValue)
        {
            if (g_cLogFormat.IntValue == 1)
            {
                GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 2)
            {
                GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 3)
            {
                GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
            }
            else if (g_cLogFormat.IntValue == 4)
            {
                Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
            }
            
            if (strlen(sClientID) > 2)
            {
                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
            }
        }

        if (strlen(sName) < 2)
        {
            GetEntityClassname(entity, sName, sizeof(sName));
        }

        char sRole[ROLE_LENGTH];
        TTT_GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));

        if (StrEqual(event, "Break", false))
        {
            TTT_LogString("-> [%N%s (%s) breaks the entity: %s]", client, sClientID, sRole, sName);
        }
        else
        {
            TTT_LogString("-> [%N%s (%s) damaged the entity: %s]", client, sClientID, sRole, sName);
        }

        if (g_cDelay.FloatValue > 0.0)
        {
            g_aSpam.Push(EntIndexToEntRef(entity));
            CreateTimer(g_cDelay.FloatValue, Timer_ResetEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public void OnButtonPressed(int activator, int caller) 
{
    if(TTT_GetClientRole(activator) == TTT_TEAM_TRAITOR)
    {
        if(g_aButtons.FindValue(caller) !=  -1)
        {
            SetEntProp(caller, Prop_Data, "m_bLocked", 0, 1);

            CreateTimer(1.0, Timer_Button, EntIndexToEntRef(caller));
        }
    }
}

public Action Timer_Button(Handle timer, any ref)
{
    if (IsValidEntity(EntRefToEntIndex(ref)))
    {
        SetEntProp(EntRefToEntIndex(ref), Prop_Data, "m_bLocked", 1, 1);
    }
    
    return Plugin_Handled;
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

public bool TR_Callback(int entity, any client)
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
            float fClientPos[3];
            GetClientEyePosition(client, fClientPos);

            if (GetVectorDistance(fPos, fClientPos, false) > g_cDistance.FloatValue)
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToChat(client, "(%s) Distance: %f", sName, GetVectorDistance(fPos, fClientPos, false));
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

            if (g_aSpam.FindValue(EntIndexToEntRef(entity)) == -1 && g_cLogUse != null && g_cLogUse.BoolValue)
            {
                char sClientID[32];

                if (g_cAddLogs != null && g_cAddLogs.BoolValue)
                {
                    if (g_cLogFormat.IntValue == 1)
                    {
                        GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
                    }
                    else if (g_cLogFormat.IntValue == 2)
                    {
                        GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
                    }
                    else if (g_cLogFormat.IntValue == 3)
                    {
                        GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
                    }
                    else if (g_cLogFormat.IntValue == 4)
                    {
                        Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
                    }
                    
                    if (strlen(sClientID) > 2)
                    {
                        Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
                    }
                }

                char sRole[ROLE_LENGTH];
                TTT_GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));
                TTT_LogString("-> [%N%s (%s) used traitor secret: %s]", client, sClientID, sRole, sName);

                if (g_cDelay.FloatValue > 0.0)
                {
                    g_aSpam.Push(EntIndexToEntRef(entity));
                    CreateTimer(g_cDelay.FloatValue, Timer_ResetEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
                }
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

public Action Timer_ResetEntity(Handle timer, any ref)
{
    int iIndex = g_aSpam.FindValue(ref);

    if (iIndex != -1)
    {
        g_aSpam.Erase(iIndex);
    }

    return Plugin_Stop;
}

public int OnLockedUse(const char[] output, int caller, int attacker, float data)
{
    if (TTT_GetClientRole(attacker) != TTT_TEAM_TRAITOR)
    {
        return 0;
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
            else if (g_cLogFormat.IntValue == 4)
            {
                Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(attacker));
            }
            
            if (strlen(sClientID) > 2)
            {
                Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
            }
        }

        char sName[64];
        GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

        char sRole[ROLE_LENGTH];
        TTT_GetRoleNameByID(TTT_GetClientRole(attacker), sRole, sizeof(sRole));
        TTT_LogString("-> [%N%s (%s) opened a traitor secret: %s]", attacker, sClientID, sRole, sName);
    }
    
    return 0;
}

void LoadButtons()
{
    g_aButtons.Clear();

    char sName[64];
    int iEntity = -1;

    for (int i = 0; i < sizeof(g_sFindEntities); i++)
    {
        while ((iEntity = FindEntityByClassname(iEntity, g_sFindEntities[i])) != -1) 
        {
            GetEntPropString(iEntity, Prop_Data, "m_iName", sName, sizeof(sName));
            if(g_aButtonNames.FindString(sName) != -1)
            {
                SetEntProp(iEntity, Prop_Data, "m_bLocked", 1, 1);
                g_aButtons.Push(iEntity);

                iEntity = -1;
                sName[0] = '\0';
            }
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
