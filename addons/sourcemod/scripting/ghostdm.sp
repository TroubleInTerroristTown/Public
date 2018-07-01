#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>
#include <multicolors>

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

#include "ghostdm/globals.sp"
#include "ghostdm/stocks.sp"
#include "ghostdm/redie.sp"

public Plugin myinfo =
{
    name = "Ghost Deathmatch with Redie",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara/TroubleinTerroristTown"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("GhostDM_IsClientInRedie", Native_IsClientInRedie);
    
    RegPluginLibrary("ghostdm");
    
    return APLRes_Success;
}

public int Native_IsClientInRedie(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_bRedie[client];
}

public void OnPluginStart()
{
    RegAdminCmd("sm_redie", Command_redie, ADMFLAG_CUSTOM4);
    RegAdminCmd("sm_reback", Command_reback, ADMFLAG_CUSTOM4);
    
    HookEvent("round_start", RoundStart);
    HookEvent("round_end", RoundEnd);
    HookEvent("player_death", PlayerDeath);
    HookEvent("player_team", PlayerTeam, EventHookMode_Pre);
    HookEvent("player_spawn", PlayerSpawn, EventHookMode_Pre);

    g_cPluginTag = AutoExecConfig_CreateConVar("ghostdm_plugin_tag", "{darkred}[Redie] {default}", "Plugin tag for every message from this plugin");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    
    Redie_OnPluginStart();
}

public void OnConfigsExecuted()
{
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnClientPutInServer(int client)
{
    if (IsClientValid(client))
    {
        Redie_OnClientPutInServer(client);
    }
}

public void OnClientDisconnect(int client)
{
    ResetRedie(client);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    Redie_OnRoundStart();
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    Redie_OnRoundEnd();
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if(IsClientValid(client))
    {
        Redie_OnPlayerDeath(client);
    }
}

public Action PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    event.BroadcastDisabled = true;
    return Plugin_Changed;
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if(IsClientValid(client))
    {
        Redie_OnPlayerSpawn(client);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    Redie_OnPlayerRunCmd(client, buttons);
}
