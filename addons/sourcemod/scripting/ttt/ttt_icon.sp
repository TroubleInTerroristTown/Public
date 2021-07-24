#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Icons"

ConVar g_cAdminImmunity = null;
ConVar g_cSeeRoles = null;
ConVar g_cTraitorIcon = null;
ConVar g_cDetectiveIcon = null;
ConVar g_cScale = null;

GlobalForward g_fwOnPrecache = null;
GlobalForward g_fwOnIconCreate = null;

enum struct PlayerData {
    int Icon;
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
    CreateNative("TTT_SetIcon", Native_SetIcon);

    g_fwOnPrecache = new GlobalForward("Icon_OnPrecache", ET_Event, Param_String, Param_Cell);
    g_fwOnIconCreate = new GlobalForward("Icon_OnIconCreate", ET_Event, Param_Cell, Param_String, Param_Cell, Param_CellByRef);

    RegPluginLibrary("ttt_icon");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();
    
    TTT_StartConfig("icon");
    CreateConVar("ttt2_icon_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cSeeRoles = AutoExecConfig_CreateConVar("ttt_dead_players_can_see_other_teams", "0", "Allow dead players to see other teams. 0 = Disabled (default). 1 = Enabled.", _, true, 0.0, true, 1.0);
    g_cTraitorIcon = AutoExecConfig_CreateConVar("ttt_icon_traitor_icon", "decals/ttt/traitor_iconNew", "Path to traitor icon file");
    g_cDetectiveIcon = AutoExecConfig_CreateConVar("ttt_icon_detective_icon", "decals/ttt/detective_iconNew", "Path to detective icon file");
    g_cAdminImmunity = AutoExecConfig_CreateConVar("ttt_icon_dead_admin", "b", "Show traitor icon for dead admins? (Nothing to disable it)");
    g_cScale = AutoExecConfig_CreateConVar("ttt_icon_scale", "0.08", "The scale to scale the sprite to");
    TTT_EndConfig();
    
    HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeamPre, EventHookMode_Pre);

    CreateTimer(2.0, Timer_CreateIcon, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
    LoopValidClients(i)
    {
        ClearIcon(i);
    }
}

public void OnMapStart()
{
    char sFile[PLATFORM_MAX_PATH];
    
    g_cTraitorIcon.GetString(sFile, sizeof(sFile));
    Format(sFile, sizeof(sFile), "materials/%s.vtf", sFile);
    AddFileToDownloadsTable(sFile);

    g_cTraitorIcon.GetString(sFile, sizeof(sFile));
    Format(sFile, sizeof(sFile), "materials/%s.vmt", sFile);
    AddFileToDownloadsTable(sFile);
    PrecacheModel(sFile);



    g_cDetectiveIcon.GetString(sFile, sizeof(sFile));
    Format(sFile, sizeof(sFile), "materials/%s.vtf", sFile);
    AddFileToDownloadsTable(sFile);

    g_cDetectiveIcon.GetString(sFile, sizeof(sFile));
    Format(sFile, sizeof(sFile), "materials/%s.vmt", sFile);
    AddFileToDownloadsTable(sFile);
    PrecacheModel(sFile);

    char sBuffer[PLATFORM_MAX_PATH];
    Action res = Plugin_Handled;

    Call_StartForward(g_fwOnPrecache);
    Call_PushStringEx(sBuffer, sizeof(sBuffer), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sBuffer));
    Call_Finish(res);

    if (strlen(sBuffer) > 3 && (res == Plugin_Continue || res == Plugin_Changed))
    {
        Format(sFile, sizeof(sFile), "materials/%s.vtf", sBuffer);
        AddFileToDownloadsTable(sFile);

        Format(sFile, sizeof(sFile), "materials/%s.vmt", sBuffer);
        AddFileToDownloadsTable(sFile);
        PrecacheModel(sFile);
    }
}

public void OnClientDisconnect(int client)
{
    ClearIcon(client);
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
    LoopValidClients(client)
    {
        ClearIcon(client);
    }
}

public Action Timer_CreateIcon(Handle timer)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    LoopValidClients(client)
    {
        if (IsPlayerAlive(client))
        {
            g_iPlayer[client].Icon = CreateIcon(client, TTT_GetClientTeam(client));
        }
    }

    return Plugin_Continue;
}

