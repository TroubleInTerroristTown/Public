#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <ttt>

int g_iColorInnocent[4] =  {0, 255, 0};
int g_iColorTraitor[4] =  {255, 0, 0};
int g_iColorDetective[4] =  {0, 0, 255};

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Glow"

ConVar g_cDGlow = null;
ConVar g_cTGlow = null;

int g_iSkinClient[2048] = { -1 , ... };

enum struct PlayerData
{
    int SkinRef;

    bool CanSee[MAXPLAYERS + 1];
    bool CanSeeAll;
    bool AllCanSee;

    Handle CanSeeTimer[MAXPLAYERS + 1];
    Handle CanSeeAllTimer;
    Handle AllCanSeeTimer;
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
    CreateNative("TTT_GetClientSkin", Native_GetClientSkin);
    CreateNative("TTT_SetGlowColor", Native_SetGlowColor);
    CreateNative("TTT_SetGlowTeam", Native_SetGlowTeam);
    CreateNative("TTT_CanSeeGlow", Native_CanSeeGlow);
    CreateNative("TTT_CanSeeClientsGlow", Native_CanSeeClientsGlow);
    CreateNative("TTT_CanSeeAllGlow", Native_CanSeeAllGlow);
    CreateNative("TTT_AllCanSeeGlow", Native_AllCanSeeGlow);
    
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
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnPluginEnd()
{
    DeleteAndClearAll();
}

public void OnConfigsExecuted()
{
    ConVar cvar = FindConVar("sv_force_transmit_players");
    cvar.SetBool(true, true, false);
}

public void TTT_OnClientGetRole(int client, int role)
{
    DeleteAndClearAllClient(client);
    CreateGlowProp(client);
}

public Action TTT_OnPlayerDeath(int victim, int attacker)
{
    DeleteAndClearAllClient(victim);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    DeleteAndClearAll();
}

int Native_GetClientSkin(Handle plugin, int numParams)
{
    return EntRefToEntIndex(g_iPlayer[GetNativeCell(1)].SkinRef);
}

int Native_SetGlowColor(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = GetNativeCell(3);

    int skin = EntRefToEntIndex(g_iPlayer[client].SkinRef);
    if (skin > MaxClients)
    {
        int color[4];
        GetNativeArray(2, color, sizeof(color));
        UpdateGlowColor(skin, color);
    }

    if (duration > 0.0)
    {
        CreateTimer(duration, Timer_ResetGlowColor, GetClientUserId(client));
    }
}

int Native_SetGlowTeam(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = GetNativeCell(3);

    int skin = EntRefToEntIndex(g_iPlayer[client].SkinRef);
    if (skin > MaxClients)
    {
        UpdateGlowTeam(skin, GetNativeCell(2));
    }

    if (duration > 0.0)
    {
        CreateTimer(duration, Timer_ResetGlowColor, GetClientUserId(client));
    }
}

int Native_CanSeeGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int target = GetNativeCell(2);
    float duration = GetNativeCell(3);

    g_iPlayer[client].CanSee[target] = true;

    if (duration > 0.0)
    {
        DataPack data;
        CreateDataTimer(duration, Timer_ResetCanSeeGlow, data);
        data.WriteCell(GetClientUserId(client));
        data.WriteCell(GetClientUserId(target));
    }
}

int Native_CanSeeClientsGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int targets[MAXPLAYERS + 1]; GetNativeArray(2, targets, sizeof(targets));
    int target_count = GetNativeCell(3);
    float duration = GetNativeCell(4);

    for (int i = 0; i < target_count; ++i)
    {
        g_iPlayer[client].CanSee[targets[i]] = true;
    }

    if (duration > 0.0)
    {
        DataPack data;
        CreateDataTimer(duration, Timer_ResetCanSeeClientsGlow, data);
        data.WriteCell(GetClientUserId(client));
        data.WriteCell(target_count);

        for (int i = 0; i < target_count; ++i)
        {
            data.WriteCell(GetClientUserId(targets[i]));
        }

        data.Reset();
    }
}

int Native_CanSeeAllGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = GetNativeCell(2);

    g_iPlayer[client].CanSeeAll = true;

    if (duration > 0.0)
    {
        CreateTimer(duration, Timer_ResetCanSeeAll, GetClientUserId(client));
    }
}

int Native_AllCanSeeGlow(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float duration = GetNativeCell(2);

    g_iPlayer[client].AllCanSee = true;

    if (duration > 0.0)
    {
        CreateTimer(duration, Timer_ResetAllCanSee, GetClientUserId(client));
    }
}

void CreateGlowProp(int client)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    int iRole = TTT_GetClientRole(client);

    SetupSee(client, iRole);

    int skin = CreatePlayerModelProp(client);
    if (skin > MaxClients)
    {
        if (SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_All))
        {
            SetGlowTeam(skin, iRole);
        }
    }
}

public Action OnSetTransmit_All(int skin, int client)
{
    int target = g_iSkinClient[skin];

    if (target == -1)
    {
        return Plugin_Handled;
    }

    int iRole = TTT_GetClientRole(client);
    int iTargetRole = TTT_GetClientRole(target);

    if (iRole == TTT_TEAM_DETECTIVE && iRole == iTargetRole && g_cDGlow.BoolValue)
    {
        return Plugin_Continue;
    }

    if (iRole == TTT_TEAM_TRAITOR && iRole == iTargetRole && g_cTGlow.BoolValue)
    {
        return Plugin_Continue;
    }
        
    if (g_iPlayer[client].CanSee[target] || g_iPlayer[target].AllCanSee || g_iPlayer[client].CanSeeAll)
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}

