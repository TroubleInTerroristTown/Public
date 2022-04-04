#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ttt>
#include <colorlib>
#include <emitsoundany>

#undef REQUIRE_PLUGIN
#include <customkeyvalues>
#include <ttt_knockout>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Grabber Mod"

ConVar g_cColored = null;
ConVar g_cBlockJump = null;
ConVar g_cShowNames = null;
ConVar g_cGrabAlive = null;
ConVar g_cGrabNonMoveAlive = null;
ConVar g_cLogBlacklist = null;
ConVar g_cLogBlacklistModels = null;
ConVar g_cLogWhitelist = null;
ConVar g_cFlags = null;
ConVar g_cBlockPush = null;
ConVar g_cGrabSound = null;
ConVar g_cGrabSoundVol = null;
ConVar g_cThrowSound = null;
ConVar g_cThrowSoundVol = null;
ConVar g_cGrabDistance = null;
ConVar g_cAllowThrow = null;
ConVar g_cThrowForce = null;
ConVar g_cReloadFlag = null;
ConVar g_cAllowFreeze = null;
ConVar g_cGrabButton = null;
ConVar g_cMultiGrab = null;
ConVar g_cDebug = null;
ConVar g_cIdentifyDistance = null;

int g_iSprite = -1;

ArrayList g_aWhitelist = null;
ArrayList g_aBlacklist = null;
ArrayList g_aBlacklistModels = null;
ArrayList g_aBlocklist = null;

GlobalForward g_fwOnGrabbing = null;

bool g_bCustomKeyValues = false;

enum struct PlayerData {
    int Object;
    float Distance;
    float Time;
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
    g_fwOnGrabbing = new GlobalForward("TTT_OnGrabbing", ET_Event, Param_Cell, Param_Cell);

    CreateNative("TTT_GetClientGrabEntity", Native_GetClientGrabEntity);
    CreateNative("TTT_ResetClientGrab", Native_ResetClientGrab);
    CreateNative("TTT_GetEntityGrabber", Native_GetEntityGrabber);
    CreateNative("TTT_ResetClientGrabByEntity", Native_ResetClientGrabByEntity);

