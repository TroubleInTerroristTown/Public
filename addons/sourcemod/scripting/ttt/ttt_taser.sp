#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#undef REQUIRE_PLUGIN
#include <ttt_glow>
#include <ttt_glow_light>

#define SHORT_NAME "taser"
#define SHORT_NAME_T "taser_t"
#define SHORT_NAME_D "taser_d"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Taser"

GlobalForward g_fwOnTased_Pre = null;
GlobalForward g_fwOnTased_Post = null;

bool g_bGlowLight = false;

ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cIPrice = null;
ConVar g_cILimit = null;
ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cDPrio = null;
ConVar g_cIPrio = null;
ConVar g_cTPrio = null;
ConVar g_cDCount = null;
ConVar g_cICount = null;
ConVar g_cTCount = null;
ConVar g_cDamage = null;
ConVar g_cOnSpawn = null;
ConVar g_cBroadcastTaserResult = null;
ConVar g_cTDamage = null;
ConVar g_cInflictor = null;
ConVar g_cLongName = null;
ConVar g_cRoundKeep = null;
ConVar g_cTKDamage = null;
ConVar g_cTaserCooldown = null;
ConVar g_cGlowPlayer = null;
ConVar g_cGlowLength = null;
ConVar g_cFadeLength = null;
ConVar g_cGlowToAll = null;
ConVar g_cTaserCooldownMessage = null;
ConVar g_cDisableTaserDamage = null;
ConVar g_cBlockPick = null;
ConVar g_cBlockDrop = null;
ConVar g_cAddLogs = null;
ConVar g_cLogFormat = null;

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

/* Block taser stuff or so... */
Handle g_hCooldown = null;

