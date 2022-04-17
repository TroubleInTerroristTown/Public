#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_bodies>

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

ConVar g_cIconPath = null;
ConVar g_cWinPath = null;
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
ConVar g_cHudTextDeadPlayers = null;
ConVar g_cHudTextFlag = null;

bool g_bEndOverlay = false;

int g_iCTWin = 0;
int g_iTWin = 0;

Handle g_hSyncR = null;
Handle g_hSyncD = null;
Handle g_hSyncI = null;
Handle g_hSyncT = null;

GlobalForward g_fwOnPrecacheWinOverlay = null;
GlobalForward g_fwOnPrecacheRoleOverlay = null;
GlobalForward g_fwOnWinOverlay = null;
GlobalForward g_fwOnRoleOverlay = null;

StringMap g_smTimeOverlays = null;

bool g_bTimeOverlay = false;
bool g_bDisableRoleOverlays = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_DisableRoleOverlays", Native_DisableRoleOverlays);
    CreateNative("TTT_PrecacheIconOverlay", Native_PrecacheIconOverlay);
    CreateNative("TTT_PrecacheWinOverlay", Native_PrecacheWinOverlay);

    g_fwOnPrecacheWinOverlay = new GlobalForward("Overlay_OnPrecacheWinOverlay", ET_Event, Param_String, Param_Cell);
    g_fwOnPrecacheRoleOverlay = new GlobalForward("Overlay_OnPrecacheRoleOverlay", ET_Event, Param_String, Param_Cell);
    g_fwOnWinOverlay = new GlobalForward("Overlay_OnWinOverlay", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
    g_fwOnRoleOverlay = new GlobalForward("Overlay_OnRoleOverlay", ET_Event, Param_Cell, Param_String, Param_Cell);
    
    RegPluginLibrary("ttt_overlay");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_StartConfig("overlay");
    CreateConVar("ttt2_overlay_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cIconPath = AutoExecConfig_CreateConVar("ttt_overlay_icon_path", "ttt/default/overlays/icon/ttt_overlay_icon_<NAME>", "Overlay path to all icon files. Don't remove <NAME>");
    g_cWinPath = AutoExecConfig_CreateConVar("ttt_overlay_win_path", "ttt/default/overlays/win/ttt_overlay_win_<NAME>", "Overlay path to all win files. Don't remove <NAME>");
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
    g_cHudTextDeadPlayers = AutoExecConfig_CreateConVar("ttt_hud_text_dead_players", "0", "Show hud text only to dead players?", _, true, 0.0, true, 1.0);
    g_cHudTextFlag = AutoExecConfig_CreateConVar("ttt_hud_text_flag", "", "Show hud text only to specific players with specific flag(s).");
    TTT_EndConfig();

    g_hSyncR = CreateHudSynchronizer();
    g_hSyncD = CreateHudSynchronizer();
    g_hSyncI = CreateHudSynchronizer();
    g_hSyncT = CreateHudSynchronizer();

    CreateTimer(1.0, Timer_HUD, _, TIMER_REPEAT);

    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnMapStart()
{
    char sBuffer[PLATFORM_MAX_PATH];
    
    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocents");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocents");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitors");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }
    
    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitors");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    char sWinFile[PLATFORM_MAX_PATH];
    g_cWinPath.GetString(sWinFile, sizeof(sWinFile));
    Action res = Plugin_Handled;

    Call_StartForward(g_fwOnPrecacheWinOverlay);
    Call_PushStringEx(sWinFile, sizeof(sWinFile), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sWinFile));
    Call_Finish(res);

    if (res == Plugin_Changed && StrContains(sWinFile, "<NAME>", false) == -1)
    {
        LogMessage("Overlays - Precache Win: %s", sWinFile);
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sWinFile);
        AddFileToDownloadsTable(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sWinFile);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocent");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocent");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitor");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sBuffer);
    }

    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitor");
    if (strlen(sBuffer) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }

    char sRoleOverlay[PLATFORM_MAX_PATH];
    g_cIconPath.GetString(sRoleOverlay, sizeof(sRoleOverlay));
    res = Plugin_Handled;

    Call_StartForward(g_fwOnPrecacheRoleOverlay);
    Call_PushStringEx(sRoleOverlay, sizeof(sRoleOverlay), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sRoleOverlay));
    Call_Finish(res);

    if (res == Plugin_Changed && StrContains(sRoleOverlay, "<NAME>", false) == -1)
    {
        LogMessage("Overlays - Precache Icon: %s", sRoleOverlay);
        
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sRoleOverlay);
        AddFileToDownloadsTable(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sRoleOverlay);
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
    g_cSeeRole = FindConVar("ttt_dead_players_can_see_other_teams");
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    ResetStuff();
    
    return Plugin_Continue;
}

public Action TTT_OnRoundStart_Pre()
{
    ResetStuff();
    
    return Plugin_Continue;
}

