#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <colorlib>
#include <ttt>
#include <ttt_roles>
#include <ttt_overlay>
#include <fourcc>

#define ROLE_KEY "jstr"
#define ROLE_TEAM TTT_TEAM_MISC

int g_iRoleID = -1;

ConVar g_cName = null;
ConVar g_cRarity = null;
ConVar g_cMinPlayers = null;
ConVar g_cMaxCount = null;

bool g_bRolesLoaded = false;

enum struct PlayerData
{
    int Team;
    bool HasRole;
    bool WasJesterMurdered;

    void Reset()
    {
        this.Team = 0;
        this.HasRole = false;
        this.WasJesterMurdered = false;
    }
}

PlayerData Player[MAXPLAYERS + 1];

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME ... " - Role: Jester",
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    g_iRoleID = FourCC_FromString(ROLE_KEY);

    TTT_StartConfig("jester", "ttt/roles");
    CreateConVar("ttt2_jester_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cName = AutoExecConfig_CreateConVar("jester_name", "Jester", "Name of the role");
    g_cRarity = AutoExecConfig_CreateConVar("jester_rarity", "0.2", "What's the chance (%/100) to get this role? 0 will disable this role.", _, true, 0.0, true, 1.0);
    g_cMinPlayers = AutoExecConfig_CreateConVar("jester_min_players", "8", "How much players must be there to get this role?");
    g_cMaxCount = AutoExecConfig_CreateConVar("jester_max_count", "1", "How much players can get this role in a round? 0 will disable this role.");
    TTT_EndConfig();

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

public void OnLibraryAdded(const char[] name)
{
    if (TTT_CheckRoleLibraryName(name))
    {
        g_bRolesLoaded = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (TTT_CheckRoleLibraryName(name))
    {
        g_bRolesLoaded = false;
    }
}

public void OnConfigsExecuted()
{
    if (g_bRolesLoaded)
    {
        if (TTT_IsRolesReady())
        {
            TTT_RolesRegister();
        }
    }

    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void OnAllPluginsLoaded()
{
    g_bRolesLoaded = TTT_CheckRoleLibraryExists();
}

public Action Overlay_OnPrecacheRoleOverlay(char[] path, int maxlen)
{    
    TTT_PrecacheIconOverlay(ROLE_KEY);

    return Plugin_Continue;
}

public Action Overlay_OnPrecacheWinOverlay(char[] path, int maxlen)
{
    TTT_PrecacheWinOverlay(ROLE_KEY);

    return Plugin_Continue;
}

public Action Overlay_OnWinOverlay(int team, int role, char[] path, int maxlen)
{
    if (role == g_iRoleID)
    {
        ReplaceString(path, maxlen, "<NAME>", ROLE_KEY);

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public Action Overlay_OnRoleOverlay(int client, char[] path, int maxlen)
{
    if (Player[client].HasRole)
    {
        ReplaceString(path, maxlen, "<NAME>", ROLE_KEY);

        return Plugin_Changed;
    }

    return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
    Player[client].Reset();

    SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamageAlive);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamageAlive);
}

public void TTT_RolesRegister()
{
    if (g_cRarity.FloatValue <= 0.0 || g_cMaxCount.IntValue <= 0)
    {
        return;
    }

    TTT_RegisterRole(ROLE_KEY, ROLE_TEAM, FourCC_FromString(ROLE_KEY), g_cRarity.FloatValue, g_cMinPlayers.IntValue, g_cMaxCount.IntValue);
}

public void TTT_OnClientGetRole(int client, int team, int role)
{
    Player[client].Team = team;
    Player[client].HasRole = (role == g_iRoleID);

    if (Player[client].HasRole)
    {
        char sName[64];
        g_cName.GetString(sName, sizeof(sName));

        CPrintToChat(client, "%s You are the {role m}%s!", g_sPluginTag, sName);
        CPrintToChat(client, "%s - Your aim is to get an {role i}innocent {default}or {role d}detective {default}to kill you.", g_sPluginTag);
        CPrintToChat(client, "%s - You can not deal any damage but {role t}traitors {default}can not hurt you.", g_sPluginTag);
    }
}

////////////////////////////////////////////////////////////////////////////////
// Events
////////////////////////////////////////////////////////////////////////////////

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(i)
    {
        Player[i].Reset();
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (Player[client].HasRole)
    {
        int attacker = GetClientOfUserId(event.GetInt("attacker"));
        if (attacker)
        {
            Player[client].WasJesterMurdered = true;
        }
    }

    return Plugin_Continue;
}

////////////////////////////////////////////////////////////////////////////////
// Hooks
////////////////////////////////////////////////////////////////////////////////

public Action Hook_OnTakeDamageAlive(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
    if (Player[attacker].HasRole ||
        (Player[victim].HasRole && !CanClientHurtJester(attacker)))
    {
        damage = 0.0;

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

////////////////////////////////////////////////////////////////////////////////
// Stocks
////////////////////////////////////////////////////////////////////////////////

bool CanClientHurtJester(int client)
{
    if (Player[client].Team == TTT_TEAM_TRAITOR)
    {
        return false;
    }

    if (Player[client].HasRole)
    {
        return false;
    }

    return true;
}
