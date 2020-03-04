#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define SHORT_NAME_I "rdmTele_i"
#define SHORT_NAME_D "rdmTele_d"
#define SHORT_NAME_T "rdmTele_t"

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Random Teleporter"

ConVar g_cTPrice = null;
ConVar g_cTLimit = null;
ConVar g_cDPrice = null;
ConVar g_cDLimit = null;
ConVar g_cIPrice = null;
ConVar g_cILimit = null;
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
ConVar g_cActivation = null;

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
    g_cTLimit = AutoExecConfig_CreateConVar("rt_traitor_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cDPrice = AutoExecConfig_CreateConVar("rt_detective_price", "0", "The amount of credits for Random Teleport costs as detective. 0 to disable.");
    g_cDLimit = AutoExecConfig_CreateConVar("rt_detective_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cIPrice = AutoExecConfig_CreateConVar("rt_innocent_price", "0", "The amount of credits for Random Teleport costs as innocent. 0 to disable.");
    g_cILimit = AutoExecConfig_CreateConVar("rt_innocent_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
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
    g_cActivation = AutoExecConfig_CreateConVar("rt_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME_I);
        TTT_RemoveShopItem(SHORT_NAME_T);
        TTT_RemoveShopItem(SHORT_NAME_D);
    }
}

public void TTT_OnVersionReceive(int version)
{
    TTT_CheckVersion(TTT_PLUGIN_VERSION, TTT_GetPluginVersion());
}

public void OnConfigsExecuted()
{
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

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
    TTT_RegisterShopItem(SHORT_NAME_T, sBuffer, g_cTPrice.IntValue, TTT_TEAM_TRAITOR, g_cTPrio.IntValue, g_cTCount.IntValue, g_cTLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_D, sBuffer, g_cDPrice.IntValue, TTT_TEAM_DETECTIVE, g_cDPrio.IntValue, g_cDCount.IntValue, g_cDLimit.IntValue, OnItemPurchased);
    TTT_RegisterShopItem(SHORT_NAME_I, sBuffer, g_cIPrice.IntValue, TTT_TEAM_INNOCENT, g_cIPrio.IntValue, g_cICount.IntValue, g_cILimit.IntValue, OnItemPurchased);
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
    if (g_cActivation.IntValue == 0)
    {
        TTT_AddInventoryItem(client, itemshort);
    }
    else if (g_cActivation.IntValue == 1)
    {
        TTT_AddItemUsage(client, itemshort);
        RandomTeleport(client);
    }

    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client) && (StrEqual(itemshort, SHORT_NAME_I) || StrEqual(itemshort, SHORT_NAME_D) || StrEqual(itemshort, SHORT_NAME_T)))
    {
        if (TTT_IsItemInInventory(client, itemshort))
        {
            RandomTeleport(client);
        }
    }
}

int RandomTeleport(int client)
{
    bool bAlive = true;
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
        Ragdoll body;

        if (!TTT_GetClientRagdoll(target, body))
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Cant find ragdoll", client);
            return -1;
        }

        int entity = EntRefToEntIndex(body.EntityRef);

        if (!IsValidEntity(entity))
        {
            return -1;
        }

        float fAngles[3], fVelo[3];
        GetClientAbsOrigin(client, fClientPos);
        fClientPos[2] += 30;

        GetClientAbsAngles(client, fAngles);
        GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelo);

        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fTargetPos);

        TeleportEntity(client, fTargetPos, NULL_VECTOR, NULL_VECTOR);

        float speed = GetVectorLength(fVelo);
        if (speed >= 500)
        {
            TeleportEntity(entity, fClientPos, fAngles, NULL_VECTOR);
        }
        else
        {
            TeleportEntity(entity, fClientPos, fAngles, fVelo);
        }
    }

    CPrintToChat(client, "%s %T", g_sPluginTag, "Random Teleporter: Teleport", client, target);

    if (iRole == TTT_TEAM_TRAITOR)
    {
        TTT_AddItemUsage(client, SHORT_NAME_T);
        TTT_RemoveInventoryItem(client, SHORT_NAME_T);
    }
    else if (iRole == TTT_TEAM_INNOCENT)
    {
        TTT_AddItemUsage(client, SHORT_NAME_I);
        TTT_RemoveInventoryItem(client, SHORT_NAME_I);
    }
    else if (iRole == TTT_TEAM_DETECTIVE)
    {
        TTT_AddItemUsage(client, SHORT_NAME_D);
        TTT_RemoveInventoryItem(client, SHORT_NAME_D);
    }

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
