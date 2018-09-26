#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

#define HUD_RADAR ( 1<<12 )
#define HUD_ALL 2050

// Following settings are just hardcoded and will replaced with convars later....
#define RESPAWN_DELAY 5.0
#define SPAWN_PROTECTION 3.0

bool g_bRedie[MAXPLAYERS + 1 ] = { false, ... };

int g_iNextPrimaryAttack = -1;
int g_iNextSecondaryAttack = -1;

Handle g_hRespawn[MAXPLAYERS + 1] = { null, ...};
Handle g_hSpawn[MAXPLAYERS + 1] = { null, ...};

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
    CreateNative("Redie_GetClientStatus", Native_GetClientStatus);

    RegPluginLibrary("ghostdm");
    
    return APLRes_Success;
}

public int Native_GetClientStatus(Handle plugin, int numParams)
{
    return g_bRedie[GetNativeCell(1)];
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_redie", Command_Redie);

    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

    AddNormalSoundHook(view_as<NormalSHook>(OnNormalSHook));

    AddTempEntHook("Shotgun Shot", TE_OnShotgunShot);
    AddTempEntHook("EffectDispatch", TE_OnEffectDispatch);

    g_iNextPrimaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextPrimaryAttack");
    g_iNextSecondaryAttack = FindSendPropInfo("CBaseCombatWeapon", "m_flNextSecondaryAttack");

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
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_bRedie[client])
    {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HUD_ALL);
    }

    g_bRedie[client] = !g_bRedie[client];

    PrintToChat(client, "Changed redie status to: %s", g_bRedie[client] ? "On" : "Off");

    SetRedie(client);

    return Plugin_Handled;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    LoopClients(i)
    {
        ResetClient(i);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
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
        }
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientValid(victim))
    {
        if (g_hRespawn[victim] != null)
        {
            ClearTimer(g_hRespawn[victim]);
        }

        PrintToChat(victim, "You will be respawned in %.1f seconds!", RESPAWN_DELAY);
        g_hRespawn[victim] = CreateTimer(RESPAWN_DELAY, Timer_Respawn, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);

        Handle hPlugin = FindPluginByFile("ttt/ttt_hide_radar.smx");

        if (hPlugin == null || GetPluginStatus(hPlugin) != Plugin_Running)
        {
            SetEntProp(victim, Prop_Send, "m_iHideHUD", HUD_ALL);
        }
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (IsClientValid(attacker) && IsClientValid(victim))
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
                if (g_bRedie[i])
                {
                    eEvent.FireToClient(i);
                }
            }

            eEvent.Cancel();
        }
    }

    event.BroadcastDisabled = true;
    return Plugin_Handled;
}

public Action Timer_Respawn(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client) && g_hRespawn[client] != null)
    {
        if (g_bRedie[client])
        {
            CS_RespawnPlayer(client);
        }

        g_hRespawn[client] = null;
    }

    return Plugin_Stop;
}

public Action OnNormalSHook(int[] clients, int &numClients, char[] sample, int &client, int &channel, float &volume, int &level, int &pitch, int &flags, char[] soundEntry, int &seed)
{
    if (IsClientValid(client))
    {
        int iTemp = numClients;
        numClients = 0;

        LoopClients(i)
        {
            if (g_bRedie[client] == g_bRedie[i])
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
    if (!StrEqual(te_name, "Shotgun Shot", false))
    {
        return Plugin_Continue;
    }

    int client = TE_ReadNum("m_iPlayer") + 1;

    if (!IsClientValid(client))
    {
        return Plugin_Continue;
    }

    int[] newClients = new int[MaxClients];
    int nClients = 0;
    
    LoopClients(i)
    {
        if (i == client)
        {
            continue;
        }

        if (g_bRedie[client] == g_bRedie[i])
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
    int victim = TE_ReadNum("entindex");

    if (IsClientValid(victim))
    {
        if (g_bRedie[victim])
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action OnSetTransmit(int target, int client)
{
    if (!IsClientValid(target) || !IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[target] != g_bRedie[client])
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (!IsClientValid(iVictim) || !IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if (g_bRedie[iAttacker] != g_bRedie[iVictim])
    {
        return Plugin_Handled;
    }

    if (g_bRedie[iAttacker] && g_hSpawn[iVictim] != null)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnWeapon(int client, int weapon)
{
    if(IsClientValid(client) && IsValidEntity(weapon) && g_bRedie[client])
    {
        char sWeapon[32];
        GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

        if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1)
        {
            RequestFrame(Frame_SetBlock, EntIndexToEntRef(weapon));
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

void SetRedie(int client)
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

        PrintToChat(client, "You have now spawn protection for %.1f seconds!", SPAWN_PROTECTION);

        if (g_hSpawn[client] != null)
        {
            ClearTimer(g_hSpawn[client]);
        }

        g_hSpawn[client] = CreateTimer(SPAWN_PROTECTION, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        ResetClient(client);
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

    if (IsClientInGame(client))
    {
        ClearTimer(g_hRespawn[client]);
        ClearTimer(g_hSpawn[client]);

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
        if (!IsClientConnected(client) || IsClientSourceTV(client) || !IsClientInGame(client))
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
