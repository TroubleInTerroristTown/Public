#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colorlib>
#include <autoexecconfig>
#include <ttt>
#include <ttt_ragdoll>

#undef REQUIRE_PLUGIN
#include <ttt_grabbermod>

#define MODEL_MICROWAVE "props/cs_office/microwave.mdl"

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME,
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

ArrayList g_aRagdoll = null;

GlobalForward g_fwOnBodyCreate = null;
GlobalForward g_fwOnBodyFound = null;
GlobalForward g_fwOnBodyCheck = null;

bool g_bGrabberMod = false;

enum struct PlayerData {
    bool IsChecking;
    bool Found;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

int g_iParticleRef[2048] = { -1, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[64];
ConVar g_cDebugMessages = null;
ConVar g_cAddSteamIDtoLogs = null;
ConVar g_cSteamIDLogFormat = null;

ConVar g_cShowNewPlayersAs = null;
ConVar g_cSpawnType = null;
ConVar g_cIdentifyLog = null;
ConVar g_cIdentifyDistance = null;
ConVar g_cIdentifyCommand = null;
ConVar g_cSilentIdEnabled = null;
ConVar g_cSilentIdColor = null;
ConVar g_cSilentIdRoles = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnBodyCreate = new GlobalForward("TTT_OnClientRagdollCreate", ET_Event, Param_Cell, Param_Cell, Param_String);
    g_fwOnBodyFound = new GlobalForward("TTT_OnBodyFound", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnBodyCheck = new GlobalForward("TTT_OnBodyCheck", ET_Event, Param_Cell, Param_Cell);

    CreateNative("TTT_GetClientRagdoll", Native_GetClientRagdoll);
    CreateNative("TTT_GetClientRagdollEntIndex", Native_GetClientRagdollEntIndex);
    CreateNative("TTT_GetEntityRefRagdoll", Native_GetEntityRefRagdoll);
    CreateNative("TTT_GetClientByRagdollID", Native_GetClientByRagdollID);
    CreateNative("TTT_PushRagdoll", Native_PushRagdoll);
    CreateNative("TTT_SetRagdoll", Native_SetRagdoll);
    CreateNative("TTT_WasBodyFound", Native_WasBodyFound);
    CreateNative("TTT_WasBodyScanned", Native_WasBodyScanned);
    CreateNative("TTT_GetFoundStatus", Native_GetFoundStatus);
    CreateNative("TTT_SetFoundStatus", Native_SetFoundStatus);
    CreateNative("TTT_CreateClientRagdoll", Native_CreateClientRagdoll);
    CreateNative("TTT_RemoveClientRagdoll", Native_RemoveClientRagdoll);
    CreateNative("TTT_GetFoundArray", Native_GetFoundArray);
    CreateNative("TTT_RemoveRagdollFromArray", Native_RemoveRagdollFromArray),

    RegPluginLibrary("ttt_bodies");

    return APLRes_Success;
}

public void OnPluginStart()
{
    Ragdoll body;
    g_aRagdoll = new ArrayList(sizeof(body));

    TTT_StartConfig("bodies");
    CreateConVar("ttt2_bodies_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cShowNewPlayersAs = AutoExecConfig_CreateConVar("ttt_show_new_player_as", "1", "Show new players as alive (0) or dead (1)?", _, true, 0.0, true, 1.0);
    g_cSpawnType = AutoExecConfig_CreateConVar("ttt_spawn_type", "0", "Which spawn you want. 0 - Default (Ragdoll), 1 - Physics Multiplayer, 2 - Particle (Ghosts)", _, true, 0.0, true, 2.0);
    g_cIdentifyCommand = AutoExecConfig_CreateConVar("ttt_allow_identify_command", "0", "Allowing players to identify ragdolls with the command \"sm_identify\"?", _, true, 0.0, true, 1.0);
    g_cIdentifyDistance = AutoExecConfig_CreateConVar("ttt_identify_max_distance", "90.0",  "Maximum distance from player to ragdoll to identify the ragdoll. (Default: 90.0)");
    g_cIdentifyLog = AutoExecConfig_CreateConVar("ttt_identity_log", "0", "Log every identified body?", _, true, 0.0, true, 1.0);
    g_cSilentIdEnabled = AutoExecConfig_CreateConVar("ttt_silent_id", "0", "0 = Disabled. 1 = Enable silent id (+speed and +use together). Silent ID wont print on chat when someone inspects a body.", _, true, 0.0, true, 1.0);
    g_cSilentIdColor = AutoExecConfig_CreateConVar("ttt_silent_id_color", "1", "0 = Disabled, will not change the color of the body. 1 = Silent ID will color the body when inspecting. (Green = Innocent, Red = Traitor, Blue = Detective)", _, true, 0.0, true, 1.0);
    g_cSilentIdRoles = AutoExecConfig_CreateConVar("ttt_silent_id_roles", "14", "2 = Innocent. 4 = Traitor. 8 = Detective. For other combinations, just sum the values. (i.e.: 14 (2+4+8) = All roles can Silent ID)");
    TTT_EndConfig();

    RegConsoleCmd("sm_identify", Command_Identify);

    HookEvent("round_start", Event_RoundStartPre, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEndPre, EventHookMode_Pre);
    HookEvent("player_changename", Event_ChangeName, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);

    TTT_LoadTranslations();
}

public void OnConfigsExecuted()
{
    // Get some values from ttt.cfg
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cDebugMessages = FindConVar("ttt_show_debug_messages");
    g_cAddSteamIDtoLogs = FindConVar("ttt_steamid_add_to_logs");
    g_cSteamIDLogFormat = FindConVar("ttt_steamid_log_format");
}

public void OnAllPluginsLoaded()
{
    if (LibraryExists("ttt_grabbermod"))
    {
        g_bGrabberMod = true;
    }
}

public void OnLibraryAdded(const char[] library)
{
    if (StrEqual(library, "ttt_grabbermod", false))
    {
        g_bGrabberMod = true;
    }
}

public void OnLibraryRemoved(const char[] library)
{
    if (StrEqual(library, "ttt_grabbermod", false))
    {
        g_bGrabberMod = false;
    }
}

public void OnMapStart()
{
    PrecacheModel(MODEL_MICROWAVE, true);
    PrecacheGhosts();
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].IsChecking = false;
    g_iPlayer[client].Found = g_cShowNewPlayersAs.BoolValue;
}

public void OnClientPostAdminCheck(int client)
{
    g_iPlayer[client].Found = g_cShowNewPlayersAs.BoolValue;
}

public void OnClientDisconnect(int client)
{
    g_iPlayer[client].Found = g_cShowNewPlayersAs.BoolValue;
}

public void TTT_OnButtonPress(int client, int button)
{
    if (button & IN_USE)
    {
        IdentifyEntity(client, button);
    }
}

public void TTT_OnButtonRelease(int client, int button)
{
    if (button & IN_USE)
    {
        g_iPlayer[client].IsChecking = false;
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action TTT_OnRoundStart_Pre()
{
    LoopValidClients(i)
    {
        g_iPlayer[i].Found = false;
    }

    return Plugin_Continue;
}

public void TTT_OnRoundStart()
{
    LoopValidClients(i)
    {
        if (!IsPlayerAlive(i))
        {
            g_iPlayer[i].Found = true;
        }
    }
}

public void TTT_OnClientGetRole(int client, int role)
{
    if (role == TTT_TEAM_UNASSIGNED)
    {
        g_iPlayer[client].Found = true;
    }
}

////////////////////////////////////////////////////////////////////////////////
// Events
////////////////////////////////////////////////////////////////////////////////

public Action Event_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
    if (g_aRagdoll != null)
    {
        g_aRagdoll.Clear();
    }

    if (g_cDebugMessages.BoolValue)
    {
        LogMessage("Event_RoundStartPre - 2 (g_aRagdoll: %d)", g_aRagdoll.Length);
    }

    LoopValidClients(i)
    {
        g_iPlayer[i].Found = true;
    }

    return Plugin_Continue;
}

public Action Event_RoundEndPre(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(i)
    {
        g_iPlayer[i].Found = true;
    }

    return Plugin_Continue;
}

public void Event_ChangeName(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    char sNew[MAX_NAME_LENGTH];
    event.GetString("newname", sNew, sizeof(sNew));

    int iSize = g_aRagdoll.Length;
    if (iSize == 0)
    {
        return;
    }

    Ragdoll body;

    for (int i = 0; i < iSize; ++i)
    {
        g_aRagdoll.GetArray(i, body, sizeof(body));

        if (client == GetClientOfUserId(body.Attacker))
        {
            Format(body.AttackerName, sizeof(Ragdoll::AttackerName), sNew);
            g_aRagdoll.SetArray(i, body, sizeof(body));
        }
        else if (client == GetClientOfUserId(body.Victim))
        {
            Format(body.VictimName, sizeof(Ragdoll::VictimName), sNew);
            g_aRagdoll.SetArray(i, body, sizeof(body));
        }
    }
}

public Action Event_PlayerDeathPre(Event event, const char[] menu, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    int iRagdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (iRagdoll > 0)
    {
        AcceptEntityInput(iRagdoll, "Kill");
    }

    if (TTT_GetClientRole(client) <= TTT_TEAM_UNASSIGNED)
    {
        g_iPlayer[client].Found = true;
        return Plugin_Continue;
    }

    int iUAttacker = event.GetInt("attacker");
    int iAttacker = GetClientOfUserId(iUAttacker);

    Ragdoll body;
    event.GetString("weapon", body.Weaponused, sizeof(body.Weaponused));

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnBodyCreate);
    Call_PushCell(client);
    Call_PushCell(iAttacker);
    Call_PushString(body.Weaponused);
    Call_Finish(res);

    if (res == Plugin_Stop)
    {
        return Plugin_Continue;
    }

    int iEntity = CreateRagdoll(client);

    int iARole = 0;
    char sName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sName, sizeof(sName));

    if (iEntity != -1)
    {
        body.EntityRef = EntIndexToEntRef(iEntity);
    }
    else
    {
        body.EntityRef = -1;
    }

    body.Victim = GetClientUserId(client);
    body.VictimRole = TTT_GetClientRole(client);
    Format(body.VictimName, sizeof(body.VictimName), sName);
    body.Scanned = false;

    if (TTT_IsClientValid(iAttacker))
    {
        TTT_GetClientName(iAttacker, sName, sizeof(sName));
        iARole = TTT_GetClientRole(iAttacker);
    }
    else
    {
        Format(sName, sizeof(sName), "Unknown attacker");
        iUAttacker = 0;
    }

    body.Attacker = iUAttacker;
    body.AttackerRole = iARole;
    Format(body.AttackerName, sizeof(body.AttackerName), sName);
    body.GameTime = GetGameTime();
    body.Explode = false;

    GetClientModel(client, body.Model, sizeof(Ragdoll::Model));

    if (iUAttacker > 0)
    {
        GetClientAuthId(iAttacker, AuthId_Steam2, body.AttackerSteam2, sizeof(body.AttackerSteam2));
    }

    GetClientAuthId(client, AuthId_Steam2, body.VictimSteam2, sizeof(body.VictimSteam2));
    
    if (iUAttacker > 0)
    {
        GetClientAuthId(iAttacker, AuthId_Steam3, body.AttackerSteam3, sizeof(body.AttackerSteam3));
    }

    GetClientAuthId(client, AuthId_Steam3, body.VictimSteam3, sizeof(body.VictimSteam3));
    
    if (iUAttacker > 0)
    {
        GetClientAuthId(iAttacker, AuthId_SteamID64, body.AttackerSteamID64, sizeof(body.AttackerSteamID64));
    }

    GetClientAuthId(client, AuthId_SteamID64, body.VictimSteamID64, sizeof(body.VictimSteamID64));

    if (iUAttacker > 0)
    {
        body.AttackerAccountID = GetSteamAccountID(iAttacker);
    }

    body.VictimAccountID = GetSteamAccountID(client);

    g_aRagdoll.PushArray(body, sizeof(body));

    return Plugin_Continue;
}

////////////////////////////////////////////////////////////////////////////////
// Commands
////////////////////////////////////////////////////////////////////////////////

public Action Command_Identify(int client, int args)
{
    if (!g_cIdentifyCommand.BoolValue)
    {
        return Plugin_Handled;
    }

    IdentifyEntity(client, IN_USE);

    return Plugin_Handled;
}

////////////////////////////////////////////////////////////////////////////////
// Natives
////////////////////////////////////////////////////////////////////////////////

public int Native_GetClientRagdoll(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (TTT_IsClientValid(client))
    {
        int userid = GetClientUserId(client);
        Ragdoll body;

        for (int i = 0; i < g_aRagdoll.Length; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));
            if (body.Victim == userid)
            {
                SetNativeArray(2, body, sizeof(body));
                return true;
            }
        }
    }

    return false;
}

