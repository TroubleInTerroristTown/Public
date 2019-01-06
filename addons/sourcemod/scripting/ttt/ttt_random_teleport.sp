#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt_shop>
#include <ttt>
#include <multicolors>

#define SHORT_NAME "rdmTele"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Random Teleporter"

ConVar g_cTPrice = null;
ConVar g_cDPrice = null;
ConVar g_cIPrice = null;
ConVar g_cTPrio = null;
ConVar g_cDPrio = null;
ConVar g_cIPrio = null;
ConVar g_cTCount = null;
ConVar g_cDCount = null;
ConVar g_cICount = null;
ConVar g_cLongName = null;
ConVar g_cRagdoll = null;
ConVar g_cIgnoreRoleTraitor = null;
ConVar g_cIgnoreRoleInnocent = null;
ConVar g_cIgnoreRoleDetective = null;

int g_iTPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iDPCount[MAXPLAYERS + 1] =  { 0, ... };
int g_iIPCount[MAXPLAYERS + 1] =  { 0, ... };

ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

bool g_bDebug = true;
char g_sLog[PLATFORM_MAX_PATH+1];

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

    char sDate[12];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
    BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/ttt/random_teleporter_%s.log", sDate);

    TTT_StartConfig("random_teleporter");
    CreateConVar("ttt2_random_teleporter_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("rt_name", "Random Teleporter", "The name of the Random Teleport in the Shop");
    g_cTPrice = AutoExecConfig_CreateConVar("rt_traitor_price", "9000", "The amount of credits for Random Teleport costs as traitor. 0 to disable.");
    g_cDPrice = AutoExecConfig_CreateConVar("rt_detective_price", "0", "The amount of credits for Random Teleport costs as detective. 0 to disable.");
    g_cIPrice = AutoExecConfig_CreateConVar("rt_innocent_price", "0", "The amount of credits for Random Teleport costs as innocent. 0 to disable.");
    g_cTPrio = AutoExecConfig_CreateConVar("rt_traitor_sort_prio", "0", "The sorting priority of the Random Teleport (Traitor) in the shop menu.");
    g_cDPrio = AutoExecConfig_CreateConVar("rt_detective_sort_prio", "0", "The sorting priority of the Random Teleport (Detective) in the shop menu.");
    g_cIPrio = AutoExecConfig_CreateConVar("rt_innocent_sort_prio", "0", "The sorting priority of the Random Teleport (innocent) in the shop menu.");
    g_cTCount = AutoExecConfig_CreateConVar("rt_traitor_count", "1", "The amount of usages for Random Teleports per round as traitor. 0 to disable.");
    g_cDCount = AutoExecConfig_CreateConVar("rt_detective_count", "1", "The amount of usages for Random Teleports per round as detective. 0 to disable.");
    g_cICount = AutoExecConfig_CreateConVar("rt_innocent_count", "1", "The amount of usages for Random Teleports per round as innocent. 0 to disable.");
    g_cRagdoll = AutoExecConfig_CreateConVar("rt_teleport_ragdolls", "1", "Teleport with dead players (ragdoll)?", _, true, 0.0, true, 1.0);
    g_cIgnoreRoleTraitor = AutoExecConfig_CreateConVar("rt_traitor_ignore_role", "4", "Which role should be ignored when traitor use random teleporter? -1 - Disabled ( https://github.com/Bara/TroubleinTerroristTown/wiki/CVAR-Masks )", _, true, 2.0);
    g_cIgnoreRoleInnocent = AutoExecConfig_CreateConVar("rt_innocent_ignore_role", "-1", "Which role should be ignored when innocent use random teleporter? -1 - Disabled ( https://github.com/Bara/TroubleinTerroristTown/wiki/CVAR-Masks )", _, true, 2.0);
    g_cIgnoreRoleDetective = AutoExecConfig_CreateConVar("rt_detective_ignore_role", "-1", "Which role should be ignored when detective use random teleporter? -1 - Disabled ( https://github.com/Bara/TroubleinTerroristTown/wiki/CVAR-Masks )", _, true, 2.0);
    TTT_EndConfig();

    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void TTT_OnLatestVersion(const char[] version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetCommitsCount());
}

public void OnClientDisconnect(int client)
{
    ResetItem(client);
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
}

public void TTT_OnShopReady()
{
    // LogToFile(g_sLog, "(TTT_OnShopReady) called!");
    RegisterItem();
}

void RegisterItem()
{
    char sBuffer[MAX_ITEM_LENGTH];
    g_cLongName.GetString(sBuffer, sizeof(sBuffer));
    TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue);
    TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue);
    TTT_RegisterCustomItem(SHORT_NAME, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public Action TTT_OnItemPurchased(int client, const char[] itemshort, bool count, int price)
{
    if (TTT_IsClientValid(client) && IsPlayerAlive(client))
    {
        if (StrEqual(itemshort, SHORT_NAME, false))
        {
            int role = TTT_GetClientRole(client);
            
            char sBuffer[MAX_ITEM_LENGTH];
            g_cLongName.GetString(sBuffer, sizeof(sBuffer));

            if (role == TTT_TEAM_TRAITOR && g_iTPCount[client] >= g_cTCount.IntValue)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cTCount.IntValue);
                return Plugin_Stop;
            }
            else if (role == TTT_TEAM_DETECTIVE && g_iDPCount[client] >= g_cDCount.IntValue)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cDCount.IntValue);
                return Plugin_Stop;
            }
            else if (role == TTT_TEAM_INNOCENT && g_iIPCount[client] >= g_cICount.IntValue)
            {
                CPrintToChat(client, "%s %T", g_sPluginTag, "Bought All", client, sBuffer, g_cICount.IntValue);
                return Plugin_Stop;
            }

            int target = RandomTeleport(client);

            if (target == -1)
            {
                return Plugin_Stop;
            }

            if (count && target != -1)
            {
                if (role == TTT_TEAM_TRAITOR)
                {
                    g_iTPCount[client]++;
                }
                else if (role == TTT_TEAM_DETECTIVE)
                {
                    g_iDPCount[client]++;
                }
                else if (role == TTT_TEAM_INNOCENT)
                {
                    g_iIPCount[client]++;
                }
            }
        }
    }
    return Plugin_Continue;
}

