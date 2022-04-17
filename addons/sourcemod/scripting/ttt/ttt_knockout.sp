#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#undef REQUIRE_PLUGIN
#pragma newdecls optional
#include <basecomm>
#include <sourcecomms>
#pragma newdecls required
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Knockout"
#define SHORT_NAME "knockout"

#define MODEL_BLACKOUT "models/blackout.mdl"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cLongName = null;
ConVar g_cCount = null;
ConVar g_cTimer = null;
ConVar g_cLimit = null;
ConVar g_cMute = null;

ConVar g_cStartMelee = null;
ConVar g_cAdditionalMeleeTeam = null;
ConVar g_cAdditionalMeleeWeapon = null;

int g_iFreeze = -1;

bool g_bSourceC = false;
bool g_bBaseC = false;

UserMsg g_uFade = view_as<UserMsg>(-1);

enum struct PlayerData {
    int Ragdoll;
    int Camera;
    int Collision;

    bool IsKnockout;

    RenderMode Mode;
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
    CreateNative("TTT_IsClientKnockout", Native_IsClientKnockout);
    
    RegPluginLibrary("ttt_knockout");

    return APLRes_Success;
}

public int Native_IsClientKnockout(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_iPlayer[client].IsKnockout;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    g_iFreeze = FindSendPropInfo("CBasePlayer", "m_fFlags");
    if (g_iFreeze == -1)
    {
        SetFailState("m_fFlags not found...");
    }

    g_uFade = GetUserMessageId("Fade");
    if (g_uFade == view_as<UserMsg>(-1))
    {
        SetFailState("Failure with UserMessage Fade...");
    }

    TTT_LoadTranslations();

    TTT_StartConfig("knockout");
    CreateConVar("ttt2_knockout_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("knockout_name", "Knockout", "The name of this in Shop");
    g_cPrice = AutoExecConfig_CreateConVar("knockout_price", "9000", "The amount of credits a knockout costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("knockout_sort_prio", "0", "The sorting priority of the knockout in the shop menu.");
    g_cCount = AutoExecConfig_CreateConVar("knockout_count", "1", "The amount of usages for knockout per round as traitor. 0 to disable.");
    g_cTimer = AutoExecConfig_CreateConVar("knockout_last", "5.0", "How long the knockout shoud last.", _, true, 3.0);
    g_cMute = AutoExecConfig_CreateConVar("knockout_local_mute", "1", "Choose 1 if you want to use external plugins for mure like sourcecomms or 0 for internal mute", _, true, 0.0, true, 1.0);
    g_cLimit = AutoExecConfig_CreateConVar("knockout_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    TTT_EndConfig();
    
    LoopValidClients(i)
    {
        OnClientPutInServer(i);
    }
    
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
    PrecacheModel(MODEL_BLACKOUT, true);
}

public void OnConfigsExecuted()
{
    g_cStartMelee = FindConVar("ttt_start_melee_weapon");
    g_cAdditionalMeleeTeam = FindConVar("ttt_additional_melee_role");
    g_cAdditionalMeleeWeapon = FindConVar("ttt_additional_melee_weapon");

    RegisterItem();
}

public void TTT_OnShopReady()
{
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_TRAITOR, g_cPrio.IntValue, g_cCount.IntValue, g_cLimit.IntValue, OnItemPurchased);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int role = TTT_GetClientTeam(client);

    if (role != TTT_TEAM_TRAITOR)
    {
        return Plugin_Stop;
    }

    TTT_RemoveWeaponByClassname(client, "weapon_taser");
    
    GivePlayerItem(client, "weapon_taser");

    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if(!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if(g_iPlayer[client].IsKnockout)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (TTT_IsClientValid(attacker) && TTT_IsClientValid(victim))
    {
        if (TTT_IsItemInInventory(attacker, SHORT_NAME) && !g_iPlayer[victim].IsKnockout)
        {
            char sWeapon[32];
            GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));

            if (StrContains(sWeapon, "taser", false) != -1)
            {
                KnockoutPlayer(victim);
                
                TTT_RemoveInventoryItem(attacker, SHORT_NAME);
                TTT_AddItemUsage(attacker, SHORT_NAME);

                return Plugin_Handled;
            }
        }
    }
    
    if(TTT_IsClientValid(victim) && g_iPlayer[victim].IsKnockout)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

void KnockoutPlayer(int client)
{
    char sModel[256];
    GetClientModel(client, sModel, sizeof(sModel));

    float pos[3];
    GetClientEyePosition(client, pos);

    int iEntity = CreateEntityByName("prop_ragdoll");
    DispatchKeyValue(iEntity, "model", sModel);
    SetEntProp(iEntity, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
    SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
    SetEntityMoveType(iEntity, MOVETYPE_NONE);
    AcceptEntityInput(iEntity, "DisableMotion");
    
    char sName[24];
    Format(sName, sizeof(sName), "knockout_ragdoll_%d", GetClientUserId(client));
    DispatchKeyValue(iEntity, "targetname", sName);
    pos[2] -= 16.0;
    TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);

    if (DispatchSpawn(iEntity))
    {
        SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
        AcceptEntityInput(iEntity, "EnableMotion");
        SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);

        g_iPlayer[client].Ragdoll = iEntity;
        g_iPlayer[client].IsKnockout = true;

        g_iPlayer[client].Mode = GetEntityRenderMode(client);
        CreateTimer(0.1, Timer_FixMode, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

        g_iPlayer[client].Collision = GetEntProp(client, Prop_Data, "m_CollisionGroup");
        SetEntProp(client, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
        
        DropWeapons(client);
        SetEntData(client, g_iFreeze, FL_CLIENT|FL_ATCONTROLS, 4, true);
        
        SpawnCamAndAttach(client, iEntity);
        PerformBlind(client, 255);

        CreateTimer(g_cTimer.FloatValue, Timer_Delete, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        if (g_cMute.BoolValue)
        {
            if (g_bSourceC)
            {
                SourceComms_SetClientMute(client, true, 1, false, "Knockout");
            }
            else if (g_bBaseC)
            {
                BaseComm_SetClientMute(client, true);
            }
            else
            {
                LogError("[%s] (KnockoutPlayer) Can't mute client.", PLUGIN_NAME);
            }
        }
        else
        {
            SetClientListeningFlags(client, VOICE_MUTED);
        }
    }
    else
    {
        LogError("[%s] (KnockoutPlayer) Can't spawn prop_ragdoll.", PLUGIN_NAME);
    }
}

public Action Timer_FixMode(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (TTT_IsClientValid(client) && g_iPlayer[client].IsKnockout)
    {
        SetEntityRenderMode(client, RENDER_NONE);
        return Plugin_Continue;
    }
    
    return Plugin_Stop;
}

void DropWeapons(int client)
{
    for(int i = 0; i < GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons"); i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if ((StrContains(sClass, "knife", false) != -1) || (StrContains(sClass, "bayonet", false) != -1))
            {
                if (!TTT_SafeRemoveWeapon(client, weapon))
                {
                    LogError("Can't remove knife! Player: \"%L\"", client);
                }
            }
            else
            {
                SDKHooks_DropWeapon(client, weapon);
            }
        }
    }
}

public Action Timer_Delete(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (TTT_IsClientValid(client))
    {
        int entity = g_iPlayer[client].Ragdoll;
    
        if (entity != -1 && IsValidEntity(entity))
            AcceptEntityInput(entity, "kill");
        
        int entity2 = EntRefToEntIndex(g_iPlayer[client].Camera);
        if(entity2 != -1)
            AcceptEntityInput(entity2, "kill");
        
        g_iPlayer[client].Camera = -1;
        g_iPlayer[client].Ragdoll = -1;
        g_iPlayer[client].IsKnockout = false;
        
        if(TTT_IsClientValid(client))
        {
            if (g_cMute.BoolValue)
            {
                if (g_bSourceC)
                {
                    SourceComms_SetClientMute(client, false);
                }
                else if (g_bBaseC)
                {
                    BaseComm_SetClientMute(client, false);
                }
            }
            else
            {
                if (IsPlayerAlive(client))
                {
                    SetClientListeningFlags(client, VOICE_NORMAL);
                }
            }
            
            SetEntData(client, g_iFreeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
            SetClientViewEntity(client, client);
            g_iPlayer[client].Camera = false;
            PerformBlind(client, 0);
            SetEntProp(client, Prop_Data, "m_CollisionGroup", g_iPlayer[client].Collision);
            SetEntityRenderMode(client, g_iPlayer[client].Mode);
            
            GiveMelee(client);
        }
    }
    
    return Plugin_Handled;
}

bool SpawnCamAndAttach(int client, int ragdoll)
{
    char sModelName[64];
    Format(sModelName, sizeof(sModelName), "fpd_ragdoll%d", client);
    DispatchKeyValue(ragdoll, "targetname", sModelName);

    int entity = CreateEntityByName("prop_dynamic");
    if (entity == -1)
    {
        return false;
    }

    char sEntityName[64];
    Format(sEntityName, sizeof(sEntityName), "fpd_ragdollCam%d", entity);

    DispatchKeyValue(entity, "targetname", sEntityName);
    DispatchKeyValue(entity, "parentname", sModelName);
    DispatchKeyValue(entity, "model",      MODEL_BLACKOUT);
    DispatchKeyValue(entity, "solid",      "0");
    DispatchKeyValue(entity, "rendermode", "10");
    DispatchKeyValue(entity, "disableshadows", "1");

    float angles[3]; GetClientEyeAngles(client, angles);
    char CamTargetAngles[64];
    Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);
    DispatchKeyValue(entity, "angles", CamTargetAngles);

    SetEntityModel(entity, MODEL_BLACKOUT);
    
    DispatchSpawn(entity);
    SetVariantString(sModelName);
    AcceptEntityInput(entity, "SetParent", entity, entity, 0);

    SetVariantString("forward");
    AcceptEntityInput(entity, "SetParentAttachment", entity, entity, 0);

    AcceptEntityInput(entity, "TurnOn");

    SetClientViewEntity(client, entity);
    g_iPlayer[client].Camera = EntIndexToEntRef(entity);
    
    return true;
}

void PerformBlind(int client, int amount)
{
    int targets[2];
    targets[0] = client;

    int duration = 1536;
    int holdtime = 1536;
    int flags;
    if (amount == 0)
        flags = (0x0001 | 0x0010);
    else flags = (0x0002 | 0x0008);

    int color[4] = { 0, 0, 0, 0 };
    color[3] = amount;

    Handle message = StartMessageEx(g_uFade, targets, 1);
    if (GetUserMessageType() == UM_Protobuf)
    {
        PbSetInt(message, "duration", duration);
        PbSetInt(message, "hold_time", holdtime);
        PbSetInt(message, "flags", flags);
        PbSetColor(message, "clr", color);
    }
    else
    {
        BfWriteShort(message, duration);
        BfWriteShort(message, holdtime);
        BfWriteShort(message, flags);
        BfWriteByte(message, color[0]);
        BfWriteByte(message, color[1]);
        BfWriteByte(message, color[2]);
        BfWriteByte(message, color[3]);
    }

    EndMessage();
}

void GiveMelee(int client)
{
    TTT_RemoveMeleeWeapons(client);

    if (g_cStartMelee == null || g_cAdditionalMeleeTeam == null || g_cAdditionalMeleeWeapon == null)
    {
        return;
    }

    char sWeapon[32];
    g_cStartMelee.GetString(sWeapon, sizeof(sWeapon));
    Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);

    int iWeapon = GivePlayerItem(client, sWeapon);
    EquipPlayerWeapon(client, iWeapon);

    if (g_cAdditionalMeleeTeam.IntValue & TTT_GetClientTeam(client))
    {
        g_cAdditionalMeleeWeapon.GetString(sWeapon, sizeof(sWeapon));
        Format(sWeapon, sizeof(sWeapon), "weapon_%s", sWeapon);
        iWeapon = GivePlayerItem(client, sWeapon);
        EquipPlayerWeapon(client, iWeapon);
    }
}
