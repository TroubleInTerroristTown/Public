#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt_inventory>
#include <ttt>
#include <ttt_playerhud>
#include <colorlib>

#undef REQUIRE_PLUGIN
#pragma newdecls optional
#include <basecomm>
#include <sourcecomms>
#pragma newdecls required
#define REQUIRE_PLUGIN

#define SHORT_NAME "iceknife"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Ice Knife"

#define ICE_MODEL "models/weapons/eminem/ice_cube/ice_cube.mdl"
#define FREEZE_SOUND "weapons/eminem/ice_cube/freeze.wav"
#define UNFREEZE_SOUND "weapons/eminem/ice_cube/unfreeze.wav"

ConVar g_cPrice = null;
ConVar g_cDamage = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cFreezeTime = null;
ConVar g_cFreezeTraitors = null;
ConVar g_cLongName = null;
ConVar g_cMute = null;
ConVar g_cMuteMode = null;
ConVar g_cGag = null;
ConVar g_cIceCube = null;
ConVar g_cFreezeVolume = null;
ConVar g_cUnfreezeVolume = null;
ConVar g_cHidePlayerHUD = null;
ConVar g_cLimit = null;

bool g_bSourceC = false;
bool g_bBaseC = false;

enum struct PlayerData {
    int OldColors[4];
    int IceEntity;

    float Location[3];

    bool Freezed;
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

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();

    TTT_StartConfig("ice_knife");
    CreateConVar("ttt2_ice_knife_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("iceknife_name", "Ice Knife", "The name of the Ice Knife in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("iceknife_price", "9000", "The amount of credits a Ice Knife costs as traitor. 0 to disable.");
    g_cCount = AutoExecConfig_CreateConVar("iceknife_count", "2", "The amount of usages for Ice Knifes per round as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("iceknife_sort_prio", "0", "The sorting priority of the Ice Knife in the shop menu.");
    g_cDamage = AutoExecConfig_CreateConVar("iceknife_damage", "0", "Amount of damage with a ice knife. 0 to disable.");
    g_cFreezeTraitors = AutoExecConfig_CreateConVar("iceknife_freeze_traitors", "0", "Allow to freeze other traitors?", _, true, 0.0, true, 1.0);
    g_cFreezeTime = AutoExecConfig_CreateConVar("iceknife_freeze_time", "5.0", "Length of the freeze time. 0.0 - Disabled");
    g_cMute = AutoExecConfig_CreateConVar("iceknife_mute", "1", "Mute client during freeze time?", _, true, 0.0, true, 1.0);
    g_cMuteMode = AutoExecConfig_CreateConVar("iceknife_local_mute", "1", "Choose 1 if you want to use external plugins for mure like sourcecomms or 0 for internal mute", _, true, 0.0, true, 1.0);
    g_cGag = AutoExecConfig_CreateConVar("iceknife_gag", "1", "Gag client during freeze time?", _, true, 0.0, true, 1.0);
    g_cIceCube = AutoExecConfig_CreateConVar("iceknife_ice_cube", "1", "Set player into a ice cube during freeze?", _, true, 0.0, true, 1.0);
    g_cFreezeVolume = AutoExecConfig_CreateConVar("iceknife_freeze_volume", "0.7", "Volume of freeze sound", _, true, 0.1, true, 1.0);
    g_cUnfreezeVolume = AutoExecConfig_CreateConVar("iceknife_unfreeze_volume", "0.7", "Volume of unfreeze sound", _, true, 0.1, true, 1.0);
    g_cHidePlayerHUD = AutoExecConfig_CreateConVar("iceknife_hide_playerhud", "1", "Hide PlayerHUD during freeze", _, true, 0.0, true, 1.0);
    g_cLimit = AutoExecConfig_CreateConVar("iceknife_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
    LateLoadAll();

    g_bSourceC = LibraryExists("sourcecomms");
    g_bBaseC = LibraryExists("basecomm");
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "sourcecomms"))
    {
        g_bSourceC = true;
    }

    if (StrEqual(name, "basecomm"))
    {
        g_bBaseC = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "sourcecomms"))
    {
        g_bSourceC = false;
    }

    if (StrEqual(name, "basecomm"))
    {
        g_bBaseC = false;
    }
}

