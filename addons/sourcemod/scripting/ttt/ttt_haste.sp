#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ttt>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Haste Mode"

int g_iRoundStart = -1;

ConVar g_cRequired = null;
ConVar g_cPercent = null;
ConVar g_cFactor = null;
ConVar g_cSecondsOn = null;
ConVar g_cTraitorGoodKillDetective = null;
ConVar g_cTraitorGoodKillInnocent = null;
ConVar g_cTraitorBadKill = null;
ConVar g_cKillTraitor = null;

bool g_bIsActive = false;

Handle g_hRoundTimer = null;

ConVar g_cDebugMessage = null;

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
    CreateNative("TTT_IsHasteActive", Native_IsHasteActive);
    CreateNative("TTT_SetHasteTime", Native_SetHasteTime);
    CreateNative("TTT_AddHasteTime", Native_AddHasteTime);
    CreateNative("TTT_RemoveHasteTime", Native_RemoveHasteTime);

    RegPluginLibrary("ttt_haste");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();
    
    TTT_StartConfig("haste_mode");
    CreateConVar("ttt2_haste_mode_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cRequired = AutoExecConfig_CreateConVar("haste_mode_required_players", "8", "The required amount of players which will be for enabling haste mode.");
    g_cPercent = AutoExecConfig_CreateConVar("haste_mode_random_chance", "20", "What is the chance (in percent (1-100)) for a haste round?");
    g_cFactor = AutoExecConfig_CreateConVar("haste_mode_player_factor", "15", "The player factor (in seconds) to calcuate the round time.\nFormula: (Amount of ALL players * Player Factor) - (Amount of traitors) * (Player factor) = Haste Round Time", _, true, 5.0);
    g_cSecondsOn = AutoExecConfig_CreateConVar("haste_mode_on_kill_identify", "0", "Add/Remove seconds on player death (0) or on player identify (1)?", _, true, 0.0, true, 1.0);
    g_cTraitorGoodKillDetective = AutoExecConfig_CreateConVar("haste_mode_good_detective_kill_as_traitor", "20", "How many seconds should be added, when traitor kills a detective? ( 0 - Disabled )");
    g_cTraitorGoodKillInnocent = AutoExecConfig_CreateConVar("haste_mode_good_innocent_kill_as_traitor", "15", "How many seconds should be added, when traitor kills a innocent? ( 0 - Disabled )");
    g_cTraitorBadKill = AutoExecConfig_CreateConVar("haste_mode_bad_kill_as_traitor", "5", "How many seconds should be removed, when traitor makes a bad kill? ( 0 - Disabled )");
    g_cKillTraitor = AutoExecConfig_CreateConVar("haste_mode_traitor_kill", "5", "How many seconds should be removed, when a innocent/detectives kills a`traitor? ( 0 - Disabled )");
    TTT_EndConfig();

    HookEvent("round_prestart", Event_RoundStartPre, EventHookMode_Pre);
}

public void OnConfigsExecuted()
{
    g_cDebugMessage = FindConVar("ttt_show_debug_messages");
}

public void OnMapEnd()
{
    g_hRoundTimer = null;
}

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundStart = GetTime();
    g_bIsActive = false;
    
    return Plugin_Continue;
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detectives)
{
    int iCount = innocents + traitors + detectives;

    if (g_cRequired.IntValue == 0 || g_cRequired.IntValue < iCount)
    {
        StartHasteRound(iCount, traitors);
    }
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    TTT_ClearTimer(g_hRoundTimer);
}

public void TTT_OnBodyFound(int client, int victim, int victimRole, int attackerRole, int entityref, bool silentID)
{
    if (g_cSecondsOn.BoolValue)
    {
        CalculateTime(victimRole, attackerRole);
    }
}

public void TTT_OnClientDeath(int victim, int attacker, bool badAction)
{
    if (!g_cSecondsOn.IntValue)
    {
        CalculateTime(TTT_GetClientRole(victim), TTT_GetClientRole(attacker));
    }
}

public int Native_IsHasteActive(Handle plugin, int numParams)
{
    return g_bIsActive;
}

public int Native_SetHasteTime(Handle plugin, int numParams)
{
    int iTime = GetNativeCell(1);
    
    if (iTime > 0)
    {
        SetRoundTime(iTime);
    }

    return GetCurrentTime();
}

public int Native_AddHasteTime(Handle plugin, int numParams)
{
    int iTime = GetNativeCell(1);
    
    if (iTime > 0)
    {
        AddRoundTime(iTime);
    }

    return GetCurrentTime();
}

public int Native_RemoveHasteTime(Handle plugin, int numParams)
{
    int iTime = GetNativeCell(1);
    
    if (iTime > 0)
    {
        RemoveRoundTime(iTime);
    }

    return GetCurrentTime();
}

