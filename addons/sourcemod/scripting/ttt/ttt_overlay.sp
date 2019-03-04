#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Overlays"

#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

ConVar g_cTraitorIcon = null;
ConVar g_cDetectiveIcon = null;
ConVar g_cInnocentIcon = null;
ConVar g_coverlayDWin = null;
ConVar g_coverlayTWin = null;
ConVar g_coverlayIWin = null;
ConVar g_cEnableHud = null;
ConVar g_cPosRX = null;
ConVar g_cPosRY = null;
ConVar g_cPosDX = null;
ConVar g_cPosDY = null;
ConVar g_cPosIX = null;
ConVar g_cPosIY = null;
ConVar g_cPosTX = null;
ConVar g_cPosTY = null;
ConVar g_cColorR = null;
ConVar g_cColorD = null;
ConVar g_cColorI = null;
ConVar g_cColorT = null;
ConVar g_cUpdateTeamScore = null;
ConVar g_cSeeRole = null;
ConVar g_cTimeOverlays = null;
ConVar g_cTimeOverlaysTime = null;

bool g_bEndOverlay = false;

int g_iCTWin = 0;
int g_iTWin = 0;

Handle g_hSyncR = null;
Handle g_hSyncD = null;
Handle g_hSyncI = null;
Handle g_hSyncT = null;

StringMap g_smTimeOverlays = null;