public void OnMapStart()
{
    AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube.vtf");
    AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube_normal.vtf");
    AddFileToDownloadsTable("materials/models/weapons/eminem/ice_cube/ice_cube.vmt");
    AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.phy");
    AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.vvd");
    AddFileToDownloadsTable("models/weapons/eminem/ice_cube/ice_cube.dx90.vtx");

    AddFileToDownloadsTable(ICE_MODEL);
    PrecacheModel(ICE_MODEL, true);

    PrecacheSound(FREEZE_SOUND);
    AddFileToDownloadsTable("sound/" ... FREEZE_SOUND);

    PrecacheSound(UNFREEZE_SOUND);
    AddFileToDownloadsTable("sound/" ... UNFREEZE_SOUND);
}

public void OnConfigsExecuted()
{
    RegisterItem();
}

public void OnClientPutInServer(int client)
{
    HookClient(client);
}

public void LateLoadAll()
{
    LoopValidClients(i)
    {
        LateLoadClient(i);
    }
}
public void LateLoadClient(int client)
{
    HookClient(client);
}

public void HookClient(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public void OnClientDisconnect(int client)
{
    if (TTT_IsClientValid(client))
    {
        ResetIceKnife(client);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        if (g_iPlayer[client].IceEntity == 0)
        {
            g_iPlayer[client].IceEntity = -1;
        }
        
        GetEntityRenderColor(client, g_iPlayer[client].OldColors[0], g_iPlayer[client].OldColors[1], g_iPlayer[client].OldColors[2], g_iPlayer[client].OldColors[3]);
        ResetIceKnife(client);
    }
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sName[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sName, sizeof(sName));
    TTT_RegisterShopItem(SHORT_NAME, sName, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

void ResetIceKnife(int client)
{
    g_iPlayer[client].Freezed = false;

    RemoveIce(client);
}

public Action OnTraceAttack(int iVictim, int &iAttacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(iVictim) || !TTT_IsClientValid(iAttacker))
    {
        return Plugin_Continue;
    }

    if (g_iPlayer[iVictim].Freezed)
    {
        return Plugin_Handled;
    }

    if (TTT_IsWorldDamage(iAttacker, damagetype))
    {
        return Plugin_Continue;
    }

    if (!TTT_IsItemInInventory(iAttacker, SHORT_NAME))
    {
        return Plugin_Continue;
    }

    if (!g_cFreezeTraitors.BoolValue && TTT_GetClientTeam(iVictim) == TTT_TEAM_TRAITOR)
    {
        return Plugin_Continue;
    }

    char sWeapon[64];
    GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
    if (StrContains(sWeapon, "knife", false) != -1 || StrContains(sWeapon, "bayonet", false) != -1)
    {
        if (g_cFreezeTime.FloatValue > 0.0)
        {
            g_iPlayer[iVictim].Freezed = true;
            
            TTT_RemoveInventoryItem(iAttacker, SHORT_NAME);
            TTT_AddItemUsage(iAttacker, SHORT_NAME);

            SetEntityMoveType(iVictim, MOVETYPE_NONE);
            SetEntPropFloat(iVictim, Prop_Data, "m_flLaggedMovementValue", 0.0);

            GetEntityRenderColor(iVictim, g_iPlayer[iVictim].OldColors[0], g_iPlayer[iVictim].OldColors[1], g_iPlayer[iVictim].OldColors[2], g_iPlayer[iVictim].OldColors[3]);
            SetEntityRenderColor(iVictim, 0, 128, 255, 135);

            GetClientEyeAngles(iVictim, g_iPlayer[iVictim].Location);
            RequestFrame(Frame_SetAngles, GetClientUserId(iVictim));

            if (g_cIceCube.BoolValue)
            {
                PlaySound(iVictim, true);
                FreezeModel(iVictim, true);
            }

            if (g_cMute.BoolValue)
            {
                if (g_cMuteMode.BoolValue)
                {
                    if (g_bSourceC)
                    {
                        SourceComms_SetClientMute(iVictim, true, 1, false, "Ice Knife");
                    }
                    else if (g_bBaseC)
                    {
                        BaseComm_SetClientMute(iVictim, true);
                    }
                    else
                    {
                        LogError("[%s] (OnTraceAttack) Can't mute \"%L\".", PLUGIN_NAME, iVictim);
                    }
                }
                else
                {
                    SetClientListeningFlags(iVictim, VOICE_MUTED);
                }
            }

            if (g_cGag.BoolValue)
            {
                if (g_bSourceC)
                {
                    SourceComms_SetClientGag(iVictim, true, 1, false, "Ice Knife");
                }
                else if (g_bBaseC)
                {
                    BaseComm_SetClientGag(iVictim, true);
                }
                else
                {
                    LogError("[%s] (OnTraceAttack) Can't gag \"%L\".", PLUGIN_NAME, iVictim);
                }
            }

            CreateTimer(g_cFreezeTime.FloatValue, Timer_FreezeEnd, GetClientUserId(iVictim));
        }

        if (g_cDamage.IntValue == 0)
        {
            return Plugin_Handled;
        }
        else if (g_cDamage.IntValue > 0)
        {
            damage = view_as<float>(g_cDamage.IntValue);
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

public void Frame_SetAngles(any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client) && g_iPlayer[client].Freezed)
    {
        TeleportEntity(client, NULL_VECTOR, g_iPlayer[client].Location, NULL_VECTOR);
        RequestFrame(Frame_SetAngles, GetClientUserId(client));
    }
}

public Action TTT_OnHudSend_Pre(int client, int target, char[] sName, int iNameLength, char[] sPlayerName, int &iPlayerNameLength, char[] sHealth, int iHealthLength, char[] sPlayerHealth, int iPlayerHealthLength, char[] sKarma, int iKarmaLength, char[] sPlayerKarma, int iPlayerKarmaLength)
{
    if (g_cHidePlayerHUD.BoolValue && g_iPlayer[client].Freezed)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Timer_FreezeEnd(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (TTT_IsClientValid(client))
    {
        if (g_cIceCube.BoolValue)
        {
            PlaySound(client, false);
            FreezeModel(client, false);
        }
        
        if (g_cMute.BoolValue)
        {
            if (g_cMuteMode.BoolValue)
            {
                if (g_bSourceC)
                {
                    SourceComms_SetClientMute(client, false);
                }
                else if (g_bBaseC)
                {
                    BaseComm_SetClientMute(client, false);
                }
                else
                {
                    LogError("[%s] (Timer_FreezeEnd) Can't unmute \"%L\".", PLUGIN_NAME, client);
                }
            }
            else
            {
                if (IsPlayerAlive(client))
                {
                    SetClientListeningFlags(client, VOICE_NORMAL);
                }
            }
        }

        if (g_cGag.BoolValue)
        {
            if (g_bSourceC)
            {
                SourceComms_SetClientGag(client, false);
            }
            else if (g_bBaseC)
            {
                BaseComm_SetClientGag(client, false);
            }
            else
            {
                LogError("[%s] (Timer_FreezeEnd) Can't ungag \"%L\".", PLUGIN_NAME, client);
            }
        }

        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

        SetEntityRenderColor(client, g_iPlayer[client].OldColors[0], g_iPlayer[client].OldColors[1], g_iPlayer[client].OldColors[2], g_iPlayer[client].OldColors[3]);

        g_iPlayer[client].Freezed = false;
    }
    return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (g_iPlayer[client].Freezed)
    {
        float fVel[3];
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);

        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void PlaySound(int client, bool freeze)
{
    if (freeze)
    {
        float vec[3];
        GetClientAbsOrigin(client, vec);
        vec[2] += 10;

        GetClientEyePosition(client, vec);
        EmitAmbientSound(FREEZE_SOUND, vec, client, SNDLEVEL_RAIDSIREN, _, g_cFreezeVolume.FloatValue);
    }
    else
    {
        float vec[3];
        GetClientAbsOrigin(client, vec);
        vec[2] += 10;

        GetClientEyePosition(client, vec);
        EmitAmbientSound(UNFREEZE_SOUND, vec, client, SNDLEVEL_RAIDSIREN, _, g_cUnfreezeVolume.FloatValue);
    }
}


void FreezeModel(int client, bool freeze)
{
    if (freeze)
    {
        SpawnIce(client);
    }
    else
    {
        RemoveIce(client);
    }
}

void SpawnIce(int client)
{
    float fPos[3];
    GetClientAbsOrigin(client, fPos);

    int iEntity = CreateEntityByName("prop_dynamic_override");
    DispatchKeyValue(iEntity, "model", ICE_MODEL);
    DispatchKeyValue(iEntity, "solid", "0");
    DispatchKeyValue(iEntity, "spawnflags", "256");

    SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

    TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);

    if (DispatchSpawn(iEntity))
    {
        AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity);
        SetVariantString("!activator");
        AcceptEntityInput(iEntity, "SetParent", client, iEntity);

        g_iPlayer[client].IceEntity = EntIndexToEntRef(iEntity);
    }
}

void RemoveIce(int client)
{
    int entity = EntRefToEntIndex(g_iPlayer[client].IceEntity);

    if (IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }

    g_iPlayer[client].IceEntity = -1;
}
