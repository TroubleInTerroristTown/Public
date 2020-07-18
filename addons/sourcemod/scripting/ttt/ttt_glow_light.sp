#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow Light"

#define TTT_INNOCENT_COLOR 0x00FF00
#define TTT_TRAITOR_COLOR 0xFF0000
#define TTT_DETECTIVE_COLOR 0x0000FF

ConVar g_cGlowMaterial = null;
ConVar g_cGlowScale = null;
ConVar g_cGlowDetective = null;
ConVar g_cGlowTraitor = null;

int g_iSkinClient[2048] = { -1 , ... };

enum struct PlayerData
{
    int iSkinRef;

    bool bCanSee[MAXPLAYERS + 1];
    bool bCanSeeAll;
    bool bAllCanSee;

    Handle hColorReset;
    Handle hCanSeeTimer;
    Handle hCanSeeAllTimer;
    Handle hAllCanSeeTimer;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

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
    CreateNative("TTT_GetClientSkinLight", Native_GetClientSkin);
    CreateNative("TTT_SetGlowColorLight", Native_SetGlowColor);
    CreateNative("TTT_SetGlowTeamLight", Native_SetGlowTeam);
    CreateNative("TTT_CanSeeGlowLight", Native_CanSeeGlow);
    CreateNative("TTT_CanSeeClientsGlowLight", Native_CanSeeClientsGlow);
    CreateNative("TTT_CanSeeAllGlowLight", Native_CanSeeAllGlow);
    CreateNative("TTT_AllCanSeeGlowLight", Native_AllCanSeeGlow);
    
    RegPluginLibrary("ttt_glow_light");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    
    TTT_StartConfig("glow_light");
    CreateConVar("ttt2_glow_light_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cGlowMaterial = AutoExecConfig_CreateConVar("glow_light_material", "materials/sprites/ttt/frame.vmt", "Glow material sprite.");
    g_cGlowScale = AutoExecConfig_CreateConVar("glow_light_scale", "0.5", "Scale of client sprite", _, true, 0.0, true, 1.0);
    g_cGlowDetective = AutoExecConfig_CreateConVar("glow_light_detective_enable", "1", "Detectives see the glows of other detectives. 0 to disable.", _, true, 0.0, true, 1.0);
    g_cGlowTraitor = AutoExecConfig_CreateConVar("glow_light_traitor_enable", "1", "Traitors see the glows of other traitors. 0 to disable.", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    RemoveAllGlow();
}

public void OnLibraryAdded(const char[] library)
{
    if (StrEqual(library, "ttt_glow", false))
    {
        SetFailState("If you want to use ttt_glow_light you must delete ttt_glow!");
        ServerCommand("sm plugins unload ttt_glow_light");
    }
}

public void OnMapStart()
{
    char sBuffer[PLATFORM_MAX_PATH];
    g_cGlowMaterial.GetString(sBuffer, sizeof(sBuffer));

    // Add .vmt file
    AddFileToDownloadsTable(sBuffer);

    // Add .vtf file
    ReplaceString(sBuffer, sizeof(sBuffer), ".vmt", ".vtf");
    AddFileToDownloadsTable(sBuffer);

    // Precache sprite
    PrecacheDecal(sBuffer, true);
}

public void OnClientDisconnect(int client)
{
    RemoveGlow(client);
}

public void TTT_OnClientGetRole(int client, int role)
{
    ResetClientGlow(client);
    RemoveGlow(client);
    CreateGlow(client);
}

public Action TTT_OnPlayerDeath(int victim, int attacker)
{
    RemoveGlow(victim);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    RemoveAllGlow();
}

stock void CreateGlow(int client)
{
    CreateTimer(0.15, Timer_CreateGlow, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CreateGlow(Handle timer, any client)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }

    if (!(client = GetClientOfUserId(client)) || !TTT_IsClientValid(client) || IsValidEntity(EntRefToEntIndex(g_iPlayer[client].iSkinRef)) || !IsPlayerAlive(client))
    {
        return;
    }

    int iEnt;

    if ((iEnt = CreateEntityByName("env_sprite")) == -1)
    {
        PrintToServer("Can't create entity 'env_sprite'!");
        return;
    }

    float fPos[3];
    GetClientAbsOrigin(client, fPos);

    fPos[2] += 35;

    char sBuffer[PLATFORM_MAX_PATH];
    g_cGlowMaterial.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "materials/", "");

    DispatchKeyValueVector(iEnt, "origin", fPos);
    DispatchKeyValue(iEnt, "model", sBuffer);
    DispatchKeyValue(iEnt, "classname", "ttt_glow_light");
    DispatchKeyValue(iEnt, "spawnflags", "1");
    DispatchKeyValueFloat(iEnt, "scale", g_cGlowScale.FloatValue);
    DispatchKeyValue(iEnt, "rendermode", "5");

    if (!DispatchSpawn(iEnt))
    {
        PrintToServer("Can't spawn entity 'env_sprite' (%i)!", iEnt);
        return;
    }

    SetVariantString("!activator");
    AcceptEntityInput(iEnt, "SetParent", client, iEnt);

    g_iPlayer[client].iSkinRef = EntIndexToEntRef(iEnt);
    g_iSkinClient[iEnt] = client;

    switch (TTT_GetClientRole(client))
    {
        case TTT_TEAM_INNOCENT: { UpdateGlow(iEnt, TTT_INNOCENT_COLOR); }
        case TTT_TEAM_TRAITOR: { UpdateGlow(iEnt, TTT_TRAITOR_COLOR); }
        case TTT_TEAM_DETECTIVE: { UpdateGlow(iEnt, TTT_DETECTIVE_COLOR); }
    }

    SDKHook(iEnt, SDKHook_SetTransmit, Hook_TransmitGlow);
}

public Action Hook_TransmitGlow(int skin, int client)
{
    int target = g_iSkinClient[skin];

    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    int iRole = TTT_GetClientRole(client);
    int iTargetRole = TTT_GetClientRole(target);

    if (g_cGlowDetective.BoolValue && iRole == TTT_TEAM_DETECTIVE && iRole == iTargetRole)
    {
        return Plugin_Continue;
    }

    if (g_cGlowTraitor.BoolValue && iRole == TTT_TEAM_TRAITOR && iRole == iTargetRole)
    {
        return Plugin_Continue;
    }

    if (g_iPlayer[client].bCanSee[target] || g_iPlayer[target].bAllCanSee || g_iPlayer[client].bCanSeeAll)
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}

stock void UpdateGlow(int skin, int color)
{
    SetVariantInt(((color & 0xFF0000) >> 16));
    AcceptEntityInput(skin, "ColorRedValue");
    SetVariantInt(((color & 0xFF00) >> 8));
    AcceptEntityInput(skin, "ColorGreenValue");
    SetVariantInt((color & 0xFF));
    AcceptEntityInput(skin, "ColorBlueValue");
}

stock void RemoveGlow(int client)
{
    int iEntity = EntRefToEntIndex(g_iPlayer[client].iSkinRef);

    if (iEntity > 0 && IsValidEntity(iEntity))
    {
        SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_TransmitGlow);
        AcceptEntityInput(iEntity, "Kill");
    }