    RegPluginLibrary("ttt_grabbermod");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_StartConfig("grabbermod");
    CreateConVar("ttt2_grabbermod_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLogWhitelist = AutoExecConfig_CreateConVar("gbm_log_whitelist", "1", "Log whitelist?", _, true, 0.0, true, 1.0);
    g_cLogBlacklist = AutoExecConfig_CreateConVar("gbm_log_blacklist", "1", "Log blacklist?", _, true, 0.0, true, 1.0);
    g_cLogBlacklistModels = AutoExecConfig_CreateConVar("gbm_log_blacklist_models", "1", "Log blacklist models?", _, true, 0.0, true, 1.0);
    g_cColored = AutoExecConfig_CreateConVar("gbm_colored", "1", "Colored laser beam for grab (new color every second)?", _, true, 0.0, true, 1.0);
    g_cBlockJump = AutoExecConfig_CreateConVar("gbm_block_jump", "1", "Block jump on \"grabbed\" entities to prevent abusing?", _, true, 0.0, true, 1.0);
    g_cGrabAlive = AutoExecConfig_CreateConVar("gbm_grab_alive", "0", "Grab living players?", _, true, 0.0, true, 1.0);
    g_cGrabNonMoveAlive = AutoExecConfig_CreateConVar("gbm_grab_non_move_alive", "0", "Grab living non moveable players?", _, true, 0.0, true, 1.0);
    g_cShowNames = AutoExecConfig_CreateConVar("gbm_show_name", "0", "Show names of entities? Useful to add this on blacklist(models)/whitelist.", _, true, 0.0, true, 1.0);
    g_cFlags = AutoExecConfig_CreateConVar("gbm_admin_flags", "z", "Admin flags to get access for gbm_show_name");
    g_cBlockPush = AutoExecConfig_CreateConVar("gbm_block_push_props", "1", "Block props with the MoveType MOVETYPE_PUSH (no clip to world, push and crush)?", _, true, 0.0, true, 1.0);
    g_cGrabSound = AutoExecConfig_CreateConVar("gbm_on_grab_sound", "ui/item_drop.wav", "Sound when player grab something (blank = disabled)");
    g_cGrabSoundVol = AutoExecConfig_CreateConVar("gbm_on_grab_sound_volume", "0.1", "Volume of the grab sound", _, true, 0.1, true, 1.0);
    g_cThrowSound = AutoExecConfig_CreateConVar("gbm_on_throw_sound", "weapons/hegrenade/grenade_throw.wav", "Sound when player throw a prop (blank = disabled)");
    g_cThrowSoundVol = AutoExecConfig_CreateConVar("gbm_on_throw_sound_volume", "1.0", "Volume of the throw sound", _, true, 0.1, true, 1.0);
    g_cGrabDistance = AutoExecConfig_CreateConVar("gbm_grab_distance", "150.0", "How long should be max the grab distance?");
    g_cAllowThrow = AutoExecConfig_CreateConVar("gbm_allow_throw", "1", "Allow throwing of props?", _, true, 0.0, true, 1.0);
    g_cThrowForce = AutoExecConfig_CreateConVar("gbm_throw_force", "1000.0", "How strong should the throw of a prop?");
    g_cReloadFlag = AutoExecConfig_CreateConVar("gbm_reload_flag", "z", "Admin flags to reload the white/blacklist");
    g_cAllowFreeze = AutoExecConfig_CreateConVar("gbm_allow_freeze", "1", "Allow freeze while grabbing?", _, true, 0.0, true, 1.0);
    g_cGrabButton = AutoExecConfig_CreateConVar("gbm_grab_button", "5", "To change the grab button, take the number after \"<<\" (as example 5 for IN_USE/E) from this list:\nhttps://github.com/alliedmodders/sourcemod/blob/cfa4998ac1203f14464598c5454710a7faebada4/plugins/include/entity_prop_stocks.inc#L100-L125");
    g_cMultiGrab = AutoExecConfig_CreateConVar("gbm_allow_multi_grab", "0", "Allow players to grab 1 entity 2 times or more", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
    
    LoadLists();

    RegConsoleCmd("sm_reloadgrablist", Command_ReloadGrablist);

    delete g_aBlocklist;
    g_aBlocklist = new ArrayList();

    g_bCustomKeyValues = LibraryExists("CustomKeyValues");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "CustomKeyValues"))
    {
        g_bCustomKeyValues = false;
    }
}

public void OnMapStart()
{
    g_iSprite = PrecacheModel("materials/sprites/laserbeam.vmt");

    char sBuffer[PLATFORM_MAX_PATH + 1];
    g_cGrabSound.GetString(sBuffer, sizeof(sBuffer));
    PrecacheSoundAny(sBuffer, true);

    g_cThrowSound.GetString(sBuffer, sizeof(sBuffer));
    PrecacheSoundAny(sBuffer, true);
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_debug_mode");
    g_cIdentifyDistance = FindConVar("ttt_identify_max_distance");
}

public void TTT_OnRoundStart()
{
    delete g_aBlocklist;
    g_aBlocklist = new ArrayList();
}

public Action Command_ReloadGrablist(int client, int args)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!TTT_CheckCommandAccess(client, "sm_reloadgrablist", g_cReloadFlag, true))
    {
        return Plugin_Handled;
    }

    LoadLists();

    ReplyToCommand(client, "White/Blacklist reloaded!");

    return Plugin_Continue;
}

void Command_Grab(int client)
{
    GrabSomething(client);
}

void Command_UnGrab(int client)
{
    if (ValidGrab(client))
    {
        char sName[128];
        GetEdictClassname(EntRefToEntIndex(g_iPlayer[client].Object), sName, sizeof(sName));

        if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox") || StrEqual(sName, "prop_physics"))
        {
            SetEntPropEnt(EntRefToEntIndex(g_iPlayer[client].Object), Prop_Data, "m_hPhysicsAttacker", 0);
        }
    }

    g_iPlayer[client].Object = -1;
    SDKUnhook(client, SDKHook_PreThink, OnPreThink);
    g_iPlayer[client].Time = 0.0;
}