public int Native_GetClientRagdollEntIndex(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (TTT_IsClientValid(client))
    {
        int userid = GetClientUserId(client);
        Ragdoll body;

        for (int i = 0; i < g_aRagdoll.Length; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));
            if (body.Victim == userid)
            {
                return EntRefToEntIndex(body.EntityRef);
            }
        }
    }

    return 0;
}

public int Native_GetEntityRefRagdoll(Handle plugin, int numParams)
{
    int entityref = GetNativeCell(1);
    if (IsValidEntity(EntRefToEntIndex(entityref)))
    {
        Ragdoll body;
        for (int i = 0; i < g_aRagdoll.Length; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));
            if (body.EntityRef == entityref)
            {
                SetNativeArray(2, body, sizeof(body));
                return true;
            }
        }
    }

    return false;
}

public int Native_GetClientByRagdollID(Handle plugin, int numParams)
{
    int ragdoll = GetNativeCell(1);
    if (IsValidEntity(ragdoll))
    {
        Ragdoll body;
        for (int i = 0; i < g_aRagdoll.Length; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));
            if (body.EntityRef == EntIndexToEntRef(ragdoll))
            {
                return GetClientOfUserId(body.Victim);
            }
        }
    }

    return -1;
}

public int Native_PushRagdoll(Handle plugin, int numParams)
{
    Ragdoll body;
    GetNativeArray(1, body, GetNativeCell(2));

    return g_aRagdoll.PushArray(body, GetNativeCell(2));
}

