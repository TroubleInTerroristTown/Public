#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Hud"

ConVar g_cTextD = null;
ConVar g_cTextI = null;
ConVar g_cTextT = null;
ConVar g_cTextU = null;
ConVar g_cTimer = null;
ConVar g_cKarmaType = null;
ConVar g_cHealthType = null;

int g_iTarget[MAXPLAYERS + 1] = {0, ...};
Handle g_hOnHudSend_Pre = null;

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
    g_hOnHudSend_Pre = CreateGlobalForward("TTT_OnHudSend_Pre", ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_String, Param_CellByRef, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell);

    RegPluginLibrary("ttt_playerhud");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("playerhud");
    CreateConVar("ttt2_playerhud_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cTextD = AutoExecConfig_CreateConVar("hud_display_detective", "{NAME}: {PLAYERNAME}<br>{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a detective. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
    g_cTextI = AutoExecConfig_CreateConVar("hud_display_innocent", "{NAME}: {PLAYERNAME}<br>{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a innocent. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
    g_cTextT = AutoExecConfig_CreateConVar("hud_display_traitor", "{NAME}: {PLAYERNAME}<br>{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a traitor. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
    g_cTextU = AutoExecConfig_CreateConVar("hud_display_unassigned", "{NAME}: {PLAYERNAME}<br>{KARMA}: {PLAYERKARMA}", "The hint text that is displayed to a unassigned. Use {Name} {PlayerName} {Health} {PlayerHealth} {Karma} {PlayerKarma}(See translation)");
    g_cKarmaType = AutoExecConfig_CreateConVar("hud_display_karma_type", "1", "Which karma display you want. 0 - Number (Old), 1 - Name (New)", _, true, 0.0, true, 1.0);
    g_cHealthType = AutoExecConfig_CreateConVar("hud_display_health_type", "1", "Which health display you want. 0 - Number (Old), 1 - Name (New)", _, true, 0.0, true, 1.0);
    g_cTimer = AutoExecConfig_CreateConVar("hud_timer_check", "0.2", "Check each x seconds.");
    TTT_EndConfig();

    TTT_LoadTranslations();
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnAllPluginsLoaded()
{
    char sFile[] = "ttt_player_hud.smx";
    Handle hPlugin = FindPluginByFile(sFile);
    
    if (hPlugin != null && GetPluginStatus(hPlugin) == Plugin_Running)
    {
        SetFailState("Old player hud file found! Please delete '%s'", sFile);
    }
}

public void OnConfigsExecuted()
{
    CreateTimer(g_cTimer.FloatValue, Timer_UpdateText, _, TIMER_REPEAT |  TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateText(Handle timer)
{
    if (!TTT_IsRoundActive())
    {
        return Plugin_Continue;
    }

    LoopValidClients(client)
    {
        if (IsPlayerAlive(client))
        {
            int iTarget = TraceClientViewEntity(client);
            if (iTarget != g_iTarget[client])
            {
                g_iTarget[client] = iTarget;

                if (!TTT_IsClientValid(iTarget))
                {
                    continue;
                }

                char sName[MAX_NAME_LENGTH];
                char sPlayerName[64];
                char sHealth[64];
                char sPlayerHealth[128];
                char sKarma[64];
                char sPlayerKarma[128];
                char sHintText[512];

                if (PrepareText(client, iTarget, sName, sizeof(sName), sPlayerName, sizeof(sPlayerName), sHealth, sizeof(sHealth), sPlayerHealth, sizeof(sPlayerHealth), sKarma, sizeof(sKarma), sPlayerKarma, sizeof(sPlayerKarma), sHintText, sizeof(sHintText)))
                {
                    PrintHintText(client, sHintText);
                }
            }
        }
    }

    return Plugin_Continue;
}

public bool PrepareText(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength, char[] sHintText, int iHintTextLength)
{
    int iHealth = GetClientHealth(target);
    int iKarma = TTT_GetClientKarma(target, false);

    char sKarmaValue[128], sHealthValue[128];
    IntToString(iHealth, sHealthValue, sizeof(sHealthValue));
    IntToString(iKarma, sKarmaValue, sizeof(sKarmaValue));

    char sTranslation[128];

    if (g_cHealthType.IntValue == 1)
    {
        GetTranslationName("Health", iHealth, sTranslation, sizeof(sTranslation));

        char sColor[12];
        if (GetTranslationColor("Health", sTranslation, sColor, sizeof(sColor)))
        {
            Format(sTranslation, sizeof(sTranslation), "HUD Health - %s", sTranslation);
            Format(sHealthValue, sizeof(sHealthValue), "<font color='#%s'>%T</font>", sColor, sTranslation, client);
        }
        else
        {
            Format(sTranslation, sizeof(sTranslation), "HUD Health - %s", sTranslation);
            Format(sHealthValue, sizeof(sHealthValue), "%T", sTranslation, client);
        }
    }
    
    if (g_cKarmaType.IntValue == 1)
    {
        GetTranslationName("Karma", iKarma, sTranslation, sizeof(sTranslation));
        
        char sColor[12];
        if (GetTranslationColor("Karma", sTranslation, sColor, sizeof(sColor)))
        {
            Format(sTranslation, sizeof(sTranslation), "HUD Karma - %s", sTranslation);
            Format(sKarmaValue, sizeof(sKarmaValue), "<font color='#%s'>%T</font>", sColor, sTranslation, client);
        }
        else
        {
            Format(sTranslation, sizeof(sTranslation), "HUD Karma - %s", sTranslation);
            Format(sKarmaValue, sizeof(sKarmaValue), "%T", sTranslation, client);
        }
    }
    
    Format(sName, iNameLength, "%T", "Hud Name", client);
    Format(sHealth, iHealthLength, "%T", "Hud Health", client);
    Format(sPlayerHealth, iPlayerHealthLength, "%T", "Hud PlayerHealth", client, sHealthValue);
    Format(sKarma, iKarmaLength, "%T", "Hud Karma", client);
    Format(sPlayerKarma, iPlayerKarmaLength, "%T", "Hud PlayerKarma", client, sKarmaValue);
    
    int iRole = TTT_GetClientRole(client);
    int iTRole = TTT_GetClientRole(target);
    
    char sText[512];
    
    if (iRole == TTT_TEAM_TRAITOR)
    {
        g_cTextT.GetString(sText, sizeof(sText));
        Format(sText, sizeof(sText), "<pre>%s</pre>", sText);
        strcopy(sHintText, iHintTextLength, sText);
        
        if (iTRole == TTT_TEAM_TRAITOR)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#ff0000'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_DETECTIVE)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#0000ff'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_INNOCENT)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#008000'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_UNASSIGNED)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        g_cTextD.GetString(sText, sizeof(sText));
        Format(sText, sizeof(sText), "<pre>%s</pre>", sText);
        strcopy(sHintText, iHintTextLength, sText);
        
        if (iTRole == TTT_TEAM_TRAITOR)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_DETECTIVE)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#0000ff'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_INNOCENT)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_UNASSIGNED)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
    }
    else if (iRole == TTT_TEAM_INNOCENT)
    {
        g_cTextI.GetString(sText, sizeof(sText));
        Format(sText, sizeof(sText), "<pre>%s</pre>", sText);
        strcopy(sHintText, iHintTextLength, sText);
        
        if (iTRole == TTT_TEAM_TRAITOR)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_DETECTIVE)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#0000ff'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_INNOCENT)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_UNASSIGNED)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
    }
    else if (iRole == TTT_TEAM_UNASSIGNED)
    {
        g_cTextU.GetString(sText, sizeof(sText));
        Format(sText, sizeof(sText), "<pre>%s</pre>", sText);
        strcopy(sHintText, iHintTextLength, sText);
        
        if (iTRole == TTT_TEAM_TRAITOR)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_DETECTIVE)
        {
            Format(sPlayerName, iPlayerNameLength, "<font color='#0000ff'>%N</font>", target);
        }
        else if (iTRole == TTT_TEAM_INNOCENT)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
        else if (iTRole == TTT_TEAM_UNASSIGNED)
        {
            GetClientName(target, sPlayerName, iPlayerNameLength);
        }
    }

    Action res = Plugin_Continue;
    Call_StartForward(g_hOnHudSend_Pre);
    Call_PushCell(client);
    Call_PushCell(target);
    Call_PushStringEx(sName, iNameLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iNameLength);
    Call_PushStringEx(sPlayerName, iPlayerNameLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCellRef(iPlayerNameLength);
    Call_PushStringEx(sHealth, iHealthLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iHealthLength);
    Call_PushStringEx(sPlayerHealth, iPlayerHealthLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iPlayerHealthLength);
    Call_PushStringEx(sKarma, iKarmaLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iKarmaLength);
    Call_PushStringEx(sPlayerKarma, iPlayerKarmaLength, SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iPlayerKarmaLength);
    Call_Finish(res);
    if (res >= Plugin_Handled)
    {
        return false;
    }

    ReplaceString(sHintText, iHintTextLength, "{Name}", sName, false);
    ReplaceString(sHintText, iHintTextLength, "{PlayerName}", sPlayerName, false);
    ReplaceString(sHintText, iHintTextLength, "{Health}", sHealth, false);
    ReplaceString(sHintText, iHintTextLength, "{PlayerHealth}", sPlayerHealth, false);
    ReplaceString(sHintText, iHintTextLength, "{Karma}", sKarma, false);
    ReplaceString(sHintText, iHintTextLength, "{PlayerKarma}", sPlayerKarma, false);

    return true;
}

int TraceClientViewEntity(int client)
{
    float m_vecOrigin[3];
    float m_angRotation[3];

    GetClientEyePosition(client, m_vecOrigin);
    GetClientEyeAngles(client, m_angRotation);

    Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_SOLID, RayType_Infinite, TRDontHitSelf, client);
    int pEntity = -1;

    if (TR_DidHit(tr))
    {
        pEntity = TR_GetEntityIndex(tr);
        delete tr;
        return pEntity;
    }

    delete tr;
    return -1;
}

public bool TRDontHitSelf(int entity, int mask, int data)
{
    return (entity != data);
}

void GetTranslationName(const char[] type, int value, char[] translation, int length)
{
    if (value == -1)
    {
        Format(translation, length, "Invalid");
        return;
    }

    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/hud_config.ini");

    KeyValues kvConfig = new KeyValues("TTT-HUD");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("[TTT-HUD] Can't read \"%s\"! (ImportFromFile)", sFile);
        delete kvConfig;
        return;
    }

    if (!kvConfig.JumpToKey(type, false))
    {
        SetFailState("[TTT-HUD] Can't find the key \"%s\"! (JumpToKey)", type);
        delete kvConfig;
        return;
    }

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sRange[32];
            char sTranslation[64];

            kvConfig.GetSectionName(sRange, sizeof(sRange));
            kvConfig.GetString(NULL_STRING, sTranslation, sizeof(sTranslation));

            char sRanges[2][12];
            ExplodeString(sRange, "-", sRanges, sizeof(sRanges), sizeof(sRanges[]));

            int iMin = StringToInt(sRanges[0]);
            int iMax = StringToInt(sRanges[1]);

            if (value >= iMin && value <= iMax)
            {
                strcopy(translation, length, sTranslation);
                delete kvConfig;
                return;
            }
        }
        while (kvConfig.GotoNextKey(false));
    }

    SetFailState("[TTT-HUD] Can't find value %d for %s!", value, type);
    delete kvConfig;
    return;
}

bool GetTranslationColor(const char[] type, const char[] translation, char[] sColor, int length)
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/hud_config.ini");

    KeyValues kvConfig = new KeyValues("TTT-HUD");

    if (!kvConfig.ImportFromFile(sFile))
    {
        SetFailState("[TTT-HUD] Can't read \"%s\"! (ImportFromFile)", sFile);
        delete kvConfig;
        return false;
    }

    if (!kvConfig.JumpToKey("Colors", false))
    {
        delete kvConfig;
        return false;
    }

    char sKey[128];
    Format(sKey, sizeof(sKey), "%s-%s", type, translation);

    if (kvConfig.GotoFirstSubKey(false))
    {
        do
        {
            char sKey2[32];

            kvConfig.GetSectionName(sKey2, sizeof(sKey2));

            if (StrEqual(sKey2, sKey, false))
            {
                kvConfig.GetString(NULL_STRING, sColor, length);
                delete kvConfig;
                return true;
            }
        }
        while (kvConfig.GotoNextKey(false));
    }

    delete kvConfig;
    return false;
}