void GrabSomething(int client)
{
    if (!g_cDebug.BoolValue && TTT_GetRoundStatus() != Round_Active)
    {
        return;
    }

    int iEntity = -1;
    float fEntityPos[3], fClientPos[3];

    iEntity = GetObject(client, false);

    if (iEntity == -1)
    {
        return;
    }

    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityPos);
    GetClientEyePosition(client, fClientPos);
    if (GetVectorDistance(fEntityPos, fClientPos, false) > g_cGrabDistance.FloatValue)
    {
        return;
    }

    if (!g_cMultiGrab.BoolValue)
    {
        LoopValidClients(i)
        {
            if (i != client && g_iPlayer[client].Object == EntIndexToEntRef(iEntity))
            {
                return;
            }
        }
    }

    if (g_bCustomKeyValues)
    {
        char sCustom[4];
        bool success = GetCustomKeyValue(iEntity, "ttt_allow_grabbing", sCustom, sizeof(sCustom));

        if (success)
        {
            if (!view_as<bool>(StringToInt(sCustom)))
            {
                return;
            }
        }

        success = GetCustomKeyValue(iEntity, "ttt_traitor_only", sCustom, sizeof(sCustom));

        if (success)
        {
            if (view_as<bool>(StringToInt(sCustom)) && TTT_GetClientRole(client) != TTT_TEAM_TRAITOR)
            {
                return;
            }
        }
    }

    char sName[128];
    GetEdictClassname(iEntity, sName, sizeof(sName));

    if (g_aBlocklist.FindValue(EntIndexToEntRef(iEntity)) != -1)
    {
        return;
    }
    
    // We block doors and buttons by default
    if (StrContains(sName, "door", false) != -1 || StrContains(sName, "button", false) != -1 || StrContains(sName, "_player", false) != -1)
    {
        return;
    }

    Action res = Plugin_Continue;
    Call_StartForward(g_fwOnGrabbing);
    Call_PushCell(client);
    Call_PushCell(iEntity);
    Call_Finish(res);

    if (res == Plugin_Handled || res == Plugin_Stop)
    {
        return;
    }
    
    // true is a positive found on the blacklist(models) or negative found on the whitelist 
    if (CheckLists(client, iEntity, sName))
    {
        return;
    }

    char sGlobal[128];
    char sTargetname[32];
    GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
    GetEntPropString(iEntity, Prop_Data, "m_iGlobalname", sGlobal, sizeof(sGlobal));

    if (strlen(sGlobal) > 1 && CheckLists(client, iEntity, sGlobal))
    {
        return;
    }

    if (strlen(sTargetname) > 1 && CheckLists(client, iEntity, sTargetname))
    {
        return;
    }

    if (g_cShowNames.BoolValue)
    {
        if (TTT_CheckCommandAccess(client, "gbm_output", g_cFlags, true))
        {
            CPrintToChat(client, "Name of Entity: %s (GetEdictClassname), %s (m_iGlobalname), %s (m_iName)", sName, sGlobal, sTargetname);
        }
    }

    if (g_cBlockPush.BoolValue && GetEntityMoveType(iEntity) == MOVETYPE_PUSH)
    {
        return;
    }
    
    if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox"))
    {
        if (IsValidEntity(iEntity))
        {
            iEntity = ReplacePhysicsEntity(iEntity);

            SetEntPropEnt(iEntity, Prop_Data, "m_hPhysicsAttacker", client);
            SetEntPropFloat(iEntity, Prop_Data, "m_flLastPhysicsInfluenceTime", GetEngineTime());
        }
    }
    
    if (StrContains(sName, "ragdoll", false) != -1 || StrContains(sName, "player", false) != -1)
    {
        // true is a positive found on the blacklist(models) or negative found on the whitelist 
        if (CheckLists(client, iEntity, sTargetname) || StrContains(sTargetname, "fpd_ragdoll", false) != -1)
        {
            return;
        }

        // This check should fix this crash bug: https://youtu.be/GbpkerPoO7g
        if (GetVectorDistance(fEntityPos, fClientPos, false) > g_cIdentifyDistance.FloatValue - 5.0)
        {
            return;
        }
    }
    
    if (!g_cGrabAlive.BoolValue)
    {
        if (TTT_IsClientValid(iEntity) && IsPlayerAlive(iEntity))
        {
            if (!g_cGrabNonMoveAlive.BoolValue || (g_cGrabNonMoveAlive.BoolValue && GetEntityMoveType(iEntity) != MOVETYPE_NONE))
            {
                return;
            }
        }
    }

    if (GetEntityMoveType(iEntity) == MOVETYPE_NONE)
    {
        if (strncmp("player", sName, 5, false) != 0)
        {
            SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
            AcceptEntityInput(iEntity, "EnableMotion");
            PrintHintText(client, "Object ist now Unfreezed");
        }
        else
        {
            SetEntityMoveType(iEntity, MOVETYPE_WALK);
            return;
        }
    }

    g_iPlayer[client].Object = EntIndexToEntRef(iEntity);
    SDKHook(client, SDKHook_PreThink, OnPreThink);

    char sSound[PLATFORM_MAX_PATH + 1];
    g_cGrabSound.GetString(sSound, sizeof(sSound));

    if (strlen(sSound) > 0)
    {
        EmitSoundToClientAny(client, sSound, _, _, _, _, g_cGrabSoundVol.FloatValue);
    }

    g_iPlayer[client].Distance = GetVectorDistance(fEntityPos, fClientPos, false);

    float position[3];
    TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, position);
}