public int Native_SetRagdoll(Handle plugin, int numParams)
{
    Ragdoll body;
    GetNativeArray(1, body, GetNativeCell(2));

    bool found = false;

    for (int i = 0; i < g_aRagdoll.Length; ++i)
    {
        Ragdoll tmp;
        g_aRagdoll.GetArray(i, tmp);
        if (body.EntityRef == tmp.EntityRef)
        {
            g_aRagdoll.SetArray(i, body, sizeof(body));

            found = true;
            break;
        }
    }

    if (!found)
    {
        g_aRagdoll.PushArray(body, sizeof(body));
    }

    return found;
}

public int Native_WasBodyFound(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (TTT_IsClientValid(client))
    {
        int iSize = g_aRagdoll.Length;

        if (iSize == 0)
        {
            return false;
        }

        Ragdoll body;

        for (int i = 0; i < iSize; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));

            if (body.Victim == GetClientUserId(client))
            {
                return body.Found;
            }
        }
    }

    return false;
}

public int Native_WasBodyScanned(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (TTT_IsClientValid(client))
    {
        int iSize = g_aRagdoll.Length;

        if (iSize == 0)
        {
            return false;
        }

        Ragdoll body;

        for (int i = 0; i < iSize; ++i)
        {
            g_aRagdoll.GetArray(i, body, sizeof(body));

            if (body.Victim == GetClientUserId(client))
            {
                return body.Scanned;
            }
        }
    }

    return false;
}

