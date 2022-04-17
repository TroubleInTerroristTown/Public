#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <colorlib>
#include <ttt>
#include <ttt_roles>
#include <ttt_overlay>
#include <fourcc>

#define ROLE_KEY "htmn"
#define ROLE_TEAM TTT_TEAM_TRAITOR

int g_iRoleID = -1;

ConVar g_cName = null;
ConVar g_cRarity = null;
ConVar g_cMinPlayers = null;
ConVar g_cMaxCount = null;

bool g_bRolesLoaded = false;

int g_iTargetCount = -1;
int g_iTargetIDs[MAXPLAYERS];

enum struct PlayerData
{
    bool HasRole;
    int TargetID;

    void Reset()
    {
        this.HasRole = false;
        this.TargetID = -1;
    }
}

PlayerData Player[MAXPLAYERS + 1];

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

public Plugin myinfo =
{
    name = TTT_PLUGIN_NAME ... " - Role: Hitman",
    author = TTT_PLUGIN_AUTHOR,
    description = TTT_PLUGIN_DESCRIPTION,
    version = TTT_PLUGIN_VERSION,
    url = TTT_PLUGIN_URL
};

public void OnPluginStart()
{
    g_iRoleID = FourCC_FromString(ROLE_KEY);

    TTT_StartConfig("hitman", "ttt/roles");
    CreateConVar("ttt2_hitman_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cName = AutoExecConfig_CreateConVar("hitman_name", "Hitman", "Name of the role");
    g_cRarity = AutoExecConfig_CreateConVar("hitman_rarity", "0.2", "What's the chance (%/100) to get this role? 0 will disable this role.", _, true, 0.0, true, 1.0);
    g_cMinPlayers = AutoExecConfig_CreateConVar("hitman_min_players", "8", "How much players must be there to get this role?");
    g_cMaxCount = AutoExecConfig_CreateConVar("hitman_max_count", "2", "How much players can get this role in a round? 0 will disable this role.");
    TTT_EndConfig();
    
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
}

public void OnClientDisconnect(int client)
{
    Player[client].Reset();
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
    Player[client].HasRole = (role == g_iRoleID);
    Player[client].TargetID = -1;

    if (Player[client].HasRole)
    {
        char sName[64];
        g_cName.GetString(sName, sizeof(sName));

        CPrintToChat(client, "%s You are a {role t}%s!", g_sPluginTag, sName);
        CPrintToChat(client, "%s  - Unlike the rest of these {role t}traitors, you're just here to cash a paycheck.", g_sPluginTag);
        CPrintToChat(client, "%s  - You only earn credits by killing your assigned target.", g_sPluginTag);

        AwaitNextClientTarget(client);
    }
}

public void TTT_OnRoundStart(int roundid, int innocents, int traitors, int detective, int misc)
{
    InitTargetIDs();
}

////////////////////////////////////////////////////////////////////////////////
// Events
////////////////////////////////////////////////////////////////////////////////

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Check whether the attacker is a Hitman
    int client = GetClientOfUserId(event.GetInt("attacker"));
    if (Player[client].HasRole)
    {
        // Check if the victim is the target
        int victim = GetClientOfUserId(event.GetInt("client"));
        if (victim && IsClientTarget(client, victim))
        {
            // Need to add the store for this next part :)

            // Assign a new target
            AwaitNextClientTarget(client);
        }
    }

    return Plugin_Continue;
}

////////////////////////////////////////////////////////////////////////////////
// Hooks
////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
// Timers
////////////////////////////////////////////////////////////////////////////////

public Action Timer_AcquireTarget(Handle timer, int userID)
{
    int client = GetClientOfUserId(userID);
    if (client)
    {
        int target = GetNextHitmanTarget();
        if (target)
        {
            SetClientTarget(client, target);
        }
    }

    return Plugin_Handled;
}

////////////////////////////////////////////////////////////////////////////////
// Stocks
////////////////////////////////////////////////////////////////////////////////

void InitTargetIDs()
{
    g_iTargetCount = GetActiveClients(g_iTargetIDs);
    for (int i = 0; i < g_iTargetCount; ++i)
    {
        g_iTargetIDs[i] = GetClientUserId(g_iTargetIDs[i]);
    }

    SortIntegers(g_iTargetIDs, g_iTargetCount, Sort_Random);
}

void AwaitNextClientTarget(int client)
{
    CPrintToChat(client, "%s Your target shall be revealed in 5 seconds.", g_sPluginTag);
    CreateTimer(5.0, Timer_AcquireTarget, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

int GetNextHitmanTarget()
{
    int target;
    for (int i = 0; i < g_iTargetCount; ++i)
    {
        target = GetClientOfUserId(g_iTargetIDs[i]);

        if (target && IsPlayerAlive(target) && TTT_GetClientTeam(target) != TTT_TEAM_TRAITOR && !Player[target].HasRole)
        {
            return target;
        }
    }

    return -1;
}

void SetClientTarget(int client, int target)
{
    Player[client].TargetID = GetClientUserId(target);

    CPrintToChat(client, "%s Your target is %N.", g_sPluginTag, target);
}

bool IsClientTarget(int client, int victim)
{
    int target = GetClientOfUserId(Player[client].TargetID);
    if (target && target == victim)
    {
        return true;
    }

    return false;
}

int GetActiveClients(int clients[MAXPLAYERS])
{
    int count = 0;

    LoopValidClients(i)
    {
        if ((TTT_IsTeamGeneric(TTT_GetClientTeam(i))) && IsPlayerAlive(i))
        {
            clients[count] = i;
            ++count;
        }
    }

    return count;
}
