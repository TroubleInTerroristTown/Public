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
#include "ghostdm/config.sp"
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
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

    Config_OnPluginStart();

    g_cPluginTag = AutoExecConfig_CreateConVar("ghostdm_plugin_tag", "{darkred}[Redie] {default}", "Plugin tag for every message from this plugin");
    g_cPluginTag.AddChangeHook(CVar_OnConVarChanged);
    
    Redie_OnPluginStart();
}

public void OnConfigsExecuted()
{
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void CVar_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
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