public int Native_GetFoundStatus(Handle plugin, int numParams)
{
    return g_iPlayer[GetNativeCell(1)].Found;
}

public int Native_SetFoundStatus(Handle plugin, int numParams)
{
    g_iPlayer[GetNativeCell(1)].Found = GetNativeCell(2);

    return 0;
}

public int Native_CreateClientRagdoll(Handle plugin, int numParams)
{
    return CreateRagdoll(GetNativeCell(1));
}

public int Native_RemoveClientRagdoll(Handle plugin, int numParams)
{
    int userid = GetClientUserId(GetNativeCell(1));

    Ragdoll body;
    for (int i = 0; i < g_aRagdoll.Length; ++i)
    {
        g_aRagdoll.GetArray(i, body, sizeof(body));
        if (body.Victim == userid)
        {
            g_aRagdoll.Erase(i);

            if (g_bGrabberMod)
            {
                int iEnt = EntRefToEntIndex(body.EntityRef);
                
                TTT_ResetClientGrabByEntity(iEnt);
            }

            RequestFrame(Frame_RemoveBody, body.EntityRef);
        }
    }

    return 0;
}

public int Native_GetFoundArray(Handle plugin, int numParams)
{
    bool bFound[MAXPLAYERS + 1];

    for (int i = 0; i < sizeof(bFound); ++i)
    {
        bFound[i] = g_iPlayer[i].Found;
    }

    return SetNativeArray(1, bFound, GetNativeCell(2));
}

public int Native_RemoveRagdollFromArray(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    Ragdoll body;
    for (int i = 0; i < g_aRagdoll.Length; ++i)
    {
        g_aRagdoll.GetArray(i, body, sizeof(body));

        if (body.EntityRef == EntIndexToEntRef(entity))
        {
            g_aRagdoll.Erase(i);
            return true;
        }
    }

    return false;
}

////////////////////////////////////////////////////////////////////////////////
// Stocks
////////////////////////////////////////////////////////////////////////////////

void PrecacheGhosts()
{
    AddFileToDownloadsTable("particles/ghosts.pcf");
    AddFileToDownloadsTable("materials/effects/largesmoke.vmt");
    AddFileToDownloadsTable("materials/effects/largesmoke.vtf");
    AddFileToDownloadsTable("materials/effects/animatedeyes/animated_eyes.vmt");
    AddFileToDownloadsTable("materials/effects/animatedeyes/animated_eyes.vtf");

    PrecacheGeneric("particles/ghosts.pcf", true);

    PrecacheEffect("ParticleEffect");

    PrecacheParticleEffect("Ghost_Cyan");
    PrecacheParticleEffect("Ghost_Green");
    PrecacheParticleEffect("Ghost_Red");
    PrecacheParticleEffect("Ghost_Orange");
}

void PrecacheEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;

    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("EffectDispatch");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}

void PrecacheParticleEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;

    if (table == INVALID_STRING_TABLE)
    {
        table = FindStringTable("ParticleEffectNames");
    }
    bool save = LockStringTables(false);
    AddToStringTable(table, sEffectName);
    LockStringTables(save);
}

void RespawnParticle(int iEntity, const char[] sEffect)
{
    int iParticle = EntRefToEntIndex(g_iParticleRef[iEntity]);

    if (!IsValidEntity(iEntity) || !IsValidEntity(iParticle))
    {
        return;
    }

    AcceptEntityInput(iParticle, "DestroyImmediately");

    DataPack pack = new DataPack();
    pack.WriteCell(EntIndexToEntRef(iEntity));
    pack.WriteString(sEffect);
    RequestFrame(Frame_RespawnParticle, pack);
}