bool ValidGrab(int client)
{
    int iObject = EntRefToEntIndex(g_iPlayer[client].Object);
    if (iObject > 0 && IsValidEntity(iObject))
    {
        return true;
    }
    return false;
}

int GetObject(int client, bool hitSelf=true)
{
    int iEntity = -1;

    if (TTT_IsClientValid(client))
    {
        if (ValidGrab(client))
        {
            iEntity = EntRefToEntIndex(g_iPlayer[client].Object);
            return iEntity;
        }

        iEntity = TraceToEntity(client);

        if (IsValidEntity(iEntity))
        {
            char sName[64];
            GetEdictClassname(iEntity, sName, sizeof(sName));
            if (StrEqual(sName, "worldspawn"))
            {
                if (hitSelf)
                {
                    iEntity = client;
                }
                else
                {
                    iEntity = -1;
                }
            }
        }
        else
        {
            iEntity = -1;
        }
    }

    return iEntity;
}

public int TraceToEntity(int client)
{
    float fEyePos[3], fEyeAngle[3];
    GetClientEyePosition(client, fEyePos);
    GetClientEyeAngles(client, fEyeAngle);

    TR_TraceRayFilter(fEyePos, fEyeAngle, MASK_PLAYERSOLID, RayType_Infinite, TraceASDF, client);

    if (TR_DidHit(null))
    {
        return TR_GetEntityIndex(null);
    }

    return -1;
}

