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

int g_iSkinRef[MAXPLAYERS + 1] = { -1 , ... };
int g_iSkinClient[2048] = { -1 , ... };

GlobalForward g_fwOnGlowCheck = null;

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
    g_fwOnGlowCheck = new GlobalForward("TTT_OnGlowCheck", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
    
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
    DeleteAllGlowProps();
}

public void OnConfigsExecuted()
{
    ConVar cvar = FindConVar("sv_force_transmit_players");
    cvar.SetBool(true, true, false);
}

public void TTT_OnClientGetRole(int client, int role)
{
    DeleteGlowProp(client);
    CreateGlowProp(client);
}

public Action TTT_OnPlayerDeath(int victim, int attacker)
{
    DeleteGlowProp(victim);
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    DeleteAllGlowProps();
}

void CreateGlowProp(int client)
{
    if(!IsPlayerAlive(client))
    {
        return;
    }
    
    int iRole = TTT_GetClientRole(client);
    if(iRole <= 1)
    {
        return;
    }
    
    if (!g_cDGlow.BoolValue && iRole == TTT_TEAM_DETECTIVE)
    {
        return;
    }
    
    if (!g_cTGlow.BoolValue && iRole == TTT_TEAM_TRAITOR)
    {
        return;
    }

    int skin = CreatePlayerModelProp(client);
    if(skin > MaxClients)
    {
        if(SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_All))
        {
            setGlowTeam(skin, iRole);
        }
    }
}

public Action OnSetTransmit_All(int skin, int client)
{
    int iClientRole = TTT_GetClientRole(client);

    int target = g_iSkinClient[skin];
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    int iTargetRole = TTT_GetClientRole(target);
        
    if (iClientRole == TTT_TEAM_DETECTIVE && iClientRole == iTargetRole)
    {
        return Plugin_Continue;
    }

    if (iClientRole == TTT_TEAM_TRAITOR && iClientRole == iTargetRole)
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
    
    Call_StartForward(g_fwOnGlowCheck);
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
    
    if (seeTarget)
    {
        return Plugin_Continue;
    }
    
    return Plugin_Handled;
}

void setGlowTeam(int skin, int role)
{
    if(role >= 2)
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
}

void SetupGlow(int skin, int color[4])
{
    int offset;
    // Get sendprop offset for prop_dynamic_override
    if (!offset && (offset = GetEntSendPropOffs(skin, "m_clrGlow")) == -1)
    {
        LogError("Unable to find property offset: \"m_clrGlow\"!");
        return;
    }

    // Enable glow for custom skin
    SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(skin, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);

    // So now setup given glow colors for the skin
    for(int i = 0; i < 3; i++)
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

        g_iSkinRef[client] = EntIndexToEntRef(skin);
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

void DeleteAllGlowProps()
{
    LoopValidClients(i)
    {
        DeleteGlowProp(i);
    }
}

void DeleteGlowProp(int client)
{
    int iEntity = EntRefToEntIndex(g_iSkinRef[client]);
    if(IsValidEntity(iEntity))
    {
        SDKUnhook(iEntity, SDKHook_SetTransmit, OnSetTransmit_All);
        AcceptEntityInput(iEntity, "Kill");
    }

    g_iSkinRef[client] = -1;
    g_iSkinClient[client] = -1;
}