public void Frame_RespawnParticle(any pack)
{
    view_as<DataPack>(pack).Reset();
    int iEntity = EntRefToEntIndex(view_as<DataPack>(pack).ReadCell());
    int iParticle = EntRefToEntIndex(g_iParticleRef[iEntity]);

    char sEffect[16];
    view_as<DataPack>(pack).ReadString(sEffect, sizeof(sEffect));
    delete view_as<DataPack>(pack);

    if (!IsValidEntity(iEntity) || !IsValidEntity(iParticle))
    {
        return;
    }

    AcceptEntityInput(iParticle, "Kill");

    iParticle = CreateEntityByName("info_particle_system");

    if (!IsValidEntity(iParticle))
    {
        LogError("Can't create \"info_particle_system\"! Invalid entity index.");
        return;
    }

    if (g_cDebugMessages.BoolValue)
    {
        PrintToChatAll("Particle: %d", iParticle);
    }

    DispatchKeyValue(iParticle, "start_active", "1");
    DispatchKeyValue(iParticle, "effect_name", sEffect);

    if (DispatchSpawn(iParticle))
    {
        float fPosition[3];
        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition);
        fPosition[2] += 7.0;

        g_iParticleRef[iEntity] = EntIndexToEntRef(iParticle);

        TeleportEntity(iParticle, fPosition, NULL_VECTOR, NULL_VECTOR);
        ActivateEntity(iParticle);

        AcceptEntityInput(iEntity, "EnableMotion");

        DataPack pack2 = new DataPack();
        pack2.WriteCell(EntIndexToEntRef(iEntity));
        pack2.WriteCell(EntIndexToEntRef(iParticle));
        RequestFrame(Frame_SetParent, pack2);
    }
}

int CreateRagdoll(int client)
{
    int iEntity = -1;
    int iType = g_cSpawnType.IntValue;

    char sModel[128];
    GetClientModel(client, sModel, sizeof(sModel));

    bool bGhosts = false;

    if (iType == 0)
    {
        iEntity = CreateEntityByName("prop_ragdoll");

        if (!IsValidEntity(iEntity))
        {
            LogError("Can't create \"prop_ragdoll\"! Invalid entity index.");
            return -1;
        }
    }
    else if (iType == 1)
    {
        iEntity = CreateEntityByName("prop_physics_multiplayer");

        if (!IsValidEntity(iEntity))
        {
            LogError("Can't create \"prop_physics_multiplayer\"! Invalid entity index.");
            return -1;
        }
    }
    else if (iType == 2)
    {
        bGhosts = true;
    }

    if (!bGhosts)
    {
        if (!DispatchKeyValue(iEntity, "model", sModel))
        {
            LogError("Error with DispatchKeyValue and \"model\"");
            return -1;
        }

        char sBuffer[12];
        IntToString(view_as<int>(MOVETYPE_NONE), sBuffer, sizeof(sBuffer));
        if (!DispatchKeyValue(iEntity, "movetype", sBuffer))
        {
            LogError("Error with DispatchKeyValue and \"movetype\"");
            return -1;
        }

        char sName[32];
        Format(sName, sizeof(sName), "ragdoll_%d", GetClientUserId(client));
        DispatchKeyValue(iEntity, "targetname", sName);

        if (DispatchSpawn(iEntity))
        {
            float fOrigin[3];
            GetClientAbsOrigin(client, fOrigin);

            float fAngles[3];
            GetClientAbsAngles(client, fAngles);

            float fVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);

            // We didnt have to set it to a NULL_VECTOR here so just normalising
            // the velocity to match the max velocity we were checking for
            // beforehand, could lower this maybe too.
            float speed = GetVectorLength(fVelocity);
            if (speed >= 500.0)
            {
                NormalizeVector(fVelocity, fVelocity);
                ScaleVector(fVelocity, Min(speed, 500.0));
            }
            TeleportEntity(iEntity, fOrigin, fAngles, fVelocity);

            ActivateEntity(iEntity);
            SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
            SetEntProp(iEntity, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
            AcceptEntityInput(iEntity, "EnableMotion");
            SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
        }
    }
    else
    {
        iEntity = CreateEntityByName("prop_physics_multiplayer");

        if (!IsValidEntity(iEntity))
        {
            LogError("Can't create \"prop_physics_multiplayer\"! Invalid entity index.");
            return -1;
        }

        if (g_cDebugMessages.BoolValue)
        {
            PrintToChatAll("Entity: %d", iEntity);
        }

        char sName[32];
        Format(sName, sizeof(sName), "ragdoll_%d", GetClientUserId(client));
        DispatchKeyValue(iEntity, "targetname", sName);
        DispatchKeyValue(iEntity, "model", "models/" ... MODEL_MICROWAVE);
        DispatchKeyValue(iEntity, "rendermode", "2");
        DispatchKeyValue(iEntity, "renderamt", "0");
        SetEntProp(iEntity, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
        SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);

        if (DispatchSpawn(iEntity))
        {
            float fPosition[3];
            GetClientAbsOrigin(client, fPosition);
            fPosition[2] -= 40.0;
            TeleportEntity(iEntity, fPosition, NULL_VECTOR, NULL_VECTOR);

            int iParticle = CreateEntityByName("info_particle_system");

            if (!IsValidEntity(iParticle))
            {
                LogError("Can't create \"info_particle_system\"! Invalid entity index.");
                return -1;
            }

            if (g_cDebugMessages.BoolValue)
            {
                PrintToChatAll("Particle: %d (Ref: %d)", iParticle, EntIndexToEntRef(iParticle));
            }

            DispatchKeyValue(iParticle, "start_active", "0");
            DispatchKeyValue(iParticle, "effect_name", "Ghost_Orange");

            if (DispatchSpawn(iParticle))
            {
                fPosition[2] += 7.0;
                TeleportEntity(iParticle, fPosition, NULL_VECTOR, NULL_VECTOR);
                ActivateEntity(iParticle);

                g_iParticleRef[iEntity] = EntIndexToEntRef(iParticle);

                AcceptEntityInput(iEntity, "EnableMotion");

                DataPack pack = new DataPack();
                pack.WriteCell(EntIndexToEntRef(iEntity));
                pack.WriteCell(EntIndexToEntRef(iParticle));
                RequestFrame(Frame_SetParent, pack);
            }
        }
    }

    if (g_cSpawnType.IntValue == 0)
    {
        SetEntPropEnt(client, Prop_Send, "m_hRagdoll", iEntity);
    }
    else if (g_cSpawnType.IntValue == 1 || g_cSpawnType.IntValue == 2)
    {
        SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);
    }

    return iEntity;
}

