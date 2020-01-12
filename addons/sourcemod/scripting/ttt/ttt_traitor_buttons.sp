#pragma semicolon 1

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Traitor Buttons"

#include <sourcemod>
#include <sdktools>
#include <ttt>

#undef REQUIRE_PLUGIN
#include <customkeyvalues>
#define REQUIRE_PLUGIN

#pragma newdecls required

ArrayList g_aButtonNames = null;
ArrayList g_aButtons = null;

bool g_bCustomKeyValues = false;

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
    g_aButtons = new ArrayList();
    g_aButtonNames = new ArrayList(64);
    
    LoadCFG();
    LoadButtons();
    
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    
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

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public Action Command_Reload(int client, int args)
{
    ReplyToCommand(client, "Reloading buttons...");

    g_aButtonNames.Clear();

    LoadCFG();
    LoadButtons();

    return Plugin_Handled;
}

void LoadButtons()
{
    g_aButtons.Clear();

    char buffer[64];
    int ent = -1;
    //Search for buttons
    while ((ent = FindEntityByClassname(ent, "func_button")) != -1) 
    {
        GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(ent, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(ent);
        }
    }
    
    ent = -1;
    
    //Search for doors
    while ((ent = FindEntityByClassname(ent, "func_door")) != -1) 
    {
        GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(ent, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(ent);
        }
    }
    
    //Search for func_door_rotating
    while ((ent = FindEntityByClassname(ent, "func_door_rotating")) != -1) 
    {
        GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(ent, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(ent);
        }
    }
    
    ent = -1;
    //Search for prop_door_rotating
    while ((ent = FindEntityByClassname(ent, "prop_door_rotating")) != -1) 
    {
        GetEntPropString(ent, Prop_Data, "m_iName", buffer, sizeof(buffer));
        if(g_aButtonNames.FindString(buffer) != -1)
        {
            SetEntProp(ent, Prop_Data, "m_bLocked", 1, 1);
            g_aButtons.Push(ent);
        }
    }
}

public void OnMapStart()
{
    LoadButtons();
}

public void LoadCFG()
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

public Action ButtonPressed(const char[] output, int caller, int activator, float delay)
{
    if (!TTT_IsClientValid(activator))
    {
        return Plugin_Continue;
    }

    if (g_bCustomKeyValues)
    {
        char sCustom[4];
        bool success = GetCustomKeyValue(caller, "ttt_traitor_only", sCustom, sizeof(sCustom));

        if (success)
        {
            if (view_as<bool>(StringToInt(sCustom)) && TTT_GetClientRole(activator) != TTT_TEAM_TRAITOR)
            {
                return Plugin_Handled;
            }
        }
    }

    char sName[64];
    GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));

    if (StrContains(sName, "traitor", false) != -1 && TTT_GetClientRole(activator) != TTT_TEAM_TRAITOR)
    {
        return Plugin_Handled;
    }

    OnButtonPressed(activator, caller);

    return Plugin_Continue;
}

public void OnButtonPressed(int activator, int caller) 
{
    if(TTT_GetClientRole(activator) == TTT_TEAM_TRAITOR)
    {
        if(g_aButtons.FindValue(caller) !=  -1)
        {
            SetEntProp(caller, Prop_Data, "m_bLocked", 0, 1);
            CreateTimer(1.0, Timer_Button, caller);
        }
    }
}

public Action Timer_Button(Handle timer, int entity)
{
    SetEntProp(entity, Prop_Data, "m_bLocked", 1, 1);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) 
{
    HookEntityOutput("func_button", "OnPressed", ButtonPressed);

    for (int i = 0; i < g_aButtons.Length; i++)
    {
        SetEntProp(g_aButtons.Get(i), Prop_Data, "m_bLocked", 1, 1);
    }
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount)
{
    static int iPlayerPrevButtons[MAXPLAYERS + 1];
    if (!(iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE)
    {
        if (IsClientInGame(client) && IsPlayerAlive(client))
        {
            int ent = GetClientAimTarget(client, false);
            if (!IsValidEntity(ent))
            {
                iPlayerPrevButtons[client] = iButtons;
                return;
            }

            if (g_bCustomKeyValues)
            {
                char sCustom[4];
                bool success = GetCustomKeyValue(ent, "ttt_traitor_only", sCustom, sizeof(sCustom));

                if (success)
                {
                    if (view_as<bool>(StringToInt(sCustom)) && TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
                    {
                        return;
                    }
                }
            }
            
            if (HasEntProp(ent, Prop_Data, "m_iName"))
            {
                char sName[128];
                GetEntityClassname(ent, sName, sizeof(sName));
                if (StrContains(sName, "door", false) != -1 || StrContains(sName, "button", false) != -1)
                {
                    OnButtonPressed(client, ent);
                }
            }
        }
    }
    iPlayerPrevButtons[client] = iButtons;
}