public void TTT_OnRoundEnd(int winner, int role, Handle array)
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
    g_cWinPath.GetString(sBuffer, sizeof(sBuffer));

    if (winner == TTT_TEAM_TRAITOR)
    {
        g_iTWin++;
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitors");
    }
    else if (winner == TTT_TEAM_INNOCENT)
    {
        g_iCTWin++;
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocents");
    }
    else if (winner == TTT_TEAM_DETECTIVE)
    {
        g_iCTWin++;
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    }

    char sFile[PLATFORM_MAX_PATH];
    Action res = Plugin_Handled;

    Call_StartForward(g_fwOnWinOverlay);
    Call_PushCell(winner);
    Call_PushCell(role);
    Call_PushStringEx(sFile, sizeof(sFile), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sFile));
    Call_Finish(res);

    if (strlen(sFile) > 3 && res == Plugin_Changed)
    {
        strcopy(sBuffer, sizeof(sBuffer), sFile);
    }

    TTT_ShowOverlayToAll(sBuffer);
    
    if (g_cUpdateTeamScore.BoolValue)
    {
        CS_SetTeamScore(CS_TEAM_CT, g_iCTWin);
        CS_SetTeamScore(CS_TEAM_T, g_iTWin);
    }
}

public Action Timer_Delay(Handle timer, any data)
{
    g_bEndOverlay = false;
    
    return Plugin_Handled;
}

public void TTT_OnClientGetRole(int client, int team, int role)
{
    SetOverlay(client, team);
}

public Action Timer_HUD(Handle timer)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }
    
    int iDet = 0;
    int iInn = 0;
    int iTra = 0;

    LoopValidClients(i)
    {
        if (!g_bEndOverlay)
        {
            SetOverlay(i, TTT_GetClientTeam(i));
        }
        
        if (!TTT_WasBodyFound(i))
        {
            if (TTT_GetClientTeam(i) == TTT_TEAM_DETECTIVE)
            {
                iDet++;
            }
            else if (TTT_GetClientTeam(i) == TTT_TEAM_INNOCENT)
            {
                iInn++;
            }
            else if (TTT_GetClientTeam(i) == TTT_TEAM_TRAITOR)
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
    
    return Plugin_Continue;
}

public Action Timer_DisableTimeOverlays(Handle timer)
{
    g_bTimeOverlay = false;
    return Plugin_Stop;
}

public void SetOverlay(int client, int team)
{
    if (g_bTimeOverlay || g_bDisableRoleOverlays)
    {
        return;
    }

    if (TTT_GetClientTeam(client) < TTT_TEAM_INNOCENT)
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
                    team = TTT_GetClientTeam(target);
                }
            }
        }
    }

    char sBuffer[PLATFORM_MAX_PATH];
    g_cIconPath.GetString(sBuffer, sizeof(sBuffer));
    if (team == TTT_TEAM_DETECTIVE)
    {
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "detectives");
    }
    else if (team == TTT_TEAM_TRAITOR)
    {
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "traitor");
    }
    else if (team == TTT_TEAM_INNOCENT)
    {
        ReplaceString(sBuffer, sizeof(sBuffer), "<NAME>", "innocent");
    }

    char sFile[PLATFORM_MAX_PATH];
    Action res = Plugin_Handled;

    Call_StartForward(g_fwOnRoleOverlay);
    Call_PushCell(client);
    Call_PushStringEx(sFile, sizeof(sFile), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sFile));
    Call_Finish(res);

    if (strlen(sFile) > 3 && res == Plugin_Changed)
    {
        strcopy(sBuffer, sizeof(sBuffer), sFile);
    }

    TTT_ShowOverlayToClient(client, sBuffer);
}

void showHudToAll(char[] message, Handle sync, float x, float y, const char[] red, const char[] green, const char[] blue, const char[] alpha)
{
    LoopValidClients(client)
    {
        if (g_cHudTextDeadPlayers.BoolValue && TTT_IsPlayerAlive(client))
        {
            continue;
        }

        char sBuffer[18];
        g_cHudTextFlag.GetString(sBuffer, sizeof(sBuffer));

        if (strlen(sBuffer) > 0 && !TTT_CheckCommandAccess(client, "ttt_hud_text", g_cHudTextFlag, true))
        {
            continue;
        }

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
    
    return 0;
}

public Action Timer_EnableRoleOverlays(Handle timer)
{
    g_bDisableRoleOverlays = false;
    return Plugin_Stop;
}

public int Native_PrecacheIconOverlay(Handle plugin, int numParams)
{
    char sRole[32];
    GetNativeString(1, sRole, sizeof(sRole));

    if (strlen(sRole) > 3)
    {
        char sOverlay[PLATFORM_MAX_PATH];
        g_cIconPath.GetString(sOverlay, sizeof(sOverlay));

        ReplaceString(sOverlay, sizeof(sOverlay), "<NAME>", sRole);
        
        char sBuffer[PLATFORM_MAX_PATH + 1];
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sOverlay);
        AddFileToDownloadsTable(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sOverlay);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }
    
    return 0;
}

public int Native_PrecacheWinOverlay(Handle plugin, int numParams)
{
    char sRole[32];
    GetNativeString(1, sRole, sizeof(sRole));

    if (strlen(sRole) > 3)
    {
        char sOverlay[PLATFORM_MAX_PATH];
        g_cWinPath.GetString(sOverlay, sizeof(sOverlay));

        ReplaceString(sOverlay, sizeof(sOverlay), "<NAME>", sRole);
        
        char sBuffer[PLATFORM_MAX_PATH + 1];
        Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sOverlay);
        AddFileToDownloadsTable(sBuffer);

        Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sOverlay);
        AddFileToDownloadsTable(sBuffer);
        PrecacheDecal(sBuffer, true);
    }
    
    return 0;
}