public void Frame_SetParent(any pack)
{
    view_as<DataPack>(pack).Reset();
    int iEntity = EntRefToEntIndex(view_as<DataPack>(pack).ReadCell());
    int iParticleRef = view_as<DataPack>(pack).ReadCell();
    int iParticle = EntRefToEntIndex(iParticleRef);
    delete view_as<DataPack>(pack);

    if (!IsValidEntity(iEntity) || !IsValidEntity(iParticle))
    {
        return;
    }

    AcceptEntityInput(iParticle, "Start");
    SetVariantEntity(iEntity);

    SetVariantString("!activator");
    AcceptEntityInput(iParticle, "SetParent", iEntity, iParticle, 0);
}

void IdentifyEntity(int client, int button = 0, bool skip = false)
{
    g_iPlayer[client].IsChecking = true;

    int iIndex = -1;
    int iEntity = -1;

    int iSize = g_aRagdoll.Length;
    if (iSize == 0)
    {
        return;
    }

    // Loop through all ragdolls to find the closest ragdoll to the client that
    // is within ID range.
    // @TODO should add a check to see that the ragdoll is visible.
    float fMaxDistance = g_cIdentifyDistance.FloatValue;

    Ragdoll body;
    for (int i = 0; i < iSize; ++i)
    {
        g_aRagdoll.GetArray(i, body, sizeof(body));
        iEntity = EntRefToEntIndex(body.EntityRef);

        if (!IsValidEntity(iEntity))
        {
            g_aRagdoll.Erase(i);
            return;
        }

        static float fEntityPosition[3];
        static float fTargetPosition[3];

        GetClientEyePosition(client, fTargetPosition);
        GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityPosition);

        float dist = GetVectorDistance(fTargetPosition, fEntityPosition, false);
        //PrintToConsole(client, "ragdoll enitiy %d (distance: %f)", iEntity, dist);
        if (dist <= fMaxDistance)
        {
            iIndex = i;
            fMaxDistance = dist;
        }
    }

    //PrintToConsole(client, "found ragdoll %d (distance: %f)", iIndex, fMaxDistance);

    if (iIndex >= 0)
    {
        g_aRagdoll.GetArray(iIndex, body, sizeof(body));
        iEntity = EntRefToEntIndex(body.EntityRef);

        if (body.VictimRole == TTT_TEAM_UNASSIGNED)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Invalid Ragdoll", client);

            RequestFrame(Frame_RemoveBody, body.EntityRef);

            g_aRagdoll.Erase(iIndex);

            return;
        }

        if (IsPlayerAlive(client))
        {
            Action res = Plugin_Continue;

            Call_StartForward(g_fwOnBodyCheck);
            Call_PushCell(client);
            Call_PushCell(body.EntityRef);
            Call_Finish(res);

            if (res == Plugin_Stop || res == Plugin_Handled)
            {
                return;
            }
            else if (res == Plugin_Changed)
            {
                // We  must update the body here, otherwise we run in some conflicts.
                g_aRagdoll.GetArray(iIndex, body, sizeof(body));
            }

            int victim = GetClientOfUserId(body.Victim);
            int attacker = GetClientOfUserId(body.Attacker);

            if (g_cDebugMessages.BoolValue)
            {
                LogMessage("Victim: %d, Victim (UserID): %d, Attacker: %d, Attacker (UserID): %d", victim, body.Victim, attacker, body.Attacker);
            }

            InspectBody(client, victim, body.VictimRole, attacker, RoundToNearest(GetGameTime() - body.GameTime), body.Weaponused, body.VictimName);

            if (!body.Found)
            {
                bool bInWalk = ((button & IN_SPEED) > 0);
                bool silentID = false;

                body.Found = true;

                bool bValidVictim = TTT_IsClientValid(victim);

                if (bValidVictim)
                {
                    g_iPlayer[victim].Found = true;
                }

                char sAttackerID[32], sClientID[32];

                if (g_cAddSteamIDtoLogs.BoolValue)
                {
                    if (g_cSteamIDLogFormat.IntValue == 1)
                    {
                        GetClientAuthId(client, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
                        if (victim > 0 && !GetClientAuthId(victim, AuthId_Steam2, sClientID, sizeof(sClientID)))
                        {
                            Format(sClientID, sizeof(sClientID), "DISCONNECTED");
                        }
                    }
                    else if (g_cSteamIDLogFormat.IntValue == 2)
                    {
                        GetClientAuthId(client, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
                        if (victim > 0 && !GetClientAuthId(victim, AuthId_Steam3, sClientID, sizeof(sClientID)))
                        {
                            Format(sClientID, sizeof(sClientID), "DISCONNECTED");
                        }
                    }
                    else if (g_cSteamIDLogFormat.IntValue == 3)
                    {
                        GetClientAuthId(client, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
                        if (victim > 0 && !GetClientAuthId(victim, AuthId_SteamID64, sClientID, sizeof(sClientID)))
                        {
                            Format(sClientID, sizeof(sClientID), "DISCONNECTED");
                        }
                    }
                    else if (g_cSteamIDLogFormat.IntValue == 4)
                    {
                        Format(sAttackerID, sizeof(sAttackerID), "%d", GetSteamAccountID(client));
                        if (victim > 0 && !IsClientInGame(victim))
                        {
                            Format(sClientID, sizeof(sClientID), "DISCONNECTED");
                        }
                        else
                        {
                            Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(victim));
                        }
                    }

                    if (strlen(sAttackerID) > 2)
                    {
                        Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
                    }

                    if (strlen(sClientID) > 2)
                    {
                        Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
                    }
                }

                char iItem[TTT_LOG_SIZE];

                char sRole[ROLE_LENGTH];
                TTT_GetRoleNameByID(TTT_GetClientRole(client), sRole, sizeof(sRole));

                char sVictimRole[ROLE_LENGTH];
                TTT_GetRoleNameByID(body.VictimRole, sVictimRole, sizeof(sVictimRole));

                bool bSetColor = false;

                if (!StrEqual(body.Weaponused, "Fake!", false))
                {
                    char sClientName[MAX_NAME_LENGTH];
                    TTT_GetClientName(client, sClientName, sizeof(sClientName));

                    if (!g_cSilentIdEnabled.BoolValue || !(bInWalk && TTT_IsValidRole(client, g_cSilentIdRoles.IntValue)))
                    {
                        char sBuffer[32];
                        Format(sBuffer, sizeof(sBuffer), "Found %s", sVictimRole);

                        LoopValidClients(j)
                        {
                            CPrintToChat(j, "%s %T", g_sPluginTag, sBuffer, j, sClientName, body.VictimName);
                        }

                        Format(iItem, sizeof(iItem), "-> %s (%s) identified body of %s%s (%s)", sClientName, sRole, body.VictimName, sClientID, sVictimRole);

                        bSetColor = true;
                    }
                    else
                    {
                        char sBuffer[32];
                        Format(sBuffer, sizeof(sBuffer), "Found %s Silent", sVictimRole);

                        CPrintToChat(client, "%s %T", g_sPluginTag, sBuffer, client, body.VictimName);

                        Format(iItem, sizeof(iItem), "-> %s (%s) identified body of %s%s (%s) - SILENT", sClientName, sRole, body.VictimName, sClientID, sVictimRole);

                        if (g_cSilentIdColor.BoolValue)
                        {
                            bSetColor = true;
                        }

                        silentID = true;
                    }
                }
                else
                {
                    bSetColor = true;
                }

                if (bSetColor)
                {
                    if (g_cSpawnType.IntValue == 2)
                    {
                        char sClass[32];
                        if (IsValidEntity(iEntity) && GetEntityClassname(iEntity, sClass, sizeof(sClass)))
                        {
                            if (StrContains(sClass, "prop_", false) != -1)
                            {
                                skip = true;
                            }
                        }
                    }

                    if (body.VictimRole == TTT_TEAM_INNOCENT)
                    {
                        if (!skip)
                        {
                            SetEntityRenderColor(iEntity, 0, 255, 0, 255);
                        }
                        else
                        {
                            RespawnParticle(iEntity, "Ghost_Green");
                        }
                    }
                    else if (body.VictimRole== TTT_TEAM_DETECTIVE)
                    {
                        if (!skip)
                        {
                            SetEntityRenderColor(iEntity, 0, 0, 255, 255);
                        }
                        else
                        {
                            RespawnParticle(iEntity, "Ghost_Cyan");
                        }
                    }
                    else if (body.VictimRole == TTT_TEAM_TRAITOR)
                    {
                        if (!skip)
                        {
                            SetEntityRenderColor(iEntity, 255, 0, 0, 255);
                        }
                        else
                        {
                            RespawnParticle(iEntity, "Ghost_Red");
                        }
                    }
                }

                if (g_cIdentifyLog.BoolValue)
                {
                    TTT_LogString(iItem);
                }

                Call_StartForward(g_fwOnBodyFound);
                Call_PushCell(client);

                if (bValidVictim)
                {
                    Call_PushCell(victim);
                }
                else
                {
                    Call_PushCell(-1);
                }

                Call_PushCell(body.VictimRole);
                Call_PushCell(body.AttackerRole);
                Call_PushCell(body.EntityRef);
                Call_PushCell(silentID);
                Call_Finish();
            }

            g_aRagdoll.SetArray(iIndex, body, sizeof(body));
        }
    }
}