int ReplacePhysicsEntity(int iEntity)
{
    float fOrigin[3], fAngle[3];

    char model[128];
    GetEntPropString(iEntity, Prop_Data, "m_ModelName", model, sizeof(model));
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
    GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngle);
    AcceptEntityInput(iEntity, "Wake");
    AcceptEntityInput(iEntity, "EnableMotion");
    AcceptEntityInput(iEntity, "EnableDamageForces");
    DispatchKeyValue(iEntity, "physdamagescale", "0.0");

    TeleportEntity(iEntity, fOrigin, fAngle, NULL_VECTOR);
    SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);

    return iEntity;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (buttons & IN_JUMP)
    {
        if (g_cBlockJump.BoolValue)
        {
            int iEnt = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");

            if (IsValidEntity(iEnt))
            {
                char sName[128];
                GetEdictClassname(iEnt, sName, sizeof(sName));

                if (StrContains(sName, "prop_", false) == -1 || StrContains(sName, "door", false) != -1)
                {
                    return Plugin_Continue;
                }
                else
                {
                    if (StrEqual(sName, "prop_physics") || StrEqual(sName, "prop_physics_multiplayer") || StrEqual(sName, "func_physbox") || StrEqual(sName, "prop_physics"))
                    {
                        buttons &= ~IN_JUMP;
                        return Plugin_Changed;
                    }
                }
            }
        }
    }

    if (buttons & (1<<g_cGrabButton.IntValue))
    {
        if (IsPlayerAlive(client) && !ValidGrab(client))
        {
            Command_Grab(client);
        }
        else if (IsPlayerAlive(client) && ValidGrab(client))
        {
            if (g_cAllowFreeze.BoolValue && buttons & IN_ATTACK)
            {
                buttons &= ~IN_ATTACK;
                buttons &= ~(1<<g_cGrabButton.IntValue);

                int iEntity = EntRefToEntIndex(g_iPlayer[client].Object);
                SetEntityMoveType(iEntity, MOVETYPE_NONE);
                AcceptEntityInput(iEntity, "DisableMotion");

                TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));

                g_aBlocklist.Push(g_iPlayer[client].Object);

                CreateTimer(1.0, Timer_Unblock, g_iPlayer[client].Object);

                Command_UnGrab(client);

                return Plugin_Changed;
            }

            if (g_cAllowThrow.BoolValue && buttons & IN_ATTACK2)
            {
                buttons &= ~IN_ATTACK2;
                buttons &= ~(1<<g_cGrabButton.IntValue);

                ThrowObject(client);

                return Plugin_Changed;
            }
        }
    }
    else if (ValidGrab(client))
    {
        Command_UnGrab(client);
    }

    return Plugin_Continue;
}

public Action Timer_Unblock(Handle timer, any refIndex)
{
    int iIndex = g_aBlocklist.FindValue(refIndex);

    if (iIndex != -1)
    {
        g_aBlocklist.Erase(iIndex);
    }
    
    return Plugin_Handled;
}

// public Action Timer_Adjust(Handle timer)
public void OnPreThink(int i)
{
    float vecDir[3];
    float vecPos[3];
    float vecPos2[3];
    float vecVel[3];
    float viewang[3];

    // LoopValidClients(i)
    // {
    if (IsPlayerAlive(i))
    {
        if (ValidGrab(i))
        {
            GetClientEyeAngles(i, viewang);
            GetAngleVectors(viewang, vecDir, NULL_VECTOR, NULL_VECTOR);
            GetClientEyePosition(i, vecPos);

            int color[4];

            if (g_cColored.BoolValue)
            {
                if (g_iPlayer[i].Time == 0.0 || GetGameTime() < g_iPlayer[i].Time)
                {
                    color[0] = GetRandomInt(0, 255);
                    color[1] = GetRandomInt(0, 255);
                    color[2] = GetRandomInt(0, 255);
                    color[3] = 255;
                }
            }
            else
            {
                color[0] = 255;
                color[1] = 0;
                color[2] = 0;
                color[3] = 255;
            }

            vecPos2 = vecPos;
            vecPos[0] += vecDir[0] * g_iPlayer[i].Distance;
            vecPos[1] += vecDir[1] * g_iPlayer[i].Distance;
            vecPos[2] += vecDir[2] * g_iPlayer[i].Distance;

            int iEntity = EntRefToEntIndex(g_iPlayer[i].Object);

            GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecDir);

            if (!IsNullVector(vecPos2) && !IsNullVector(vecDir))
            {
                TE_SetupBeamPoints(vecPos2, vecDir, g_iSprite, 0, 0, 0, 0.1, 3.0, 3.0, 10, 0.0, color, 0);
                TE_SendToAll();
            }

            g_iPlayer[i].Time = GetGameTime() + 1.0;

            SubtractVectors(vecPos, vecDir, vecVel);
            ScaleVector(vecVel, 10.0);

            TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, vecVel);
        }
        else
        {
            Command_UnGrab(i);
        }
    }
    // }
}

public void OnClientDisconnect(int client)
{
    Command_UnGrab(client);
}