enum struct PlayerData {
    bool HasRoundTaser;
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
    g_fwOnTased_Pre = new GlobalForward("TTT_OnTased_Pre", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
    g_fwOnTased_Post = new GlobalForward("TTT_OnTased_Post", ET_Ignore, Param_Cell, Param_Cell);
    
    RegPluginLibrary("ttt_taser");

    return APLRes_Success;
}

public void OnPluginStart()
{
    TTT_IsGameCSGO();

    TTT_LoadTranslations();

    TTT_StartConfig("taser");
    CreateConVar("ttt2_taser_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cDPrice = AutoExecConfig_CreateConVar("taser_detective_price", "9000", "The amount of credits a taser costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("taser_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIPrice = AutoExecConfig_CreateConVar("taser_innocent_price", "9000", "The amount of credits a taser costs as innocent. 0 to disable.");
    g_cILimit = AutoExecConfig_CreateConVar("taser_innocent_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTPrice = AutoExecConfig_CreateConVar("taser_traitor_price", "0", "The amount of credits a taser costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("taser_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrio = AutoExecConfig_CreateConVar("taser_detective_sort_prio", "0", "The sorting priority of the taser (Detective) in the shop menu.");
    g_cIPrio = AutoExecConfig_CreateConVar("taser_innocent_sort_prio", "0", "The sorting priority of the taser (Innocent) in the shop menu.");
    g_cTPrio = AutoExecConfig_CreateConVar("taser_traitor_sort_prio", "0", "The sorting priority of the taser (Traitor) in the shop menu.");
    g_cDCount = AutoExecConfig_CreateConVar("taser_detective_count", "1", "The amount of usages for tasers per round as detective. 0 to disable.");
    g_cICount = AutoExecConfig_CreateConVar("taser_innocent_count", "1", "The amount of usages for tasers per round as innocent. 0 to disable.");
    g_cTCount = AutoExecConfig_CreateConVar("taser_traitor_count", "1", "The amount of usages for tasers per round as traitor. 0 to disable.");
    g_cDamage = AutoExecConfig_CreateConVar("taser_damage", "0", "The amount of damage a taser deals for detectives and innocents");
    g_cTDamage = AutoExecConfig_CreateConVar("taser_traitor_damage", "0", "The amount of damage a taser deals for traitors");
    g_cOnSpawn = AutoExecConfig_CreateConVar("taser_give_taser_spawn", "1", "Give the Detective a taser when he spawns?", _, true, 0.0, true, 1.0);
    g_cBroadcastTaserResult = AutoExecConfig_CreateConVar("taser_broadcast_taser_result", "0", "When set to true the results of the taser message will be printed to everyone instead of the client that tased", _, true, 0.0, true, 1.0);
    g_cInflictor = AutoExecConfig_CreateConVar("taser_barrel_fix", "1", "Prevent bug with taser and a explosive barrel", _, true, 0.0, true, 1.0);
    g_cLongName = AutoExecConfig_CreateConVar("taser_name", "Taser", "The name of this in Shop");
    g_cRoundKeep = AutoExecConfig_CreateConVar("ta_keep_to_next_round", "0", "Give the Innocents a tasers if they had one before round end?", _, true, 0.0, true, 1.0);
    g_cTKDamage = AutoExecConfig_CreateConVar("taser_kill_traitor_credits", "2000", "The amount of credits an innocent or detective will recieve for discovering a traitor with their zues/taser.");
    g_cTaserCooldown = AutoExecConfig_CreateConVar("taser_cooldown_after_round_start", "30.0", "Disable taser for X seconds after round starts (0.0 to disable it)");
    g_cTaserCooldownMessage = AutoExecConfig_CreateConVar("taser_cooldown_after_round_start_message", "1", "Show message when tasers are enabled?", _, true, 0.0, true, 1.0);
    g_cGlowPlayer = AutoExecConfig_CreateConVar("taser_glow_player_after_taser", "1", "Glow player on taser? ( 0 - Disable, 1 - Enable)", _, true, 0.0, true, 1.0);
    g_cGlowLength = AutoExecConfig_CreateConVar("taser_glow_player_length", "5", "How long should the player glow?, Time in Seconds, 0 - Disabled", _, true, 0.0);
    g_cFadeLength = AutoExecConfig_CreateConVar("taser_fade_player_length", "0.25", "The amount of seconds for runtime (0 - Disable)");
    g_cGlowToAll = AutoExecConfig_CreateConVar("taser_glow_player_for_all", "1", "Glow player for all? ( 0 - Disable, 1 - Enable)", _, true, 0.0, true, 1.0);
    g_cDisableTaserDamage = AutoExecConfig_CreateConVar("taser_disable_damage", "1", "Disable taser damage if the player don't have this item?", _, true, 0.0, true, 1.0);
    g_cBlockPick = AutoExecConfig_CreateConVar("taser_block_pick", "1", "Block taser pick up?", _, true, 0.0, true, 1.0);
    g_cBlockDrop = AutoExecConfig_CreateConVar("taser_block_drop", "1", "Block drop for players with taser and taser item?", _, true, 0.0, true, 1.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("weapon_fire", Event_WeaponFire);
    HookEvent("item_equip", Event_ItemEquip);

    LateLoadAll();

    g_bGlowLight = LibraryExists("ttt_glow_light");
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void OnLibraryAdded(const char[] library)
{
    if (StrEqual(library, "ttt_glow_light", false))
    {
        g_bGlowLight = true;
    }
}

public void OnLibraryRemoved(const char[] library)
{
    if (StrEqual(library, "ttt_glow_light", false))
    {
        g_bGlowLight = false;
    }
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    g_cAddLogs = FindConVar("ttt_steamid_add_to_logs");
    g_cLogFormat = FindConVar("ttt_steamid_log_format");

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

    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cICount.IntValue, g_cILimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnClientDisconnect(int client)
{
    ResetTaser(client, true);
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
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void TTT_OnRoundStart(int innocents, int traitors, int detective)
{
    if (g_hCooldown != null)
    {
        KillTimer(g_hCooldown);
    }
    g_hCooldown = null;

    if (g_cTaserCooldown.FloatValue > 0.0)
    {
        g_hCooldown = CreateTimer(g_cTaserCooldown.FloatValue, Timer_ActivateTasers);

        LoopValidClients(i)
        {
            for(int j = 0; j < GetEntPropArraySize(i, Prop_Send, "m_hMyWeapons"); j++)
            {
                int weapon = GetEntPropEnt(i, Prop_Send, "m_hMyWeapons", j);
        
                if (IsValidEntity(weapon))
                {
                    char sClass[32];
                    GetEntityClassname(weapon, sClass, sizeof(sClass));
        
                    if (StrContains(sClass, "taser", false) != -1)
                    {
                        BlockTaser(weapon);
                    }
                }
            }
        }
    }
}

public Action Timer_ActivateTasers(Handle timer)
{
    LoopValidClients(i)
    {
        for(int j = 0; j < GetEntPropArraySize(i, Prop_Send, "m_hMyWeapons"); j++)
        {
            int weapon = GetEntPropEnt(i, Prop_Send, "m_hMyWeapons", j);
    
            if (IsValidEntity(weapon))
            {
                char sClass[32];
                GetEntityClassname(weapon, sClass, sizeof(sClass));
    
                if (StrContains(sClass, "taser", false) != -1)
                {
                    UnblockTaser(weapon);
                }
            }
        }
    }

    if (g_cTaserCooldownMessage.BoolValue && (g_cICount.IntValue > 0 || g_cTCount.IntValue > 0 || g_cDCount.IntValue > 0))
    {
        CPrintToChatAll("%s %T", g_sPluginTag, "Tasers: Enabled", LANG_SERVER);
    }

    g_hCooldown = null;
    return Plugin_Stop;
}

public void TTT_OnRoundEnd(int winner, Handle array)
{
    if (g_hCooldown != null)
    {
        KillTimer(g_hCooldown);
    }
    g_hCooldown = null;

    LoopValidClients(i)
    {
        if (IsPlayerAlive(i) && HasTaser(i))
        {
            g_iPlayer[i].HasRoundTaser = true;
        }
    }
}

public void TTT_OnInventoryReady()
{
    LoopValidClients(client)
    {
        int role = TTT_GetClientRole(client);
        
        if (role == TTT_TEAM_DETECTIVE)
        {
            if (g_cOnSpawn.BoolValue)
            {
                if (TTT_IsItemInInventory(client, SHORT_NAME_D))
                {
                    return;
                }

                GivePlayerItem(client, "weapon_taser");
                TTT_AddInventoryItem(client, SHORT_NAME_D);
            }
            else if (g_cRoundKeep.BoolValue)
            {
                if (!g_iPlayer[client].HasRoundTaser)
                {
                    return;
                }

                GivePlayerItem(client, "weapon_taser");
                TTT_AddInventoryItem(client, SHORT_NAME_D);
            }
        }

        g_iPlayer[client].HasRoundTaser = false;
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetTaser(client, true);
    }
    
    return Plugin_Continue;
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

        if (IsValidEntity(iWeapon))
        {
            char sClass[32];
            GetEntityClassname(iWeapon, sClass, sizeof(sClass));
            
            if (StrEqual(sClass, "weapon_taser", false))
            {
                if (TTT_RemoveInventoryItem(client, SHORT_NAME))
                {
                    TTT_AddItemUsage(client, SHORT_NAME);
                }
                else if (TTT_RemoveInventoryItem(client, SHORT_NAME_D))
                {
                    TTT_AddItemUsage(client, SHORT_NAME_D);
                }
                else if (TTT_RemoveInventoryItem(client, SHORT_NAME_T))
                {
                    TTT_AddItemUsage(client, SHORT_NAME_T);
                }
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Event_ItemEquip(Event event, const char[] name, bool dontBroadcast)
{
    if (TTT_GetRoundStatus() != Round_Active)
    {
        return Plugin_Continue;
    }

    if (g_hCooldown == null)
    {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

        if (IsValidEntity(iWeapon))
        {
            char sClass[32];
            GetEntityClassname(iWeapon, sClass, sizeof(sClass));
            
            if (StrEqual(sClass, "weapon_taser", false))
            {
                BlockTaser(iWeapon);
            }
        }
    }

    return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (weapon == -1)
    {
        return Plugin_Continue;
    }

    if (g_hCooldown == null)
    {
        return Plugin_Continue;
    }

    if (IsValidEntity(weapon))
    {
        char sWeapon[32];
        GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

        if (StrContains(sWeapon, "taser", false) != -1)
        {
            BlockTaser(weapon);
        }
    }

    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if (!g_cBlockPick.BoolValue)
    {
        return Plugin_Continue;
    }

    if (TTT_IsClientValid(client) && IsValidEntity(weapon))
    {
        char sClass[32];
        GetEntityClassname(weapon, sClass, sizeof(sClass));

        if (StrEqual(sClass, "weapon_taser", false) && !HasTaser(client))
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action OnWeaponDrop(int client, int weapon)
{
    if (!g_cBlockDrop.BoolValue || (IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iClip1") <= 0))
    {
        return Plugin_Continue;
    }

    if (TTT_IsClientValid(client) && IsValidEntity(weapon))
    {
        char sClass[32];
        GetEntityClassname(weapon, sClass, sizeof(sClass));
        
        if (StrEqual(sClass, "weapon_taser", false))
        {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (!HasTaser(client))
    {
        GivePlayerItem(client, "weapon_taser");
        TTT_AddInventoryItem(client, itemshort);
    }
    else
    {
        TTT_AddInventoryItem(client, itemshort);

        int iTaser = TTT_HasClientTaser(client);

        if (iTaser != -1)
        {
            SetEntProp(iTaser, Prop_Send, "m_iClip1", TTT_GetClientItemQuantity(client, itemshort));
        }
        else
        {
            iTaser = GivePlayerItem(client, "weapon_taser");
            SetEntProp(iTaser, Prop_Send, "m_iClip1", TTT_GetClientItemQuantity(client, itemshort));
        }
    }

    return Plugin_Continue;
}

void ResetTaser(int client, bool fullReset)
{
    if (fullReset)
    {
        g_iPlayer[client].HasRoundTaser = false;
    }
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

    if (TTT_IsWorldDamage(iAttacker, damagetype))
    {
        return Plugin_Continue;
    }

    char sWeapon[64];
    GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));

    if (StrContains(sWeapon, "taser", false) == -1)
    {
        return Plugin_Continue;
    }

    if (g_hCooldown != null)
    {
        return Plugin_Handled;
    }

    if (g_cInflictor.BoolValue && iAttacker != inflictor)
    {
        return Plugin_Continue;
    }

    int iRole = TTT_GetClientRole(iVictim);
    int iARole = TTT_GetClientRole(iAttacker);

    Action result = Plugin_Continue;

    Call_StartForward(g_fwOnTased_Pre);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_PushCellRef(iRole);
    Call_Finish(result);

    if (result == Plugin_Stop || result == Plugin_Handled)
    {
        return result;
    }

    char sAttackerID[32], sVictimID[32];

    if (g_cAddLogs != null && g_cAddLogs.BoolValue)
    {
        if (g_cLogFormat.IntValue == 1)
        {
            GetClientAuthId(iAttacker, AuthId_Steam2, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(iVictim, AuthId_Steam2, sVictimID, sizeof(sVictimID));
        }
        else if (g_cLogFormat.IntValue == 2)
        {
            GetClientAuthId(iAttacker, AuthId_Steam3, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(iVictim, AuthId_Steam3, sVictimID, sizeof(sVictimID));
        }
        else if (g_cLogFormat.IntValue == 3)
        {
            GetClientAuthId(iAttacker, AuthId_SteamID64, sAttackerID, sizeof(sAttackerID));
            GetClientAuthId(iVictim, AuthId_SteamID64, sVictimID, sizeof(sVictimID));
        }
        else if (g_cLogFormat.IntValue == 4)
        {
            Format(sAttackerID, sizeof(sAttackerID), "%d", GetSteamAccountID(iAttacker));
            Format(sVictimID, sizeof(sVictimID), "%d", GetSteamAccountID(iVictim));
        }
        
        if (strlen(sAttackerID) > 2 && strlen(sVictimID) > 2)
        {
            Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
            Format(sVictimID, sizeof(sVictimID), " (%s)", sVictimID);
        }
    }

    char sVictimName[MAX_NAME_LENGTH], sAttackerName[MAX_NAME_LENGTH];
    TTT_GetClientName(iAttacker, sAttackerName, sizeof(sAttackerName));
    TTT_GetClientName(iVictim, sVictimName, sizeof(sVictimName));
    
    // TODO: Make it shorter(?) with this natives - https://github.com/TroubleInTerroristTown/Public/issues/309
    if (iRole == TTT_TEAM_TRAITOR)
    {
        char sVictim[MAX_NAME_LENGTH], sAttacker[MAX_NAME_LENGTH];
        TTT_GetClientName(iVictim, sVictim, sizeof(sVictim));
        TTT_GetClientName(iAttacker, sAttacker, sizeof(sAttacker));
        
        TTT_LogString("-> [%s%s (Traitor) was tased by %s%s] - TRAITOR DETECTED", sVictim, sVictimID, sAttacker, sAttackerID);

        if (g_cBroadcastTaserResult.BoolValue)
        {
            CPrintToChatAll("%s %T", g_sPluginTag, "You tased a Traitor", LANG_SERVER, sAttackerName, sVictimName);
        }
        else
        {
            CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt a Traitor", iVictim, sVictim);
        }
        
        TTT_SetClientCredits(iAttacker, TTT_GetClientCredits(iAttacker) + g_cTKDamage.IntValue);
    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        char sVictim[MAX_NAME_LENGTH], sAttacker[MAX_NAME_LENGTH];
        TTT_GetClientName(iVictim, sVictim, sizeof(sVictim));
        TTT_GetClientName(iAttacker, sAttacker, sizeof(sAttacker));
        
        TTT_LogString("-> [%s%s (Detective) was tased by %s%s]", sVictim, sVictimID, sAttacker, sAttackerID);

        if (g_cBroadcastTaserResult.BoolValue)
        {
            CPrintToChatAll("%s %T", g_sPluginTag, "You tased a Detective", LANG_SERVER, sAttackerName, sVictimName);
        }
        else
        {
            CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt a Detective", iVictim, sVictim);
        }
    }
    else if (iRole == TTT_TEAM_INNOCENT)
    {
        char sVictim[MAX_NAME_LENGTH], sAttacker[MAX_NAME_LENGTH];
        TTT_GetClientName(iVictim, sVictim, sizeof(sVictim));
        TTT_GetClientName(iAttacker, sAttacker, sizeof(sAttacker));
        
        TTT_LogString("-> [%s%s (Innocent) was tased by %s%s]", sVictim, sVictimID, sAttacker, sAttackerID);

        if (g_cBroadcastTaserResult.BoolValue)
        {
            CPrintToChatAll("%s %T", g_sPluginTag, "You tased an Innocent", LANG_SERVER, sAttackerName, sVictimName);
        }
        else
        {
            CPrintToChat(iAttacker, "%s %T", g_sPluginTag, "You hurt an Innocent", iVictim, sVictim);
        }
    }
    
    Call_StartForward(g_fwOnTased_Post);
    Call_PushCell(iAttacker);
    Call_PushCell(iVictim);
    Call_Finish();

    if (g_cGlowPlayer.BoolValue && g_cGlowLength.IntValue > 0)
    {
        if (g_cGlowToAll.BoolValue)
        {
            if (g_bGlowLight)
            {
                TTT_AllCanSeeGlowLight(iVictim, g_cGlowLength.FloatValue);
            }
            else
            {
                TTT_AllCanSeeGlow(iVictim, g_cGlowLength.FloatValue);
            }
        } 
        else
        {
            if (g_bGlowLight)
            {
                TTT_CanSeeGlowLight(iAttacker, iVictim, g_cGlowLength.FloatValue);
            }
            else
            {
                TTT_CanSeeGlow(iAttacker, iVictim, g_cGlowLength.FloatValue);
            }
        }

        FadePlayer(iVictim, { 255, 255, 255, 100 });
    }

    if (iARole != TTT_TEAM_TRAITOR)
    {
        if (g_cDamage.IntValue == 0)
        {
            return Plugin_Handled;
        }
        else if (g_cDamage.IntValue > 0)
        {
            damage = g_cDamage.FloatValue;
            return Plugin_Changed;
        }
    }
    else
    {
        if (g_cTDamage.IntValue == 0)
        {
            return Plugin_Handled;
        }

        damage = g_cTDamage.FloatValue;
        return Plugin_Changed;
    }
    

    if (g_cDisableTaserDamage.BoolValue && StrContains(sWeapon, "taser", false) != -1)
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (g_hCooldown != null && buttons & IN_ATTACK)
    {
        if (weapon == -1 || !IsValidEntity(weapon))
        {
            return Plugin_Continue;
        }

        char sWeapon[32];
        GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));

        if (StrEqual(sWeapon, "weapon_taser", false))
        {
            BlockTaser(weapon);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

void BlockTaser(int weapon)
{
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + (g_cTaserCooldown.FloatValue) * 128);
    SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + (g_cTaserCooldown.FloatValue) * 128);
}

void UnblockTaser(int weapon)
{
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + -0.1);
    SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + -0.1);
}

void FadePlayer(int client, int iColor[4])
{
    if (g_cFadeLength.FloatValue > 0.0)
    {
        int iFadeLength = RoundToNearest(g_cFadeLength.FloatValue * 1000.0);

        Protobuf pbMessage = view_as<Protobuf>(StartMessageOne("Fade", client, USERMSG_RELIABLE));
        pbMessage.SetInt("duration", iFadeLength);
        pbMessage.SetInt("hold_time", iFadeLength);
        pbMessage.SetInt("flags", 0x0001);
        pbMessage.SetColor("clr", iColor);
        EndMessage();
    }
}

bool HasTaser(int client)
{
    if (TTT_IsItemInInventory(client, SHORT_NAME) || TTT_IsItemInInventory(client, SHORT_NAME_D) || TTT_IsItemInInventory(client, SHORT_NAME_T))
    {
        return true;
    }

    return false;
}
