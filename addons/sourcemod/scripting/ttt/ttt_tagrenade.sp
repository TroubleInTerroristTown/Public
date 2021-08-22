#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colorlib>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>

#undef REQUIRE_PLUGIN
#include <ttt_glow>
#include <ttt_glow_light>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - TA-Grenade"

#define SHORT_NAME "tagrenade"
#define SHORT_NAME_T "tagrenade_t"
#define SHORT_NAME_D "tagrenade_d"

ConVar g_cDebug = null;
ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cTCount = null;
ConVar g_cTPrio = null;
ConVar g_cTagrenadeRange = null;
ConVar g_cTagrenadeTime = null;
ConVar g_cLongName = null;
ConVar g_cShowPlayersBehindWalls = null;
ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cDCount = null;
ConVar g_cDPrio = null;
ConVar g_cDTagrenadeRange = null;
ConVar g_cCountPlayersBehindWalls = null;
ConVar g_cCountInnocents = null;
ConVar g_cCountTraitors = null;
ConVar g_cCountDetectives = null;
ConVar g_cRequiredPlayers = null;

bool g_bGlow = false;
bool g_bGlowLight = false;

ConVar g_cPluginTag = null;
char g_sPluginTag[64];

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

    TTT_StartConfig("tagrenade");
    CreateConVar("ttt2_tagrenade_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("tagrenade_name", "TA-Grenade", "The name of the TA-Grenade in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("tagrenade_traitor_price", "9000", "The amount of credits for tagrenade costs as traitor. 0 to disable.");
    g_cTLimit = AutoExecConfig_CreateConVar("tagrenade_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("tagrenade_detective_price", "9000", "The amount of credits for tagrenade costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("tagrenade_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cTCount = AutoExecConfig_CreateConVar("tagrenade_traitor_count", "1", "The amount of usages for tagrenade per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("tagrenade_detective_count", "1", "The amount of usages for tagrenade per round as detective. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("tagrenade_traitor_sort_prio", "0", "The sorting priority of the tagrenade (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("tagrenade_detective_sort_prio", "0", "The sorting priority of the tagrenade (Detective) in the shop menu.");
    g_cTagrenadeRange = AutoExecConfig_CreateConVar("tagrenade_distance", "1000.0", "Sets the proximity in which the tactical grenade will tag an opponent.");
    g_cDTagrenadeRange = AutoExecConfig_CreateConVar("tagrenade_distance_detective", "1000.0", "Sets the proximity in which the tactical grenade will count the players.");
    g_cTagrenadeTime = AutoExecConfig_CreateConVar("tagrenade_time", "3.5", "How long a player is tagged for in seconds.");
    g_cShowPlayersBehindWalls = AutoExecConfig_CreateConVar("tagrenade_players_behind_walls", "1", "Tag players behind a wall?", _, true, 0.0, true, 1.0);
    g_cCountPlayersBehindWalls = AutoExecConfig_CreateConVar("tagrenade_players_behind_walls_detective", "1", "Count players behind a wall?", _, true, 0.0, true, 1.0);
    g_cCountInnocents = AutoExecConfig_CreateConVar("tagrenade_detective_count_innocents", "1", "Count innocents for detectives tagrenade?", _, true, 0.0, true, 1.0);
    g_cCountTraitors = AutoExecConfig_CreateConVar("tagrenade_detective_count_traitors", "1", "Count traitors for detectives tagrenade?", _, true, 0.0, true, 1.0);
    g_cCountDetectives = AutoExecConfig_CreateConVar("tagrenade_detective_count_detectives", "1", "Count detectives for detectives tagrenade?", _, true, 0.0, true, 1.0);
    g_cRequiredPlayers = AutoExecConfig_CreateConVar("tagrenade_detective_required_players", "4", "How much (valid incl. count convars) players must be in the proximity?");
    TTT_EndConfig();

    HookEvent("tagrenade_detonate", OnTagrenadeDetonate);

    g_bGlow = LibraryExists("ttt_glow");
    g_bGlowLight = LibraryExists("ttt_glow_light");
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = true;
    }
    else if(StrEqual(name, "ttt_glow_light"))
    {
        g_bGlowLight = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "ttt_glow"))
    {
        g_bGlow = false;
    }
    else if(StrEqual(name, "ttt_glow_light"))
    {
        g_bGlowLight = false;
    }
}

public void OnConfigsExecuted()
{
    g_cDebug = FindConVar("ttt_debug_mode");
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    ConVar UseTAGrenade = FindConVar("cd_usetagrenade");
    
    if (UseTAGrenade != null)
    {
        UseTAGrenade.SetBool(true);
    }

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
    
    if (g_bGlow || g_bGlowLight)
    {
        TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
        TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
    }
    else
    {
        if (LibraryExists("ttt_glow"))
        {
            g_bGlow = true;
        }
        else if(LibraryExists("ttt_glow_light"))
        {
            g_bGlowLight = true;
        }
        else
        {
            SetFailState("Neither the TTT Glow or TTT Glow Light is not enabled.");
        }
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    GivePlayerItem(client, "weapon_tagrenade");
    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public void OnTagrenadeDetonate(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    
    DataPack pack = new DataPack();
    pack.WriteCell(userid);
    pack.WriteCell(event.GetInt("entityid"));
    pack.WriteFloat(event.GetFloat("x"));
    pack.WriteFloat(event.GetFloat("y"));
    pack.WriteFloat(event.GetFloat("z"));
    
    RequestFrame(Frame_OnGetTagrenadeTimes, pack);
    
    int client = GetClientOfUserId(userid);
    
    if (TTT_IsClientValid(client) && TTT_IsItemInInventory(client, SHORT_NAME))
    {
        TTT_AddItemUsage(client, SHORT_NAME);
        TTT_RemoveInventoryItem(client, SHORT_NAME);
    }
}

public void Frame_OnGetTagrenadeTimes(any pack)
{
    view_as<DataPack>(pack).Reset();

    int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());
    if (client == 0)
    {
        delete view_as<DataPack>(pack);
        return;
    }
    
    int role = TTT_GetClientRole(client);

    int entity = view_as<DataPack>(pack).ReadCell();

    float position[3];
    float targetposition[3];
    float distance;

    position[0] = view_as<DataPack>(pack).ReadFloat();
    position[1] = view_as<DataPack>(pack).ReadFloat();
    position[2] = view_as<DataPack>(pack).ReadFloat();
    delete view_as<DataPack>(pack);

    int iInno = 0;
    int iTraitor = 0;
    int iDete = 0;

    int targets[MAXPLAYERS + 1];
    int target_count = 0;
    
    LoopValidClients(target)
    {
        if (target < 1)
        {
            continue;
        }

        if (client == target)
        {
            continue;
        }
        
        if (!g_cDebug.BoolValue && IsFakeClient(target))
        {
            continue;
        }

        if (!IsPlayerAlive(target))
        {
            continue;
        }

        if (TTT_GetClientRole(target) < TTT_TEAM_INNOCENT)
        {
            continue;
        }

        SetEntPropFloat(target, Prop_Send, "m_flDetectedByEnemySensorTime", 0.0);
        
        if (!TTT_IsItemInInventory(client, SHORT_NAME))
        {
            continue;
        }

        GetClientEyePosition(target, targetposition);
        distance = GetVectorDistance(position, targetposition);

        if (role == TTT_TEAM_TRAITOR && distance > g_cTagrenadeRange.FloatValue)
        {
            continue;
        }
        else if (role == TTT_TEAM_DETECTIVE && distance > g_cDTagrenadeRange.FloatValue)
        {
            continue;
        }
        
        if (role == TTT_TEAM_TRAITOR)
        {
            if (g_cShowPlayersBehindWalls.BoolValue)
            {
                Handle trace = TR_TraceRayFilterEx(position, targetposition, MASK_VISIBLE, RayType_EndPoint, OnTraceForTagrenade, entity);
                
                if (TR_DidHit(trace) && TR_GetEntityIndex(trace) == target)
                {
                    targets[target_count] = target;
                    ++target_count;
                }
                
                delete trace;
            }
            else
            {
                targets[target_count] = target;
                ++target_count;
            }
        }
        else if (role == TTT_TEAM_DETECTIVE)
        {
            if (g_cCountPlayersBehindWalls.BoolValue)
            {
                int tRole = TTT_GetClientRole(target);
                
                if (tRole == TTT_TEAM_INNOCENT)
                {
                    iInno++;
                }
                else if (tRole == TTT_TEAM_TRAITOR)
                {
                    iTraitor++;
                }
                else if (tRole == TTT_TEAM_DETECTIVE)
                {
                    iDete++;
                }
            }
        }
    }

    if (role == TTT_TEAM_TRAITOR)
    {
        if (g_bGlowLight)
        {
            TTT_CanSeeClientsGlowLight(client, targets, target_count, g_cTagrenadeTime.FloatValue);
        }
        else
        {
            TTT_CanSeeClientsGlow(client, targets, target_count, g_cTagrenadeTime.FloatValue);   
        }
    }

    int iPlayers = 0;
    
    if (g_cCountInnocents.BoolValue)
    {
        iPlayers += iInno;
    }
    
    if (g_cCountTraitors.BoolValue)
    {
        iPlayers += iTraitor;
    }
    
    if (g_cCountDetectives.BoolValue)
    {
        iPlayers += iDete;
    }
    
    if (iPlayers >= g_cRequiredPlayers.IntValue && role == TTT_TEAM_DETECTIVE)
    {
        CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade We Found", client);
        
        if (g_cCountInnocents.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Innocents", client, iInno);
        }
        
        if (g_cCountTraitors.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Traitors", client, iTraitor);
        }
        
        if (g_cCountDetectives.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "TAGrenade Detectives", client, iDete);
        }
    }
}

public bool OnTraceForTagrenade(int entity, int contentsMask, any tagrenade)
{
    if (entity == tagrenade)
    {
        return false;
    }
    return true;
}
