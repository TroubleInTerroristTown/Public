#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <ttt>
#include <ttt_shop>

#pragma newdecls required

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Radio"

ConVar g_cReopen = null;
ConVar g_cReloadAccess = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

StringMap g_smMenu = null;

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

    TTT_LoadTranslations();
    
    TTT_StartConfig("radio");
    CreateConVar("ttt2_radio_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cReopen = AutoExecConfig_CreateConVar("ttt_radio_reopen", "0", "Reopen radio menu after choose?", _, true, 0.0, true, 1.0);
    g_cReloadAccess = AutoExecConfig_CreateConVar("ttt_radio_reload_access", "z", "Admin flags to access reload radio command.");
    TTT_EndConfig();

    LoadMenu();
    
    RegConsoleCmd("sm_radio", Command_Radio);
    RegConsoleCmd("sm_reload_radio", Command_ReloadRadio);
}

public void OnMapStart()
{
    LoadMenu();
}

public Action Command_ReloadRadio(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }
    
    if (!TTT_CheckCommandAccess(client, "sm_reload_radio", g_cReloadAccess, true))
    {
        return Plugin_Handled;
    }

    LoadMenu();

    return Plugin_Continue;
}

void LoadMenu()
{
    delete g_smMenu;
    g_smMenu = new StringMap();

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/ttt/radio.ini");

    if (!FileExists(sFile))
    {
        SetFailState("[TTT-Radio] Can't open File: %s", sFile);
    }

    KeyValues kv = new KeyValues("TTT-Radio");

    if (!kv.ImportFromFile(sFile))
    {
        delete kv;
        SetFailState("[TTT-Radio] Can't read %s correctly! (ImportFromFile)", sFile);
        return;
    }

    if (!kv.JumpToKey("Order"))
    {
        delete kv;
        SetFailState("[TTT-Radio] Can't read %s correctly! (JumpToKey)", sFile);
        return;
    }

    if (!kv.GotoFirstSubKey(false))
    {
        delete kv;
        SetFailState("[TTT-Radio] Can't read %s correctly! (KvGotoFirstSubKey)", sFile);
        return;
    }

    char sKey[32];
    char sTranslations[64];

    do
    {
        kv.GetSectionName(sKey, sizeof(sKey));
        kv.GetString(NULL_STRING, sTranslations, sizeof(sTranslations));

        g_smMenu.SetString(sKey, sTranslations);
    }
    while (kv.GotoNextKey(false));

    delete kv;
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action Command_Radio(int client, int args)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Handled;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }
    
    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "YouAreDead", client);
        return Plugin_Handled;
    }

    if (args == 0)
    {
        ShowRadioMenu(client);
        return Plugin_Handled;
    }
    
    char sMessage[MAX_MESSAGE_LENGTH];
    GetCmdArgString(sMessage, sizeof(sMessage));
    
    char sColor[16];
    int iTeam = TTT_GetClientTeam(client);
    
    if (iTeam == TTT_TEAM_INNOCENT || iTeam == TTT_TEAM_TRAITOR)
    {
        Format(sColor, sizeof(sColor), "green");
    }
    else if (iTeam == TTT_TEAM_DETECTIVE)
    {
        Format(sColor, sizeof(sColor), "darkblue");
    }
    
    if (strlen(sColor) < 3)
    {
        return Plugin_Handled;
    }
    
    if (StrEqual(sMessage, "yes", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Yes", i);
        }
    }
    
    if (StrEqual(sMessage, "no", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: No", i);
        }
    }
    
    if (StrEqual(sMessage, "maybe", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Maybe", i);
        }
    }
    
    if (StrEqual(sMessage, "help", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Help", i);
        }
    }
    
    if (StrEqual(sMessage, "check", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Check", i);
        }
    }
    
    int iTarget = TraceClientViewEntity(client);
    
    if (!TTT_IsClientValid(iTarget))
    {
        CReplyToCommand(client, "%s %T", g_sPluginTag, "Radio: Invalid target", client);
        return Plugin_Handled;
    }

    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(iTarget, sName, sizeof(sName));
    
    if (StrEqual(sMessage, "imwith", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Im With", i, sName);
        }
    }
    
    if (StrEqual(sMessage, "suspect", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Suspect", i, sName);
        }
    }
    
    if (StrEqual(sMessage, "traitor", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Traitor", i, sName);
        }
    }

    if (StrEqual(sMessage, "kos", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: KOS", i, sName);
        }
    }
    
    if (StrEqual(sMessage, "innocent", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: Innocent", i, sName);
        }
    }
    
    if (StrEqual(sMessage, "see", false))
    {
        LoopValidClients(i)
        {
            CPrintToChat(i, "%s {%s}%N{default}: %T", g_sPluginTag, sColor, client, "TTT Radio: See", i, sName);
        }
    }
    
    return Plugin_Continue;
}

void ShowRadioMenu(int client)
{
    Menu menu = new Menu(Menu_RadioHandler);
    menu.SetTitle("%T", "TTT Radio Menu: Commands", client);

    char sKey[32];
    char sBuffer[64];
    char sTranslations[128];

    StringMapSnapshot smSnapshot = g_smMenu.Snapshot();

    for (int i = 0; i < smSnapshot.Length; i++)
    {
        smSnapshot.GetKey(i, sKey, sizeof(sKey));
        g_smMenu.GetString(sKey, sBuffer, sizeof(sBuffer));
        Format(sTranslations, sizeof(sTranslations), "TTT Radio Menu: %s", sBuffer);
        Format(sTranslations, sizeof(sTranslations), "%T", sTranslations, client);
        menu.AddItem(sKey, sTranslations);
    }

    delete smSnapshot;
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
}

public int Menu_RadioHandler(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sCommand[32];
        menu.GetItem(param, sCommand, sizeof(sCommand));
        FakeClientCommand(client, "sm_radio %s", sCommand);

        RequestFrame(Frame_Reopen, GetClientUserId(client));
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public void Frame_Reopen(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        if (g_cReopen.BoolValue)
        {
            Command_Radio(client, 0);
        }
    }
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
        delete(tr);
        return pEntity;
    }

    if (tr != null)
    {
        delete(tr);
    }

    return -1;
}



public bool TRDontHitSelf(int entity, int mask, any data)
{
    return (entity != data);
}

