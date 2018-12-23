#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <ttt>
#include <CustomPlayerSkins>

int g_iColorInnocent[3] =  {0, 255, 0};
int g_iColorTraitor[3] =  {255, 0, 0};
int g_iColorDetective[3] =  {0, 0, 255};

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow"

ConVar g_cDGlow = null;
ConVar g_cTGlow = null;
ConVar g_cDebug = null;

bool g_bCPS = false;

Handle g_hOnGlowCheck = null;

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "Bara & zipcore",
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hOnGlowCheck = CreateGlobalForward("TTT_OnGlowCheck", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
    
    RegPluginLibrary("ttt_glow");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("glow");
    CreateConVar("ttt2_glow_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cDGlow = AutoExecConfig_CreateConVar("glow_detective_enable", "1", "Detectives see the glows of other detectives. 0 to disable.", _, true, 0.0, true, 1.0);
    g_cTGlow = AutoExecConfig_CreateConVar("glow_traitor_enable", "1", "Traitors see the glows of other traitors. 0 to disable.", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    g_bCPS = LibraryExists("CustomPlayerSkins");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnPluginEnd()
{
    LoopValidClients(i)
    {
        UnHookSkin(i);
        CPS_RemoveSkin(i);
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "CustomPlayerSkins"))
    {
        g_bCPS = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "CustomPlayerSkins"))
    {
        g_bCPS = false;
    }
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_debug_mode");
    
    if (!g_bCPS)
    {
        SetFailState("CustomPlayerSkins not loaded!");
    }
    else
    {
        CreateTimer(0.3, Timer_SetupGlow, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        int iSkin = CPS_GetSkin(client);

        if (IsValidEntity(iSkin))
        {
            SetEntProp(iSkin, Prop_Send, "m_bShouldGlow", false, true);

            int iOffset = -1;

            if ((iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow")) == -1)
            {
                return;
            }

            SetEntData(iSkin, iOffset, 0, _, true);
            SetEntData(iSkin, iOffset + 1, 0, _, true);
            SetEntData(iSkin, iOffset + 2, 0, _, true);
            SetEntData(iSkin, iOffset + 3, 0, _, true);
        }
    }
}

public Action Timer_SetupGlow(Handle timer, any data)
{
    if(!TTT_IsRoundActive())
    {
        return Plugin_Continue;
    }

    LoopValidClients(i)
    {
        SetupGlowSkin(i);
    }

    return Plugin_Continue;
}

void SetupGlowSkin(int client)
{
    UnHookSkin(client);
    CPS_RemoveSkin(client);

    if (!TTT_IsRoundActive())
    {
        return;
    }

    if (!g_cDebug.BoolValue && (IsFakeClient(client) || IsClientSourceTV(client)))
    {
        return;
    }

    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    int role = TTT_GetClientRole(client);
    
    if (role != TTT_TEAM_DETECTIVE && role != TTT_TEAM_INNOCENT && role != TTT_TEAM_TRAITOR)
    {
        return;
    }
    
    if (!g_cDGlow.BoolValue && role == TTT_TEAM_DETECTIVE)
    {
        return;
    }

    if (!g_cTGlow.BoolValue && role == TTT_TEAM_TRAITOR)
    {
        return;
    }

    char model[PLATFORM_MAX_PATH];
    GetClientModel(client, model, sizeof(model));
    int skin = CPS_SetSkin(client, model, CPS_RENDER);

    if(skin == -1)
    {
        return;
    }
    
    if (SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
    {
        SetupGlow(client, skin);
    }
}

void UnHookSkin(int client)
{
    if(CPS_HasSkin(client))
    {
        int skin = EntRefToEntIndex(CPS_GetSkin(client));

        if(IsValidEntity(skin))
        {
            SDKUnhook(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin);
        }
    }
}

void SetupGlow(int client, int skin)
{
    int iOffset;

    if ((iOffset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
    {
        return;
    }

    SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(skin, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);

    int iRed = 255;
    int iGreen = 255;
    int iBlue = 255;
    
    if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
    {
        iRed = g_iColorDetective[0];
        iGreen = g_iColorDetective[1];
        iBlue = g_iColorDetective[2];
    }
    else if (TTT_GetClientRole(client) == TTT_TEAM_TRAITOR)
    {
        iRed = g_iColorTraitor[0];
        iGreen = g_iColorTraitor[1];
        iBlue = g_iColorTraitor[2];
    }
    else if (TTT_GetClientRole(client) == TTT_TEAM_INNOCENT)
    {
        iRed = g_iColorInnocent[0];
        iGreen = g_iColorInnocent[1];
        iBlue = g_iColorInnocent[2];
    }

    SetEntData(skin, iOffset, iRed, _, true);
    SetEntData(skin, iOffset + 1, iGreen, _, true);
    SetEntData(skin, iOffset + 2, iBlue, _, true);
    SetEntData(skin, iOffset + 3, 255, _, true);
}

public Action OnSetTransmit_GlowSkin(int skin, int client)
{
    int iRole = TTT_GetClientRole(client);
    
    int target = -1;
    
    LoopValidClients(i)
    {
        if (i < 1)
        {
            continue;
        }

        if (client == i)
        {
            continue;
        }

        if (!g_cDebug.BoolValue && IsFakeClient(i))
        {
            continue;
        }

        if (!IsPlayerAlive(i))
        {
            continue;
        }

        if (!CPS_HasSkin(i))
        {
            continue;
        }

        if (EntRefToEntIndex(CPS_GetSkin(i)) != skin)
        {
            continue;
        }
        
        target = i;
    }
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    int iTRole = TTT_GetClientRole(target);
        
    if (iRole == TTT_TEAM_DETECTIVE && iRole == iTRole)
    {
        return Plugin_Continue;
    }

    if (iRole == TTT_TEAM_TRAITOR && iRole == iTRole)
    {
        return Plugin_Continue;
    }
    
    bool seeTarget = false;
    bool override = false;
    int red = 255;
    int green = 255;
    int blue = 255;
    int alpha = 255;
    int style = 0;
    
    Call_StartForward(g_hOnGlowCheck);
    Call_PushCell(client);
    Call_PushCell(target);
    Call_PushCellRef(seeTarget);
    Call_PushCellRef(override);
    Call_PushCellRef(red);
    Call_PushCellRef(green);
    Call_PushCellRef(blue);
    Call_PushCellRef(alpha);
    Call_PushCellRef(style);
    Call_Finish();
    
    if (seeTarget && override)
    {
        int iSkin = EntRefToEntIndex(CPS_GetSkin(target));

        if(IsValidEntity(iSkin))
        {
            int iOffset;
    
            if ((iOffset = GetEntSendPropOffs(iSkin, "m_clrGlow")) == -1)
            {
                return Plugin_Handled;
            }
            
            SetEntData(iSkin, iOffset, red, _, true);
            SetEntData(iSkin, iOffset + 1, green, _, true);
            SetEntData(iSkin, iOffset + 2, blue, _, true);
            SetEntData(iSkin, iOffset + 3, alpha, _, true);
            SetEntProp(iSkin, Prop_Send, "m_nGlowStyle", style);
        }
    }
    
    if (seeTarget)
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}