public void TTT_OnRoundStart()
{
    ApplyIcons();
}

public void TTT_OnClientGetRole(int client, int team, int role)
{
    g_iPlayer[client].Icon = CreateIcon(client, team);
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    ClearIcon(client);
}

public Action Event_PlayerTeamPre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(event.GetInt("team") == CS_TEAM_SPECTATOR)
    {
        ClearIcon(client);
    }

    return Plugin_Continue;
}

void ApplyIcons()
{
    LoopValidClients(i)
    {
        if (IsPlayerAlive(i))
        {
            g_iPlayer[i].Icon = CreateIcon(i, TTT_GetClientTeam(i));
        }
    }
}

int CreateIcon(int client, int team)
{
    ClearIcon(client);

    if (team < TTT_TEAM_TRAITOR)
    {
        return -1;
    }

    char iTarget[16];
    Format(iTarget, 16, "client%d", client);
    DispatchKeyValue(client, "targetname", iTarget);

    float origin[3];

    GetClientAbsOrigin(client, origin);
    origin[2] = origin[2] + 80.0;

    int ent = CreateEntityByName("env_sprite");
    if (!ent)
    {
        return -1;
    }

    char sBuffer[PLATFORM_MAX_PATH];
    char sScale[PLATFORM_MAX_PATH];

    if (team == TTT_TEAM_DETECTIVE)
    {
        g_cDetectiveIcon.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "%s.vmt", sBuffer);
    }
    else if (team == TTT_TEAM_TRAITOR)
    {
        g_cTraitorIcon.GetString(sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "%s.vmt", sBuffer);
    }

    char sFile[PLATFORM_MAX_PATH];
    Action res = Plugin_Continue;
    bool bAsTraitor = false;

    if (team == TTT_TEAM_TRAITOR)
    {
        bAsTraitor = true;
    }

    Call_StartForward(g_fwOnIconCreate);
    Call_PushCell(client);
    Call_PushStringEx(sFile, sizeof(sFile), SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(sizeof(sFile));
    Call_PushCellRef(view_as<int>(bAsTraitor));
    Call_Finish(res);

    if (res == Plugin_Changed)
    {
        Format(sBuffer, sizeof(sBuffer), "%s.vmt", sFile);
    }
    g_cScale.GetString(sScale, sizeof(sScale));

    DispatchKeyValue(ent, "model", sBuffer);
    DispatchKeyValue(ent, "classname", "env_sprite");
    DispatchKeyValue(ent, "spawnflags", "1");
    DispatchKeyValue(ent, "scale", sScale);
    DispatchKeyValue(ent, "rendermode", "1");
    DispatchKeyValue(ent, "rendercolor", "255 255 255");
    TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
    DispatchSpawn(ent);
    SetVariantString(iTarget);
    AcceptEntityInput(ent, "SetParent", ent, ent);

    if (team == TTT_TEAM_TRAITOR && bAsTraitor)
    {
        SDKHook(ent, SDKHook_SetTransmit, Hook_SetTransmitT);
    }
    return EntIndexToEntRef(ent);
}

public Action Hook_SetTransmitT(int entity, int client)
{
    if (TTT_IsClientValid(client))
    {
        if (!IsPlayerAlive(client))
        {
            if (g_cSeeRoles.BoolValue)
            {
                return Plugin_Continue;
            }
            else
            {
                if (TTT_CheckCommandAccess(client, "icon_immunity", g_cAdminImmunity, true))
                {
                    return Plugin_Continue;
                }
            }
        }

        if (IsPlayerAlive(client) && TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
        {
            return Plugin_Continue;
        }
    }
    return Plugin_Handled;
}

void ClearIcon(int client)
{
    if (g_iPlayer[client].Icon == 0)
    {
        g_iPlayer[client].Icon = -1;
    }

    int iTeam = TTT_GetClientTeam(client);
    int entity = EntRefToEntIndex(g_iPlayer[client].Icon);

    if (IsValidEdict(entity))
    {
        if (iTeam == TTT_TEAM_TRAITOR)
        {
            SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmitT);
        }
        AcceptEntityInput(entity, "Kill");
    }

    g_iPlayer[client].Icon = -1;

}

public int Native_SetIcon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int team = GetNativeCell(2);

    g_iPlayer[client].Icon = CreateIcon(client, team);

    return 0;
}