bool g_bTimeOverlay = false;
bool g_bDisableRoleOverlays = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_DisableRoleOverlays", Native_DisableRoleOverlays);
    
    RegPluginLibrary("ttt_overlay");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_StartConfig("overlay");
    CreateConVar("ttt2_overlay_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cDetectiveIcon = AutoExecConfig_CreateConVar("ttt_overlay_detective", "darkness/ttt/overlayDetective", "The overlay to display for detectives during the round.");
    g_cTraitorIcon = AutoExecConfig_CreateConVar("ttt_overlay_traitor", "darkness/ttt/overlayTraitor", "The overlay to display for detectives during the round.");
    g_cInnocentIcon = AutoExecConfig_CreateConVar("ttt_overlay_inno", "darkness/ttt/overlayInnocent", "The overlay to display for detectives during the round.");
    g_coverlayDWin = AutoExecConfig_CreateConVar("ttt_overlay_detective_win", "overlays/ttt/detectives_winNew", "The overlay to display when detectives win.");
    g_coverlayTWin = AutoExecConfig_CreateConVar("ttt_overlay_traitor_win", "overlays/ttt/traitors_winNew", "The overlay to display when traitors win.");
    g_coverlayIWin = AutoExecConfig_CreateConVar("ttt_overlay_inno_win", "overlays/ttt/innocents_winNew", "The overlay to display when innocent win.");
    g_cEnableHud = AutoExecConfig_CreateConVar("ttt_hud_text_enable", "0", "Enable hud_text? (it's a bit buggy with 4:3 and 16:9 resolutions)", _, true, 0.0, true, 1.0);
    g_cPosRX = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_x_position", "0.28", "Remaining position (Default Horizontal: 0.28 Vertical: 0.2) (<X>-POSITION>)");
    g_cPosDX = AutoExecConfig_CreateConVar("ttt_hud_text_detective_x_position", "0.37", "Detective position (Default Horizontal: 0.37 Vertical: 0.3) (<X>-POSITION>)");
    g_cPosIX = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_x_position", "0.48", "Innocent position (Default Horizontal: 0.48 Vertical: 0.3,) (<X>-POSITION>)");
    g_cPosTX = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_x_position", "0.586", "Traitor position (Default Horizontal: 0.586 Vertical: 0.3) (<X>-POSITION>)");
    g_cPosRY = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_y_position", "0.06", "Remaining position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
    g_cPosDY = AutoExecConfig_CreateConVar("ttt_hud_text_detective_y_position", "0.06", "Detective position (Default Horizontal: 0.0 Vertical: 0.0) (<Y>-POSITION>)");
    g_cPosIY = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_y_position", "0.06", "Innocent position (Default Horizontal: 0.0 Vertical: 0.05) (<Y>-POSITION>)");
    g_cPosTY = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_y_position", "0.06", "Traitor position (Default Horizontal: 0.0 Vertical: 0.1) (<Y>-POSITION>)");
    g_cColorR = AutoExecConfig_CreateConVar("ttt_hud_text_remaining_color", "255;255,255", "Remaining color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
    g_cColorD = AutoExecConfig_CreateConVar("ttt_hud_text_detective_color", "0;0;255", "Detective color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
    g_cColorI = AutoExecConfig_CreateConVar("ttt_hud_text_innocent_color", "0;255;0", "Innocent color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
    g_cColorT = AutoExecConfig_CreateConVar("ttt_hud_text_traitor_color", "255;0;0", "Traitor color in rbga (<RED>,<GREEN>,<BLUE>,<ALPHA>)");
    g_cUpdateTeamScore = AutoExecConfig_CreateConVar("ttt_team_score_update", "1", "Update team score based on detective/innocent win and traitor win?", _, true, 0.0, true, 1.0);
    g_cTimeOverlays = AutoExecConfig_CreateConVar("ttt_time_overlays_enable", "0", "Enable / Disable time overlays? You could show overlays during a active(!) round. 0 - Disable, 1 - Enable", _, true, 0.0, true, 1.0);
    g_cTimeOverlaysTime = AutoExecConfig_CreateConVar("ttt_time_overlays_time", "3.0", "Time in seconds how long the time overlays will be shown.");
    TTT_EndConfig();

    g_hSyncR = CreateHudSynchronizer();
    g_hSyncD = CreateHudSynchronizer();
    g_hSyncI = CreateHudSynchronizer();
    g_hSyncT = CreateHudSynchronizer();

    CreateTimer(1.0, Timer_HUD, _, TIMER_REPEAT);

    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnMapStart()
{
    char sBuffer[PLATFORM_MAX_PATH];
    
    g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }
    g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }


    g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }


    g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_iCTWin = 0;
    g_iTWin = 0;

    PrecacheTimeOverlays();
}

void PrecacheTimeOverlays()
{
    delete g_smTimeOverlays;
    g_smTimeOverlays = new StringMap();

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/time_overlays.ini");

    if (!FileExists(sFile))
    {
        SetFailState("[Time-Overlays] Can't open File: %s", sFile);
    }

    KeyValues kv = new KeyValues("Time-Overlays");

    if (!kv.ImportFromFile(sFile))
    {
        delete kv;
        SetFailState("[Time-Overlays] Can't read %s correctly! (ImportFromFile)", sFile);
        return;
    }

    if (!kv.GotoFirstSubKey(false))
    {
        delete kv;
        SetFailState("[Time-Overlays] Can't read %s correctly! (KvGotoFirstSubKey)", sFile);
        return;
    }

    char sTime[32];
    char sOverlay[PLATFORM_MAX_PATH];

    do
    {
        kv.GetSectionName(sTime, sizeof(sTime));
        kv.GetString(NULL_STRING, sOverlay, sizeof(sOverlay));

        if (strlen(sOverlay) > 2)
        {
            char sFullPath[PLATFORM_MAX_PATH];
            Format(sFullPath, sizeof(sFullPath), "materials/%s.vmt", sOverlay);
            AddFileToDownloadsTable(sFullPath);
            Format(sFullPath, sizeof(sFullPath), "materials/%s.vtf", sOverlay);
            AddFileToDownloadsTable(sFullPath);
            PrecacheDecal(sFullPath, true);

            g_smTimeOverlays.SetString(sTime, sOverlay);

            LogMessage("[Time-Overlays] Time: %s, Overlay: %s", sTime, sOverlay);
        }
    }
    while (kv.GotoNextKey(false));

    delete kv;
}

public void OnAllPluginsLoaded()
{
    g_cSeeRole = FindConVar("ttt_dead_players_can_see_other_roles");
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    ResetStuff();
}

public Action TTT_OnRoundStart_Pre()
{
    ResetStuff();
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    g_bTimeOverlay = false;
    g_bDisableRoleOverlays = false;
    ConVar cCvar = FindConVar("ttt_after_round_delay");
    
    if (cCvar.FloatValue > 0.0)
    {
        g_bEndOverlay = true;
        CreateTimer(cCvar.FloatValue, Timer_Delay);
    }
    
    char sBuffer[PLATFORM_MAX_PATH];
    if (winner == TTT_TEAM_TRAITOR)
    {
        g_iTWin++;
        
        g_coverlayTWin.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToAll(sBuffer);
    }
    else if (winner == TTT_TEAM_INNOCENT)
    {
        g_iCTWin++;
        
        g_coverlayIWin.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToAll(sBuffer);
    }
    else if (winner == TTT_TEAM_DETECTIVE)
    {
        g_iCTWin++;
        
        g_coverlayDWin.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToAll(sBuffer);
    }
    
    if (g_cUpdateTeamScore.BoolValue)
    {
        CS_SetTeamScore(CS_TEAM_CT, g_iCTWin);
        CS_SetTeamScore(CS_TEAM_T, g_iTWin);
    }
}

public Action Timer_Delay(Handle timer, any data)
{
    g_bEndOverlay = false;
}

public void TTT_OnClientGetRole(int client, int role)
{
    SetOverlay(client, role);
}

public Action Timer_HUD(Handle timer)
{
    if (!TTT_IsRoundActive())
    {
        return;
    }
    
    int iDet = 0;
    int iInn = 0;
    int iTra = 0;

    LoopValidClients(i)
    {
        if (!g_bEndOverlay)
        {
            SetOverlay(i, TTT_GetClientRole(i));
        }
        
        if (!TTT_WasBodyFound(i))
        {
            if (TTT_GetClientRole(i) == TTT_TEAM_DETECTIVE)
            {
                iDet++;
            }
            else if (TTT_GetClientRole(i) == TTT_TEAM_INNOCENT)
            {
                iInn++;
            }
            else if (TTT_GetClientRole(i) == TTT_TEAM_TRAITOR)
            {
                iTra++;
            }
        }
    }

    if (g_cEnableHud.BoolValue)
    {
        char sBuffer[32];
        char sCR[4][4], sCD[4][4], sCI[4][4], sCT[4][4];
        char sR[24], sD[24], sI[24], sT[24];
        
        g_cColorR.GetString(sBuffer, sizeof(sBuffer));
        Format(sR, sizeof(sR), "Remaining:");
        ExplodeString(sBuffer, ";", sCR, sizeof(sCR), sizeof(sCR[]));

        if (iDet == 1)
        {
            Format(sD, sizeof(sD), "%d Detective", iDet);
        }
        else if (iDet > 1)
        {
            Format(sD, sizeof(sD), "%d Detectives", iDet);
        }
        g_cColorD.GetString(sBuffer, sizeof(sBuffer));
        ExplodeString(sBuffer, ";", sCD, sizeof(sCD), sizeof(sCD[]));

        if (iInn == 1)
        {
            Format(sI, sizeof(sI), "%d Innocent", iInn);
        }
        else if (iInn > 1)
        {
            Format(sI, sizeof(sI), "%d Innocents", iInn);
        }
        g_cColorI.GetString(sBuffer, sizeof(sBuffer));
        ExplodeString(sBuffer, ";", sCI, sizeof(sCI), sizeof(sCI[]));

        if (iTra == 1)
        {
            Format(sT, sizeof(sT), "%d Traitor", iTra);
        }
        else if (iTra > 1)
        {
            Format(sT, sizeof(sT), "%d Traitors", iTra);
        }
        g_cColorT.GetString(sBuffer, sizeof(sBuffer));
        ExplodeString(sBuffer, ";", sCT, sizeof(sCT), sizeof(sCT[]));

        showHudToAll(sR, g_hSyncR, g_cPosRX.FloatValue, g_cPosRY.FloatValue, sCR[0], sCR[1], sCR[2], sCR[3]);
        showHudToAll(sD, g_hSyncD, g_cPosDX.FloatValue, g_cPosDY.FloatValue, sCD[0], sCD[1], sCD[2], sCD[3]);
        showHudToAll(sI, g_hSyncI, g_cPosIX.FloatValue, g_cPosIY.FloatValue, sCI[0], sCI[1], sCI[2], sCI[3]);
        showHudToAll(sT, g_hSyncT, g_cPosTX.FloatValue, g_cPosTY.FloatValue, sCT[0], sCT[1], sCT[2], sCT[3]);
    }

    if (g_cTimeOverlays.BoolValue)
    {
        int iLeft = TTT_GetRoundTimeLeft();

        char sLeft[12], sOverlay[PLATFORM_MAX_PATH];
        IntToString(iLeft, sLeft, sizeof(sLeft));

        if (g_smTimeOverlays.GetString(sLeft, sOverlay, sizeof(sOverlay)))
        {
            g_bTimeOverlay = true;
            CreateTimer(g_cTimeOverlaysTime.FloatValue, Timer_DisableTimeOverlays);
            TTT_ShowOverlayToAll(sOverlay);
        }
    }
}

public Action Timer_DisableTimeOverlays(Handle timer)
{
    g_bTimeOverlay = false;
    return Plugin_Stop;
}

public void SetOverlay(int client, int role)
{
    if (g_bTimeOverlay || g_bDisableRoleOverlays)
    {
        return;
    }

    if (TTT_GetClientRole(client) < TTT_TEAM_INNOCENT)
    {
        TTT_ShowOverlayToClient(client, " ");
    }

    if (!TTT_IsPlayerAlive(client))
    {
        TTT_ShowOverlayToClient(client, " ");
    }

    if (g_cSeeRole != null)
    {
        if (g_cSeeRole.BoolValue && !TTT_IsPlayerAlive(client))
        {
            int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

            if (iMode == SPECMODE_FIRSTPERSON || iMode == SPECMODE_3RDPERSON)
            {
                int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

                if (TTT_IsClientValid(target) && TTT_IsPlayerAlive(target))
                {
                    role = TTT_GetClientRole(target);
                }
            }
        }
    }

    char sBuffer[PLATFORM_MAX_PATH];
    if (role == TTT_TEAM_DETECTIVE)
    {
        g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToClient(client, sBuffer);
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToClient(client, sBuffer);
    }
    else if (role == TTT_TEAM_INNOCENT)
    {
        g_cInnocentIcon.GetString(sBuffer, sizeof(sBuffer));
        TTT_ShowOverlayToClient(client, sBuffer);
    }
}

void showHudToAll(char[] message, Handle sync, float x, float y, const char[] red, const char[] green, const char[] blue, const char[] alpha)
{
    LoopValidClients(client)
    {
        SetHudTextParams(x, y, 2.1, StringToInt(red), StringToInt(green), StringToInt(blue), StringToInt(alpha), 0, 0.0, 0.0, 0.0);
        ShowSyncHudText(client, sync, message);
    }
}

void ResetStuff()
{
    g_bTimeOverlay = false;
    g_bDisableRoleOverlays = false;
    g_bEndOverlay = false;
    TTT_ShowOverlayToAll(" ");
}

public int Native_DisableRoleOverlays(Handle plugin, int numParams)
{
    float fTime = view_as<float>(GetNativeCell(1));
    g_bDisableRoleOverlays = true;
    CreateTimer(fTime, Timer_EnableRoleOverlays);
}

public Action Timer_EnableRoleOverlays(Handle timer)
{
    g_bDisableRoleOverlays = false;
    return Plugin_Stop;
}