void InspectBody(int client, int victim, int victimRole, int attacker, int time, const char[] weapon, const char[] victimName)
{
    static char team[64];
    if (victimRole == TTT_TEAM_TRAITOR)
    {
        strcopy(team, sizeof(team), "<font color=\"#FF0000\">Traitor</font>");
    }
    else if (victimRole == TTT_TEAM_DETECTIVE)
    {
        strcopy(team, sizeof(team), "<font color=\"#0000FF\">Detective</font>");
    }
    else if (victimRole == TTT_TEAM_INNOCENT)
    {
        strcopy(team, sizeof(team), "<font color=\"#00FF00\">Innocent</font>");
    }
    else
    {
        strcopy(team, sizeof(team), "None");
    }

    char sBuffer[MAX_MESSAGE_LENGTH];
    if (TTT_GetClientRole(client) == TTT_TEAM_DETECTIVE)
    {
        static char sTime[128];
        static char sWeaponUsed[128];
        Format(sTime, sizeof(sTime), "%T", "Elapsed since their death", client, time);
        if (attacker > 0 && attacker != victim)
        {
            Format(sWeaponUsed, sizeof(sWeaponUsed), "%T", "The weapon used has been", client, weapon);
        }
        else
        {
            Format(sWeaponUsed, sizeof(sWeaponUsed), "%T", "The weapon used has been: themself (suicide)", client);
        }
        
        Format(sBuffer, sizeof(sBuffer), "<center><pre><font color=\"#FFFFFF\"><font size=\"48\">%s (%s)</font>\n<font size=\"32\">%s\n%s</font></font></pre></center>", victimName, team, sTime, sWeaponUsed);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "<center><pre><font color=\"#FFFFFF\"><font size=\"48\">%s (%s)</font></font></pre></center>", victimName, team);
    }
    PrintCenterTextCustom(client, sBuffer);
}