int RandomTeleport(int client)
{
    bool bAlive = true;
    int[] iRagdoll = new int[Ragdolls];
    float fClientPos[3], fTargetPos[3];

    if (g_cRagdoll.BoolValue)
    {
        bAlive = false;
    }

    int target = -1;
    int iRole = TTT_GetClientRole(client);

    if (iRole == TTT_TEAM_TRAITOR)
    {
        target = TTT_GetRandomPlayer(bAlive, g_cIgnoreRoleTraitor.IntValue);
    }
    else if (iRole == TTT_TEAM_INNOCENT)
    {
        target = TTT_GetRandomPlayer(bAlive, g_cIgnoreRoleInnocent.IntValue);
    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        target = TTT_GetRandomPlayer(bAlive, g_cIgnoreRoleDetective.IntValue);
    }

    if (target == -1 || !TTT_IsClientValid(target))
    {
        LogToFile(g_sLog, "[Random Teleport] Target %d is invalid (with Ragdoll? %d)", target, g_cRagdoll.BoolValue);
        return -1;
    }

    if (g_bDebug)
    {
        LogToFile(g_sLog, "[Random Teleport] Target: \"%L\" - UserID: %d - Index: %d - Valid: %d - Alive: %d - Ragdoll: %d", target, GetClientUserId(target), target, TTT_IsClientValid(target), TTT_IsPlayerAlive(target), g_cRagdoll.BoolValue);
    }

    if (TTT_IsPlayerAlive(target))
    {
        GetClientAbsOrigin(client, fClientPos);
        GetClientAbsOrigin(target, fTargetPos);

        LogToFile(g_sLog, "[Random Teleporter] [1/2] Target: \"%L\" - From: %f:%f:%f - To: %f:%f:%f", target, fTargetPos[0], fTargetPos[1], fTargetPos[2], fClientPos[0], fClientPos[1], fClientPos[2]);
        LogToFile(g_sLog, "[Random Teleporter] [1/2] Client: \"%L\" - From: %f:%f:%f - To: %f:%f:%f", client, fClientPos[0], fClientPos[1], fClientPos[2], fTargetPos[0], fTargetPos[1], fTargetPos[2]);

        DataPack cPack = new DataPack();
        RequestFrame(Frame_Teleport, cPack);
        cPack.WriteCell(GetClientUserId(client));
        cPack.WriteFloat(fTargetPos[0]);
        cPack.WriteFloat(fTargetPos[1]);
        cPack.WriteFloat(fTargetPos[2]);

        DataPack tPack = new DataPack();
        RequestFrame(Frame_Teleport, tPack);
        tPack.WriteCell(GetClientUserId(target));
        tPack.WriteFloat(fClientPos[0]);
        tPack.WriteFloat(fClientPos[1]);
        tPack.WriteFloat(fClientPos[2]);
    }
    else
    {
        if (!TTT_GetClientRagdoll(target, iRagdoll))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Cant find ragdoll", client);
            return -1;
        }

        int body = EntRefToEntIndex(iRagdoll[Ent]);

        if (!IsValidEntity(body))
        {
            return -1;
        }

        float fAngles[3], fVelo[3];
        GetClientAbsOrigin(client, fClientPos);
        fClientPos[2] += 30;

        GetClientAbsAngles(client, fAngles);
        GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelo);

        GetEntPropVector(body, Prop_Send, "m_vecOrigin", fTargetPos);

        TeleportEntity(client, fTargetPos, NULL_VECTOR, NULL_VECTOR);

        float speed = GetVectorLength(fVelo);
        if (speed >= 500)
        {
            TeleportEntity(body, fClientPos, fAngles, NULL_VECTOR);
        }
        else
        {
            TeleportEntity(body, fClientPos, fAngles, fVelo);
        }
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Teleport", client, target);
    return target;
}

public void Frame_Teleport(DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());

    if (TTT_IsClientValid(client))
    {
        float fOrigin[3];

        fOrigin[0] = pack.ReadFloat();
        fOrigin[1] = pack.ReadFloat();
        fOrigin[2] = pack.ReadFloat();

        TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);

        LogToFile(g_sLog, "[Random Teleporter] [2/2] Client: \"%L\" - To: %f:%f:%f", client, fOrigin[0], fOrigin[1], fOrigin[2]);
    }

    delete pack;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (TTT_IsClientValid(client))
    {
        ResetItem(client);
    }
}

void ResetItem(int client)
{
    g_iTPCount[client] = 0;
    g_iDPCount[client] = 0;
    g_iIPCount[client] = 0;
}
