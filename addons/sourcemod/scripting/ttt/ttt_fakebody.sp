#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ttt>
#include <ttt_bodies>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define SHORT_NAME "fakebody"
#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Items: Fake Body"

ConVar g_cPrice = null;
ConVar g_cShowFakeMessage = null;
ConVar g_cDeleteFakeBodyAfterFound = null;
ConVar g_cAllowProofByTraitors = null;
ConVar g_cShowTraitorAsDead = null;
ConVar g_cCount = null;
ConVar g_cPrio = null;
ConVar g_cLimit = null;
ConVar g_cLongName = null;
ConVar g_cActivation = null;

ConVar g_cSpawnType = null;
ConVar g_cPluginTag = null;
char g_sPluginTag[PLATFORM_MAX_PATH] = "";

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

    TTT_StartConfig("fakebody");
    CreateConVar("ttt2_fakebody_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("fakebody_name", "Fakebody", "The name of the Fakebody in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("fakebody_price", "9000", "The amount of credits a fake body costs as traitor. 0 to disable.");
    g_cCount = AutoExecConfig_CreateConVar("fakebody_count", "1", "The amount of usages for fake bodys per round as traitor. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("fakebody_sort_prio", "0", "The sorting priority of the fake body in the shop menu.");
    g_cLimit = AutoExecConfig_CreateConVar("fakebody_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cAllowProofByTraitors = AutoExecConfig_CreateConVar("fakebody_allow_proof_by_all", "1", "Allow fake body scan for traitors players?");
    g_cShowFakeMessage = AutoExecConfig_CreateConVar("fakebody_show_fake_message", "0", "Show the fake message (XXX has found a fake body)?");
    g_cDeleteFakeBodyAfterFound = AutoExecConfig_CreateConVar("fakebody_delete_fakebody_after_found", "0", "Delete fake body after found?");
    g_cShowTraitorAsDead = AutoExecConfig_CreateConVar("fakebody_show_traitor_as_dead", "1", "Show traitor as dead after fakebody found?");
    g_cActivation = AutoExecConfig_CreateConVar("fakebody_activation_mode", "1", "Which activation mode? 0 - New, over !inventory menu; 1 - Old, on purchase", _, true, 0.0, true, 1.0);
    TTT_EndConfig();
}

public void OnPluginEnd()
{
    if (TTT_IsShopRunning())
    {
        TTT_RemoveShopItem(SHORT_NAME);
    }
}

public void OnConfigsExecuted()
{
    g_cSpawnType = FindConVar("ttt_spawn_type");
    g_cPluginTag = FindConVar("ttt_plugin_tag");
    g_cPluginTag.AddChangeHook(OnConVarChanged);
    g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));

    RegisterItem();
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
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

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    if (g_cActivation.IntValue == 0)
    {
        TTT_AddInventoryItem(client, SHORT_NAME);
    }
    else if (g_cActivation.IntValue == 1)
    {
        TTT_AddItemUsage(client, SHORT_NAME);
        SpawnFakeBody(client);
    }
    
    return Plugin_Continue;
}

public void TTT_OnInventoryMenuItemSelect(int client, const char[] itemshort)
{
    if (TTT_IsClientValid(client) && StrEqual(itemshort, SHORT_NAME))
    {
        if (TTT_IsItemInInventory(client, SHORT_NAME))
        {
            TTT_RemoveInventoryItem(client, SHORT_NAME);
            TTT_AddItemUsage(client, SHORT_NAME);

            SpawnFakeBody(client);
        }
    }
}

bool SpawnFakeBody(int client)
{
    if (g_cSpawnType == null)
    {
        g_cSpawnType = FindConVar("ttt_spawn_type");

        if (g_cSpawnType == null)
        {
            SetFailState("[TTT Fakebody] Something went wrong \"ttt_spawn_type\".");
            return false;
        }
    }

    int iRagdoll = TTT_CreateClientRagdoll(client);

    if (iRagdoll == -1)
    {
        return false;
    }

    Ragdoll body;
    body.EntityRef = EntIndexToEntRef(iRagdoll);
    body.Victim = GetClientUserId(client);
    body.VictimTeam = TTT_GetClientTeam(client);
    TTT_GetClientName(client, body.VictimName, sizeof(body.VictimName));
    body.Scanned = false;
    body.Attacker = 0;
    body.AttackerTeam = TTT_TEAM_TRAITOR;
    Format(body.AttackerName, sizeof(body.AttackerName), "Fake!");
    body.GameTime = 0.0;

    if (TTT_IsItemInInventory(client, "decoyBody"))
    {
        body.Explode = true;

        TTT_RemoveInventoryItem(client, "decoyBody");
        TTT_AddItemUsage(client, "decoyBody");
    }
    else
    {
        body.Explode = false;
    }

    Format(body.Weaponused, sizeof(body.Weaponused), "Fake!");
    body.Found = false;

    TTT_PushRagdoll(body, sizeof(body));

    return true;
}

public Action TTT_OnBodyCheck(int client, int entityref)
{
    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    Ragdoll body;
    TTT_GetEntityRefRagdoll(entityref, body);

    if (StrEqual(body.Weaponused, "Fake!", false))
    {
        if (!g_cAllowProofByTraitors.BoolValue)
        {
            if (TTT_GetClientTeam(client) == TTT_TEAM_TRAITOR)
            {
                return Plugin_Stop;
            }
        }

        char sName[MAX_NAME_LENGTH];
        TTT_GetClientName(client, sName, sizeof(sName));

        LoopValidClients(j)
        {
            if (g_cShowFakeMessage.BoolValue && !body.Found)
            {
                CPrintToChat(j, "%s %T", g_sPluginTag, "Found Fake", j, sName);
            }
            else if (!g_cShowFakeMessage.BoolValue && !body.Found)
            {
                CPrintToChat(j, "%s %T", g_sPluginTag, "Found Traitor", j, sName, body.VictimName);
            }
            else if (body.Found)
            {
                return Plugin_Stop;
            }
        }

        if (g_cShowTraitorAsDead.BoolValue)
        {
            TTT_SetFoundStatus(GetClientOfUserId(body.Victim), true);
        }

        body.Found = true;

        if (g_cDeleteFakeBodyAfterFound.BoolValue)
        {
            AcceptEntityInput(body.EntityRef, "Kill");
        }

        if (!g_cDeleteFakeBodyAfterFound.BoolValue && !g_cShowFakeMessage.BoolValue)
        {
            if (g_cSpawnType.IntValue != 2)
            {
                SetEntityRenderColor(body.EntityRef, 255, 0, 0, 255);
            }
        }

        TTT_SetRagdoll(body, sizeof(body));
    }
    return Plugin_Continue;
}