public int Menu_BodyInspect(Menu menu, MenuAction action, int client, int itemNum)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public void Frame_RemoveBody(any ref)
{
    int iRagdoll = EntRefToEntIndex(ref);

    if (iRagdoll > 0)
    {
        if (g_cSpawnType.IntValue == 0 || g_cSpawnType.IntValue == 1)
        {
            AcceptEntityInput(iRagdoll, "Kill");
        }
        else
        {
            int iParticle = EntRefToEntIndex(g_iParticleRef[iRagdoll]);

            if (IsValidEntity(iParticle))
            {
                AcceptEntityInput(iParticle, "DestroyImmediately");
            }
            
            if (IsValidEntity(iRagdoll))
            {
                AcceptEntityInput(iRagdoll, "Kill");
            }
        }
    }
}

float Min(float x, float y)
{
    return x < y ? x : y;
}

void PrintCenterTextCustom(int client, const char[] message)
{
    static char sBuffer[2048];
    Format(sBuffer, sizeof(sBuffer), "</font>     %s\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", message);
    Protobuf pbMessage = view_as<Protobuf>(StartMessageOne("TextMsg", client));
    pbMessage.SetInt("msg_dst", 4);
    pbMessage.AddString("params", "#SFUI_ContractKillStart");
    pbMessage.AddString("params", sBuffer);
    pbMessage.AddString("params", NULL_STRING);
    pbMessage.AddString("params", NULL_STRING);
    pbMessage.AddString("params", NULL_STRING);
    pbMessage.AddString("params", NULL_STRING);
    
    EndMessage();
}