void LoadLists()
{
    if (g_aWhitelist == null)
    {
        g_aWhitelist = new ArrayList(32);
    }
    else
    {
        g_aWhitelist.Clear();
    }

    if (g_aBlacklist == null)
    {
        g_aBlacklist = new ArrayList(32);
    }
    else
    {
        g_aBlacklist.Clear();
    }

    if (g_aBlacklistModels == null)
    {
        g_aBlacklistModels = new ArrayList(PLATFORM_MAX_PATH + 1);
    }
    else
    {
        g_aBlacklistModels.Clear();
    }

    LoadWhitelist();
    LoadBlacklist();
    LoadBlacklistModels();
}

void LoadWhitelist()
{
    char sPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/whitelist_grabbermod.ini");

    File hFile = OpenFile(sPath, "rt");

    if (!FileExists(sPath))
    {
        SetFailState("Can't find the following file: \"configs/ttt/whitelist_grabbermod.ini\"");
        return;
    }
    
    char sBuffer[32];
    while(!hFile.EndOfFile() && hFile.ReadLine(sBuffer, sizeof(sBuffer)))
    {
        TrimString(sBuffer);
        
        if (strlen(sBuffer) > 2)
        {
            g_aWhitelist.PushString(sBuffer);
            
            if (g_cLogWhitelist.BoolValue)
            {
                LogMessage("[GrabberMod] (LoadWhitelist) Add %s to array...", sBuffer);
            }
        }
    }
    
    delete hFile;
}

void LoadBlacklist()
{
    char sPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/blacklist_grabbermod.ini");

    File hFile = OpenFile(sPath, "rt");

    if (!FileExists(sPath))
    {
        SetFailState("Can't find the following file: \"configs/ttt/blacklist_grabbermod.ini\"");
        return;
    }
    
    char sBuffer[32];
    while(!hFile.EndOfFile() && hFile.ReadLine(sBuffer, sizeof(sBuffer)))
    {
        TrimString(sBuffer);
        
        if (strlen(sBuffer) > 2)
        {
            g_aBlacklist.PushString(sBuffer);
            
            if (g_cLogBlacklist.BoolValue)
            {
                LogMessage("[GrabberMod] (LoadBlacklist) Add %s to array...", sBuffer);
            }
        }
    }
    
    delete hFile;
}

void LoadBlacklistModels()
{
    char sPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/ttt/blacklist_models_grabbermod.ini");

    File hFile = OpenFile(sPath, "rt");

    if (!FileExists(sPath))
    {
        SetFailState("Can't find the following file: \"configs/ttt/blacklist_models_grabbermod.ini\"");
        return;
    }
    
    char sBuffer[PLATFORM_MAX_PATH + 1];
    while(!hFile.EndOfFile() && hFile.ReadLine(sBuffer, sizeof(sBuffer)))
    {
        TrimString(sBuffer);
        
        if (strlen(sBuffer) > 2)
        {
            g_aBlacklistModels.PushString(sBuffer);
            
            if (g_cLogBlacklistModels.BoolValue)
            {
                LogMessage("[GrabberMod] (LoadBlacklistModels) Add %s to array...", sBuffer);
            }
        }
    }
    
    delete hFile;
}

bool CheckBlacklist(int client, const char[] name)
{
    char sBuffer[32];
    if (g_cShowNames.BoolValue) PrintToChat(client, "(Blocked) name: %s", name);
    if (g_aBlacklist.Length > 0)
    {
        for (int i = 0; i < g_aBlacklist.Length; i++)
        {
            g_aBlacklist.GetString(i, sBuffer, sizeof(sBuffer));

            if (g_cShowNames.BoolValue) PrintToChat(client, "(Blocked) name: %s - sBuffer: %s", name, sBuffer);
            
            if (strlen(sBuffer) > 1 && StrContains(name, sBuffer, false) != -1)
            {
                if (g_cShowNames.BoolValue) PrintToChat(client, "(Blocked) name: %s - sBuffer: %s", name, sBuffer);
                return true;
            }
        }
    }

    
    return false;
}