    g_iPlayer[client].iSkinRef = -1;
}

stock void RemoveAllGlow()
{
    LoopValidClients(i)
    {
        RemoveGlow(i);
        ResetClientGlow(i);
    }
}

stock void ResetClientGlow(int client)
{
    g_iPlayer[client].bCanSeeAll = false;
    g_iPlayer[client].bAllCanSee = false;

    TTT_ClearTimer(g_iPlayer[client].hColorReset);
    TTT_ClearTimer(g_iPlayer[client].hCanSeeTimer);
    TTT_ClearTimer(g_iPlayer[client].hCanSeeAllTimer);
    TTT_ClearTimer(g_iPlayer[client].hAllCanSeeTimer);

    LoopValidClients(i)
    {
        g_iPlayer[client].bCanSee[i] = false;
    }
}

// ** NATIVES ** //
int Native_GetClientSkin(Handle plugin, int numParams)
{
    return EntRefToEntIndex(g_iPlayer[GetNativeCell(1)].iSkinRef);
}

int Native_SetGlowColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = view_as<float>(GetNativeCell(3));

    int iSkin = EntRefToEntIndex(g_iPlayer[client].iSkinRef);

    if (iSkin > MaxClients)
    {
        int color[3];
        GetNativeArray(2, color, sizeof(color));

        int iRenderColor;
        iRenderColor |= ((color[0] & 0xFF) << 16);
        iRenderColor |= ((color[1] & 0xFF) << 8);
        iRenderColor |= ((color[2] & 0xFF) << 0);

        UpdateGlow(iSkin, iRenderColor);
    }

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hColorReset != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hColorReset);
        }

        g_iPlayer[client].hColorReset = CreateTimer(duration, Timer_ResetGlowColor, GetClientUserId(client));
    }
}