void SetGlowTeam(int skin, int role)
{
    if (role == TTT_TEAM_DETECTIVE)
    {
        SetupGlow(skin, g_iColorDetective);
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        SetupGlow(skin, g_iColorTraitor);
    }
    else if (role == TTT_TEAM_INNOCENT)
    {
        SetupGlow(skin, g_iColorInnocent);
    }
}

void UpdateGlowTeam(int skin, int role)
{
    if (role == TTT_TEAM_DETECTIVE)
    {
        UpdateGlowColor(skin, g_iColorDetective);
    }
    else if (role == TTT_TEAM_TRAITOR)
    {
        UpdateGlowColor(skin, g_iColorTraitor);
    }
    else if (role == TTT_TEAM_INNOCENT)
    {
        UpdateGlowColor(skin, g_iColorInnocent);
    }
}

void SetupGlow(int skin, int color[4])
{
    int offset;

    if (!offset && (offset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
    {
        LogError("Unable to find property offset: \"m_clrGlow\"!");
        return;
    }

    SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(skin, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);

    for (int i = 0; i < 3; i++)
    {
        SetEntData(skin, offset + i, color[i], _, true); 
    }
}

void UpdateGlowColor(int skin, int color[4])
{
    static int offset = -1;
    if (offset == -1 && (offset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
    {
        LogError("Unable to find property offset: \"m_clrGlow\"!");
        return;
    }

    for (int i = 0; i < 3; i++)
    {
        SetEntData(skin, offset + i, color[i], _, true); 
    }
}

int CreatePlayerModelProp(int client)
{
    DeleteGlowProp(client);

    int skin = CreateEntityByName("prop_dynamic_override");

    char sModel[PLATFORM_MAX_PATH];
    GetClientModel(client, sModel, sizeof(sModel));
    DispatchKeyValue(skin, "model", sModel);

    DispatchKeyValue(skin, "disablereceiveshadows", "1");
    DispatchKeyValue(skin, "disableshadows", "1");
    DispatchKeyValue(skin, "solid", "0");
    DispatchKeyValue(skin, "spawnflags", "256");

    SetEntProp(skin, Prop_Send, "m_CollisionGroup", 0);

    if (DispatchSpawn(skin))
    {
        SetEntityRenderMode(skin, RENDER_TRANSALPHA);
        SetEntityRenderColor(skin, 0, 0, 0, 0);

        SetEntProp(skin, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW);

        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(EntIndexToEntRef(skin));
        RequestFrame(Frame_SetParent, pack);

        g_iPlayer[client].SkinRef = EntIndexToEntRef(skin);
        g_iSkinClient[skin] = client;

        return skin;
    }

    return -1;
}

public void Frame_SetParent(DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());
    int skin = EntRefToEntIndex(pack.ReadCell());

    delete pack;

    if (TTT_IsClientValid(client) && IsValidEntity(skin))
    {
        SetVariantString("!activator");
        AcceptEntityInput(skin, "SetParent", client, skin);
        SetVariantString("primary");
        AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0);
    }
}

Action Timer_ResetGlowColor(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsPlayerAlive(client))
    {
        int skin = EntRefToEntIndex(g_iPlayer[client].SkinRef);
        UpdateGlowTeam(skin, TTT_GetClientRole(client));
    }
}

Action Timer_ResetCanSeeGlow(Handle timer, DataPack data)
{
    data.Reset();

    int client = GetClientOfUserId(data.ReadCell());
    int target = GetClientOfUserId(data.ReadCell());

    if (TTT_IsClientValid(client) && target && IsPlayerAlive(client))
    {
        g_iPlayer[client].CanSee[target] = false;
    }
}

Action Timer_ResetCanSeeClientsGlow(Handle timer, DataPack data)
{
    data.Reset();
    
    int client = GetClientOfUserId(data.ReadCell());
    int target_count = data.ReadCell();

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        for (int i = 0; i < target_count; ++i)
        {
            g_iPlayer[client].CanSee[GetClientOfUserId(data.ReadCell())] = false;
        }
    }

    delete data;
}

Action Timer_ResetCanSeeAll(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iPlayer[client].CanSeeAll = false;
    }
}

Action Timer_ResetAllCanSee(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iPlayer[client].AllCanSee = false;
    }
}

void DeleteAndClearAll()
{
    LoopValidClients(i)
    {
        DeleteAndClearAllClient(i);
    }
}

void DeleteAndClearAllClient(int client)
{
    DeleteGlowProp(client);

    g_iPlayer[client].CanSeeAll = false;
    g_iPlayer[client].AllCanSee = false;

    TTT_ClearTimer(g_iPlayer[client].CanSeeAllTimer);
    TTT_ClearTimer(g_iPlayer[client].AllCanSeeTimer);

    LoopValidClients(i)
    {
        g_iPlayer[client].CanSee[i] = false;
        TTT_ClearTimer(g_iPlayer[client].CanSeeTimer[i]);
    }
}

void DeleteGlowProp(int client)
{
    int iEntity = EntRefToEntIndex(g_iPlayer[client].SkinRef);

    if (iEntity > 0 && IsValidEntity(iEntity))
    {
        SDKUnhook(iEntity, SDKHook_SetTransmit, OnSetTransmit_All);
        AcceptEntityInput(iEntity, "Kill");
    }

    g_iPlayer[client].SkinRef = -1;
    g_iSkinClient[client] = -1;
}

void SetupSee(int client, int role)
{
    int iRole;

    LoopValidClients(i)
    {
        iRole = TTT_GetClientRole(i);

        if (iRole & (TTT_TEAM_TRAITOR | TTT_TEAM_DETECTIVE) && iRole == role)
        {
            g_iPlayer[i].CanSee[client] = true;
        }
    }
}
