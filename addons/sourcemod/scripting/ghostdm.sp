/*

    ToDo:
        - Only allow weapons (primary and secondary)

*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <autoexecconfig>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

#define HUD_RADAR ( 1<<12 )
#define HUD_ALL 2050

bool g_bRedie[MAXPLAYERS + 1 ] = { false, ... };
bool g_bDM[MAXPLAYERS + 1 ] = { false, ... };

int g_iNextPrimaryAttack = -1;
int g_iNextSecondaryAttack = -1;

Handle g_hRespawn[MAXPLAYERS + 1] = { null, ...};
Handle g_hSpawn[MAXPLAYERS + 1] = { null, ...};

int g_iHealth = -1;
float g_fRespawn = 0.0;
float g_fSpawnProt = 0.0;
bool g_bChest = false;
bool g_bHelm = false;
StringMap g_smPrimary = null;
StringMap g_smSecondary = null;
StringMap g_smWeaponLimits = null;

ConVar g_cEnable = null;
ConVar g_cListenerMode = null;

#include "ghostdm/config.sp"

public Plugin myinfo =
{
    name = "GhostDeathmatch with Redie",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara/TroubleinTerroristTown"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("GhostDM_IsClientInRedie", Native_IsClientInRedie);
    CreateNative("GhostDM_IsClientInDeathmatch", Native_IsClientInDeathmatch);

    RegPluginLibrary("ghostdm");
    
    return APLRes_Success;
}

public int Native_IsClientInRedie(Handle plugin, int numParams)
{
    return g_bRedie[GetNativeCell(1)];
}

public int Native_IsClientInDeathmatch(Handle plugin, int numParams)
{
    return g_bDM[GetNativeCell(1)];
}

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    g_cEnable = AutoExecConfig_CreateConVar("ghostdm_enable", "1", "Enable/Disable GhostDM", _, true, 0.0, true, 1.0);
    g_cListenerMode = AutoExecConfig_CreateConVar("ghostdm_listener_mode", "1", "Which mode? (0 - redie/ghostdm players can hear living players, 1 - redie/ghostdm players can't hear living players)", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    RegConsoleCmd("sm_redie", Command_Redie);
    RegConsoleCmd("sm_dm", Command_Deathmatch);

    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

    AddNormalSoundHook(view_as<NormalSHook>(OnNormalSHook));

    AddTempEntHook("Shotgun Shot", TE_OnShotgunShot);
    AddTempEntHook("EffectDispatch", TE_OnEffectDispatch);

    g_iNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
    g_iNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");

    Config_OnPluginStart();

    LoopClients(i)
    {
        OnClientPutInServer(i);
    }
}

public void OnClientPutInServer(int client)
{
    ResetClient(client);

    SDKHook(client, SDKHook_SetTransmit, OnSetTransmit);
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    SDKHook(client, SDKHook_WeaponCanUse, OnWeapon);
    SDKHook(client, SDKHook_WeaponEquip, OnWeapon);
    SDKHook(client, SDKHook_WeaponSwitch, OnWeapon);
}

public void OnClientDisconnect(int client)
{
    ResetClient(client);
}

public Action Command_Redie(int client, int args)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Handled;
    }

    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (IsPlayerAlive(client))
    {
        ReplyToCommand(client, "You must be dead!");
        return Plugin_Handled;
    }

    if (g_bRedie[client] && g_bDM[client])
    {
        ReplyToCommand(client, "You must leave deathmatch first! Type !dm");
        return Plugin_Handled;
    }

    g_bRedie[client] = !g_bRedie[client];

    PrintToChat(client, "Changed redie status to: %s", g_bRedie[client] ? "On" : "Off");
    CS_RespawnPlayer(client);

    if (g_bRedie[client])
    {
        SetRedie(client);
    }
    else
    {
        ResetClient(client);
    }

    return Plugin_Handled;
}

public Action Command_Deathmatch(int client, int args)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Handled;
    }

    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!g_bRedie[client])
    {
        ReplyToCommand(client, "You must be in redie to join deathmatch");
        return Plugin_Handled;
    }

    g_bDM[client] = !g_bDM[client];

    PrintToChat(client, "Changed deathmatch status to: %s", g_bDM[client] ? "On" : "Off");

    if (g_bDM[client])
    {
        SetRedie(client, true);
    }

    return Plugin_Handled;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    LoopClients(i)
    {
        ResetClient(i);
    }

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientValid(client))
    {
        if (!g_bRedie[client])
        {
            ResetClient(client);
        }
        else
        {
            SetRedie(client);
            
            if (g_bDM[client])
            {
                RequestFrame(Frame_GiveWeapons, event.GetInt("userid"));
            }
        }
    }

    return Plugin_Continue;
}

public void Frame_GiveWeapons(int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        // Code...
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientValid(victim) && g_bDM[victim])
    {
        if (g_hRespawn[victim] != null)
        {
            ClearTimer(g_hRespawn[victim]);
        }

        PrintToChat(victim, "You will be respawned in %.1f seconds!", g_fRespawn);
        g_hRespawn[victim] = CreateTimer(g_fRespawn, Timer_Respawn, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);

        Handle hPlugin = FindPluginByFile("ttt/ttt_hide_radar.smx");

        if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
        {
            SetEntProp(victim, Prop_Send, "m_iHideHUD", HUD_ALL);
        }
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsClientValid(attacker) && g_bDM[attacker])
    {
        char sWeapon[32];
        event.GetString("weapon", sWeapon, sizeof(sWeapon));

        Event eEvent = CreateEvent("player_death", true);

        if (eEvent != null)
        {
            eEvent.SetInt("userid", event.GetInt("userid"));
            eEvent.SetInt("attacker", event.GetInt("attacker"));
            eEvent.SetString("weapon", sWeapon);
            eEvent.SetBool("headshot", event.GetBool("headshot"));
            eEvent.SetInt("dominated", event.GetInt("dominated"));
            eEvent.SetInt("revenge", event.GetInt("revenge"));
            eEvent.SetInt("penetrated", event.GetInt("penetrated"));

            LoopClients(i)
            {
                if (g_bDM[i] == (g_bDM[attacker] && g_bDM[victim]))
                {
                    eEvent.FireToClient(i);
                }
            }

            eEvent.Cancel();
        }

        event.BroadcastDisabled = true;
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Timer_Respawn(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client) && g_hRespawn[client] != null)
    {
        if (g_bDM[client])
        {
            CS_RespawnPlayer(client);
        }

        g_hRespawn[client] = null;
    }

    return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(g_bRedie[client])
    {
        if (buttons & IN_ATTACK)
        {
            buttons &= ~IN_USE;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public Action OnNormalSHook(int[] clients, int &numClients, char[] sample, int &client, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }
    
    if (IsClientValid(client))
    {
        if (g_bRedie[client] && !g_bDM[client])
        {
            return Plugin_Stop;
        }

        int iTemp = numClients;
        numClients = 0;

        LoopClients(i)
        {
            if (g_bDM[client] == g_bDM[i])
            {
                clients[numClients] = i;
                numClients++;
            }
        }

        if (numClients == 0)
        {
            numClients = iTemp;
        }

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action TE_OnShotgunShot(const char[] te_name, const int[] clients, int numClients, float delay)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!StrEqual(te_name, "Shotgun Shot", false))
    {
        return Plugin_Continue;
    }

    int client = TE_ReadNum("m_iPlayer") + 1;

    if (!IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[client] && !g_bDM[client])
    {
        return Plugin_Stop;
    }

    int[] newClients = new int[MaxClients];
    int nClients = 0;
    
    LoopClients(i)
    {
        if (i == client)
        {
            continue;
        }

        if (g_bDM[client] == g_bDM[i])
        {
            newClients[nClients++] = i;
        }
    }
    
    if (nClients == numClients)
    {
        return Plugin_Continue;
    }
    
    if (nClients)
    {
        float fTemp[3];
        TE_Start("Shotgun Shot");
        TE_ReadVector("m_vecOrigin", fTemp);
        TE_WriteVector("m_vecOrigin", fTemp);
        TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
        TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
        TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
        TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
        TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
        TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
        TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
        TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
        TE_Send(newClients, nClients, delay);
    }

    return Plugin_Stop;
}

public Action TE_OnEffectDispatch(const char[] te_name, const int[] clients, int numClients, float delay)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    int victim = TE_ReadNum("entindex");

    if (IsClientValid(victim))
    {
        if (g_bDM[victim])
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action OnSetTransmit(int target, int client)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!IsClientValid(target) || !IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[target] != g_bRedie[client])
    {
        return Plugin_Handled;
    }

    if (g_bDM[target] != g_bDM[client])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!IsClientValid(iVictim) || !IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[iVictim] && !g_bDM[iVictim])
    {
        return Plugin_Handled;
    }

    if (g_bDM[iAttacker] != g_bDM[iVictim])
    {
        return Plugin_Handled;
    }

    if (g_bDM[iAttacker] && g_hSpawn[iVictim] != null)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnWeapon(int client, int weapon)
{
    if (!g_cEnable.BoolValue)
    {
        return Plugin_Continue;
    }

    if(IsClientValid(client) && IsValidEntity(weapon))
    {
        if (g_bDM[client])
        {
            char sWeapon[32];
            GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

            if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1)
            {
                RequestFrame(Frame_SetBlock, EntIndexToEntRef(weapon));
            }
        }

        if (g_bRedie[client] && !g_bDM[client])
        {
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

public void Frame_SetBlock(int ref)
{
    int iWeapon = EntRefToEntIndex(ref);

    if (IsValidEntity(iWeapon))
    {
        SetEntDataFloat(iWeapon, g_iNextPrimaryAttack, GetGameTime() + 9999.9);
        SetEntDataFloat(iWeapon, g_iNextSecondaryAttack, GetGameTime() + 9999.9);
    }
}

void SetRedie(int client, bool bDeathmatch = false)
{
    if (g_bRedie[client])
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_RADAR);

        int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

        if (IsValidEntity(iWeapon))
        {
            char sWeapon[32];
            GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
            
            if (strlen(sWeapon) > 1 && (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1))
            {
                SetEntDataFloat(iWeapon, g_iNextPrimaryAttack, GetGameTime() + 9999.9);
                SetEntDataFloat(iWeapon, g_iNextSecondaryAttack, GetGameTime() + 9999.9);
            }
        }

        if (bDeathmatch)
        {
            if (g_hSpawn[client] != null)
            {
                ClearTimer(g_hSpawn[client]);
            }

            g_hSpawn[client] = CreateTimer(g_fSpawnProt, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

            PrintToChat(client, "You have now spawn protection for %.1f seconds!", g_fSpawnProt);
        }
        
        SetListener(client);
    }
    else
    {
        ResetClient(client);
    }
}

void SetListener(int client)
{
    if (g_bRedie[client])
    {
        LoopClients(i)
        {
            if (!g_cListenerMode.BoolValue)
            {
                // Redie (incl. deathmatch) players can hear living players but can't talk to living players
                if (IsPlayerAlive(i) && !g_bRedie[client])
                {
                    SetListenOverride(client, i, Listen_Yes);
                    SetListenOverride(i, client, Listen_No);
                    continue;
                }
            }
            else
            {
                // Redie (incl. deathmatch) players can't hear and talk to living players
                if (IsPlayerAlive(i) && !g_bRedie[client])
                {
                    SetListenOverride(client, i, Listen_No);
                    SetListenOverride(i, client, Listen_No);
                    continue;
                }
            }

            // Deathmatch players can hear and talk to other deathmatch players
            if (g_bDM[i] && g_bDM[client])
            {
                SetListenOverride(client, i, Listen_Yes);
                SetListenOverride(i, client, Listen_Yes);
                continue;
            }

            // Deathmath players can't hear and talk to other non deathmatch players
            if (g_bDM[i] && !g_bDM[client])
            {
                SetListenOverride(client, i, Listen_No);
                SetListenOverride(i, client, Listen_No);
                continue;
            }

            // Redie players can hear and talk to other redie players
            if (g_bRedie[i] && !g_bDM[i] && !g_bDM[client])
            {
                SetListenOverride(client, i, Listen_Yes);
                SetListenOverride(i, client, Listen_Yes);
                continue;
            }

            // Redie players can't hear and talk to other non redie/ghostdeathmatch players
            if (!g_bRedie[i])
            {
                SetListenOverride(client, i, Listen_No);
                SetListenOverride(i, client, Listen_No);
                continue;
            }
        }
    }
    else
    {
        // Taken from ttt_talk_override player_team event
        LoopClients(i)
        {
            if (!IsPlayerAlive(client))
            {
                if (IsPlayerAlive(i))
                {
                    SetListenOverride(i, client, Listen_No);
                    SetListenOverride(client, i, Listen_Yes);
                }
                else
                {
                    SetListenOverride(i, client, Listen_Yes);
                    SetListenOverride(client, i, Listen_Yes);
                }
            }
            else
            {
                SetListenOverride(client, i, Listen_Yes);
                SetListenOverride(i, client, Listen_Yes);
            }
        }
    }
}

public Action Timer_Spawn(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        g_hSpawn[client] = null;
    }

    return Plugin_Stop;
}

void ResetClient(int client)
{
    g_bRedie[client] = false;
    g_bDM[client] = false;

    if (IsClientInGame(client))
    {
        ClearTimer(g_hRespawn[client]);
        ClearTimer(g_hSpawn[client]);

        SetListener(client);

        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_ALL);

        int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

        if (IsValidEntity(iWeapon))
        {
            char sWeapon[32];
            GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
            
            if (strlen(sWeapon) > 1 && (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1))
            {
                SetEntDataFloat(iWeapon, g_iNextPrimaryAttack, GetGameTime() - 0.1);
                SetEntDataFloat(iWeapon, g_iNextSecondaryAttack, GetGameTime() - 0.1);
            }
        }
    }

    g_hRespawn[client] = null;
    g_hSpawn[client] = null;
}

bool IsClientValid(int client, bool nobots = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if (IsClientSourceTV(client) || !IsClientInGame(client))
        {
            return false;
        }
        
        if (nobots && IsFakeClient(client))
        {
            return false;
        }

        return true;
    }

    return false;
}

void ClearTimer(Handle &timer, bool autoClose = false)
{
    if (timer != null)
    {
        KillTimer(timer, autoClose);
        timer = null;
    }
}