int Native_SetGlowTeam(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = view_as<float>(GetNativeCell(3));

    int iSkin = EntRefToEntIndex(g_iPlayer[client].iSkinRef);

    if (iSkin > MaxClients)
    {
        switch (GetNativeCell(2))
        {
            case TTT_TEAM_INNOCENT: { UpdateGlow(iSkin, TTT_INNOCENT_COLOR); }
            case TTT_TEAM_TRAITOR: { UpdateGlow(iSkin, TTT_TRAITOR_COLOR); }
            case TTT_TEAM_DETECTIVE: { UpdateGlow(iSkin, TTT_DETECTIVE_COLOR); }
        }
    }

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hColorReset != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hColorReset);
        }

        g_iPlayer[client].hColorReset = CreateTimer(duration, Timer_ResetGlowColor, GetClientUserId(client));
    }
}

int Native_CanSeeGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int target = GetNativeCell(2);
    float duration = view_as<float>(GetNativeCell(3));

    g_iPlayer[client].bCanSee[target] = true;

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hCanSeeTimer != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hCanSeeTimer);
        }

        DataPack data;
        g_iPlayer[client].hCanSeeTimer = CreateDataTimer(duration, Timer_ResetCanSeeGlow, data);

        data.WriteCell(GetClientUserId(client));
        data.WriteCell(GetClientUserId(target));
    }
}

int Native_CanSeeClientsGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int targets[MAXPLAYERS + 1]; GetNativeArray(2, targets, sizeof(targets));
    int target_count = GetNativeCell(3);
    float duration = view_as<float>(GetNativeCell(4));

    for (int i = 0; i < target_count; ++i)
    {
        g_iPlayer[client].bCanSee[targets[i]] = true;
    }

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hCanSeeTimer != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hCanSeeTimer);
        }

        DataPack data;
        g_iPlayer[client].hCanSeeTimer = CreateDataTimer(duration, Timer_ResetCanSeeClientsGlow, data);

        data.WriteCell(GetClientUserId(client));
        data.WriteCell(target_count);

        for (int i = 0; i < target_count; ++i)
        {
            data.WriteCell(GetClientUserId(targets[i]));
        }
    }
}

int Native_CanSeeAllGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = view_as<float>(GetNativeCell(2));

    g_iPlayer[client].bCanSeeAll = true;

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hCanSeeAllTimer != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hCanSeeAllTimer);
        }

        g_iPlayer[client].hCanSeeAllTimer = CreateTimer(duration, Timer_ResetCanSeeAll, GetClientUserId(client));
    }
}

int Native_AllCanSeeGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = view_as<float>(GetNativeCell(2));

    g_iPlayer[client].bAllCanSee = true; 

    if (duration > 0.0)
    {
        if (g_iPlayer[client].hAllCanSeeTimer != null)
        {
            TTT_ClearTimer(g_iPlayer[client].hAllCanSeeTimer);
        }

        g_iPlayer[client].hAllCanSeeTimer = CreateTimer(duration, Timer_ResetAllCanSee, GetClientUserId(client));
    }
}

// ** TIMERS ** //
Action Timer_ResetGlowColor(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    g_iPlayer[client].hColorReset = null;

    if (client > 0 && IsPlayerAlive(client))
    {
        int iSkin = EntRefToEntIndex(g_iPlayer[client].iSkinRef);

        if (iSkin > MaxClients)
        {
            switch (TTT_GetClientRole(client))
            {
                case TTT_TEAM_INNOCENT: { UpdateGlow(iSkin, TTT_INNOCENT_COLOR); }
                case TTT_TEAM_TRAITOR: { UpdateGlow(iSkin, TTT_TRAITOR_COLOR); }
                case TTT_TEAM_DETECTIVE: { UpdateGlow(iSkin, TTT_DETECTIVE_COLOR); }
            }
        }
    }
}

Action Timer_ResetCanSeeGlow(Handle timer, DataPack data)
{
    data.Reset();

    int client = GetClientOfUserId(data.ReadCell());
    int target = GetClientOfUserId(data.ReadCell());

    g_iPlayer[client].hCanSeeTimer = null;

    if (TTT_IsClientValid(client) && target && IsPlayerAlive(client))
    {
        g_iPlayer[client].bCanSee[target] = false;
    }
}

Action Timer_ResetCanSeeClientsGlow(Handle timer, DataPack data)
{
    data.Reset();

    int client = GetClientOfUserId(data.ReadCell());
    int target_count = data.ReadCell();

    g_iPlayer[client].hCanSeeTimer = null;

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        for (int i = 0; i < target_count; ++i)
        {
            g_iPlayer[client].bCanSee[GetClientOfUserId(data.ReadCell())] = false;
        }
    }
}

Action Timer_ResetCanSeeAll(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    g_iPlayer[client].hCanSeeAllTimer = null;

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iPlayer[client].bCanSeeAll = false;
    }
}

Action Timer_ResetAllCanSee(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    g_iPlayer[client].hAllCanSeeTimer = null;

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iPlayer[client].bAllCanSee = false;
    }
}