void StartHasteRound(int players, int traitors)
{
    delete g_hRoundTimer;

    int iRandom = GetRandomInt(1, 100);

    if (iRandom > g_cPercent.IntValue)
    {
        return;
    }

    g_bIsActive = true;

    int iOldTime = GetCurrentTime();

    if (g_cDebugMessage.BoolValue)
    {
        LogMessage("GetCurrentTime: %d, GameRule_iRoundTime: %d, GetPlayTime: %d", GetCurrentTime(), GameRules_GetProp("m_iRoundTime"), GetPlayTime());
        PrintToChatAll("GetCurrentTime: %d, GameRule_iRoundTime: %d, GetPlayTime: %d", GetCurrentTime(), GameRules_GetProp("m_iRoundTime"), GetPlayTime());
    }

    int iRoundTime = ((players * g_cFactor.IntValue) - (traitors * g_cFactor.IntValue));
    SetRoundTime(iRoundTime + (GetTime() - g_iRoundStart));
    
    LoopValidClients(i)
    {
        CPrintToChat(i, "%T", "Chat - Haste: Haste Round Start", i, ((iRoundTime / 60) % 60), (iRoundTime % 60));
    } 

    TTT_StopRoundTimer();

    if (g_cDebugMessage.BoolValue)
    {
        LogMessage("[Haste] SetRoundTime: %d (players: %d, traitors: %d, factor: %d), Current Time: %d, Old Time: %d", iRoundTime, players, traitors, g_cFactor.IntValue, iRoundTime, iOldTime);
        PrintToChatAll("[Haste] SetRoundTime: %d (players: %d, traitors: %d, factor: %d), Current Time: %d, Old Time: %d", iRoundTime, players, traitors, g_cFactor.IntValue, iRoundTime, iOldTime);
    }
    
    g_hRoundTimer = CreateTimer(1.0, Timer_RoundTime, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void SetRoundTime(int seconds)
{
    if (!g_bIsActive)
    {
        return;
    }
    
    int iRoundTime = seconds;

    if (iRoundTime <= 0)
    {
        TTT_TerminateRound(3.0, CSRoundEnd_Draw);
        return;
    }

    GameRules_SetProp("m_iRoundTime", iRoundTime, _, _, true);
}

void AddRoundTime(int seconds)
{
    if (!g_bIsActive)
    {
        return;
    }
    
    int time = GameRules_GetProp("m_iRoundTime");
    int newTime = time + seconds;

    if (newTime <= 0)
    {
        TTT_TerminateRound(3.0, CSRoundEnd_Draw);
        return;
    }

    GameRules_SetProp("m_iRoundTime", newTime, _, _, true);
}

void RemoveRoundTime(int seconds)
{
    if (!g_bIsActive)
    {
        return;
    }
    
    int time = GameRules_GetProp("m_iRoundTime");
    int newTime = time - seconds;

    if (newTime <= 0)
    {
        TTT_TerminateRound(3.0, CSRoundEnd_Draw);
        return;
    }

    GameRules_SetProp("m_iRoundTime", newTime, _, _, true);
}

int GetPlayTime()
{
    return (GetTime() - g_iRoundStart);
}

int GetCurrentTime()
{
    return GameRules_GetProp("m_iRoundTime") - GetPlayTime();
}

void CalculateTime(int victimRole, int attackerRole)
{
    if (attackerRole == TTT_TEAM_TRAITOR)
    {
        if (victimRole == TTT_TEAM_TRAITOR)
        {
            if (g_cTraitorBadKill.IntValue > 0)
            {
                RemoveRoundTime(g_cTraitorBadKill.IntValue);
            }
        }
        else if (victimRole == TTT_TEAM_INNOCENT)
        {
            if (g_cTraitorGoodKillInnocent.IntValue > 0)
            {
                AddRoundTime(g_cTraitorGoodKillInnocent.IntValue);
            }
        }
        else if (victimRole == TTT_TEAM_DETECTIVE)
        {
            if (g_cTraitorGoodKillDetective.IntValue > 0)
            {
                AddRoundTime(g_cTraitorGoodKillDetective.IntValue);
            }
        }
    }
    else if ((attackerRole == TTT_TEAM_DETECTIVE || attackerRole == TTT_TEAM_INNOCENT) && victimRole == TTT_TEAM_TRAITOR)
    {
        if (g_cKillTraitor.IntValue > 0)
        {
            RemoveRoundTime(g_cKillTraitor.IntValue);
        }
    }
}

public Action Timer_RoundTime(Handle timer)
{
    if (GetCurrentTime() < 0)
    {
        TTT_TerminateRound(3.0, CSRoundEnd_CTWin);
    }
    
    return Plugin_Continue;
}
