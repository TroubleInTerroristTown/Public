#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>
#include <multicolors>

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

ConVar g_cRedieTag = null;
ConVar g_cGhostDMTag = null;
char g_sRedieTag[64];
char g_sGhostDMTag[64];

#include "ghostdm/globals.sp"
#include "ghostdm/config.sp"
#include "ghostdm/stocks.sp"
#include "ghostdm/redie.sp"
#include "ghostdm/deathmatch.sp"

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
    CreateNative("GhostDM_IsClientInDM", Native_IsClientInDM);
    
    RegPluginLibrary("ghostdm");
    
    return APLRes_Success;
}

public int Native_IsClientInRedie(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_bRedie[client];
}

public int Native_IsClientInDM(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_bDM[client];
}

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

    Config_OnPluginStart();

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.ghostdm");
    g_cRedieTag = AutoExecConfig_CreateConVar("ghostdm_redie_tag", "{darkblue}[Redie] {default}", "Redie tag for every message from this plugin");
    g_cGhostDMTag = AutoExecConfig_CreateConVar("ghostdm_tag", "{darkred}[GhostDM] {default}", "GhostDM tag for every message from this plugin");
    g_cRedieTag.AddChangeHook(CVar_OnConVarChanged);
    g_cGhostDMTag.AddChangeHook(CVar_OnConVarChanged);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    Redie_OnPluginStart();
    GhostDM_OnPluginStart();
}

public void OnConfigsExecuted()
{
    g_cRedieTag.GetString(g_sRedieTag, sizeof(g_sRedieTag));
    g_cGhostDMTag.GetString(g_sGhostDMTag, sizeof(g_sGhostDMTag));
}

public void CVar_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cRedieTag)
    {
        g_cRedieTag.GetString(g_sRedieTag, sizeof(g_sRedieTag));
    }
    else if (convar == g_cGhostDMTag)
    {
        g_cGhostDMTag.GetString(g_sGhostDMTag, sizeof(g_sGhostDMTag));
    }
}

public void OnClientPutInServer(int client)
{
    if (IsClientValid(client))
    {
        ResetDM(client);
        ResetRedie(client);
        Redie_OnClientPutInServer(client);
    }
}

public void OnClientDisconnect(int client)
{
    ResetDM(client);
    ResetRedie(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    Redie_OnRoundStart();
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    Redie_OnRoundEnd();
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if(IsClientValid(client))
    {
        Redie_OnPlayerDeath(client);
    }
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    event.BroadcastDisabled = true;
    return Plugin_Changed;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
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

public Action OnNormalSoundPlayed(int[] clients, int &numClients, char[] sample, int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
    if(IsClientValid(entity))
    {
        if (Redie_OnNormalSoundPlayed(entity))
        {
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}