bool CheckBlacklistModels(int entity)
{
    char sBuffer[PLATFORM_MAX_PATH + 1], sModel[PLATFORM_MAX_PATH + 1];
    GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
    
    // by returning true we shouldn't break any compatibility with older version
    if (strlen(sModel) < 1)
    {
        return true;
    }

    if (g_aBlacklistModels.Length > 0)
    {
        for (int i = 0; i < g_aBlacklistModels.Length; i++)
        {
            g_aBlacklistModels.GetString(i, sBuffer, sizeof(sBuffer));
            
            if (strlen(sBuffer) > 1 && StrContains(sBuffer, sModel, false) != -1)
            {
                return true;
            }
        }
    }
    
    return false;
}

bool CheckWhitelist(const char[] name)
{
    char sBuffer[32];
    
    if (g_aWhitelist.Length > 0)
    {
        for (int i = 0; i < g_aWhitelist.Length; i++)
        {
            g_aWhitelist.GetString(i, sBuffer, sizeof(sBuffer));
            
            if (strlen(sBuffer) > 1 && StrContains(name, sBuffer, false) != -1)
            {
                return true;
            }
        }
    }
    
    return false;
}

bool CheckLists(int client, int entity, const char[] name)
{
    if (strlen(name) < 2)
    {
        return false;
    }

    if (g_cShowNames.BoolValue)
    {
        PrintToChat(client, "CheckLists 1 - CheckBlacklist: %d - CheckBlacklistModels: %d - CheckWhitelist: %d", CheckBlacklist(client, name), CheckBlacklistModels(entity), CheckWhitelist(name));
    }

    if (CheckWhitelist(name))
    {
        return false;
    }

    // We'll check blacklists first...
    if (CheckBlacklist(client, name) || CheckBlacklistModels(entity))
    {
        return true;
    }
    
    return false;
}

public int Native_GetClientGrabEntity(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (ValidGrab(client))
    {
        return EntRefToEntIndex(g_iPlayer[client].Object);
    }

    return -1;
}

public int Native_ResetClientGrab(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    Command_UnGrab(client);
    
    return 0;
}

public int Native_GetEntityGrabber(Handle plugin, int numParams)
{
    int iEnt = GetNativeCell(1);
    LoopValidClients(i)
    {
        if (ValidGrab(i))
        {
            if (EntRefToEntIndex(g_iPlayer[i].Object) == iEnt)
            {
                return i;
            }
        }
    }

    return 0; // returning 0 so we only need to do if (ent) { ... }
}

public int Native_ResetClientGrabByEntity(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);

    LoopValidClients(client)
    {
        if (EntRefToEntIndex(g_iPlayer[client].Object) == entity)
        {
            Command_UnGrab(client);
        }
    }
    
    return 0;
}

void ThrowObject(int client)
{
    if (ValidGrab(client) && !TTT_IsClientValid(EntRefToEntIndex(g_iPlayer[client].Object)))
    {
        int iEntity = EntRefToEntIndex(g_iPlayer[client].Object);

        float fAngles[3], vecFwd[3], fPosition[3], vecVel[3];

        GetClientEyeAngles(client, fAngles);
        GetAngleVectors(fAngles, vecFwd, NULL_VECTOR, NULL_VECTOR);
        GetClientEyePosition(client, fPosition);

        fPosition[0] += vecFwd[0] * g_cThrowForce.FloatValue;
        fPosition[1] += vecFwd[1] * g_cThrowForce.FloatValue;
        fPosition[2] += vecFwd[2] * g_cThrowForce.FloatValue;

        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecFwd);

        SubtractVectors(fPosition, vecFwd, vecVel);
        ScaleVector(vecVel, 10.0);

        TeleportEntity(iEntity, NULL_VECTOR, NULL_VECTOR, vecVel);

        char sSound[PLATFORM_MAX_PATH + 1];
        g_cThrowSound.GetString(sSound, sizeof(sSound));

        if (strlen(sSound) > 0)
        {
            EmitSoundToClientAny(client, sSound, _, _, _, _, g_cThrowSoundVol.FloatValue);
        }

        Command_UnGrab(client);
    }
}
