#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <ttt>
#include <ttt_bodies>
#include <ttt_shop>
#include <ttt_inventory>
#include <colorlib>

#define PLUGIN_NAME TTT_PLUGIN_NAME ... " - Dna Scanner"
#define SHORT_NAME "dnascanner"

ConVar g_cPrice = null;
ConVar g_cPrio = null;
ConVar g_cPrintTo = null;
ConVar g_cLongName = null;
ConVar g_cTeamColor = null;
ConVar g_cStartWith = null;
ConVar g_cFreeCount = null;
ConVar g_cCount = null;
ConVar g_cLimit = null;
ConVar g_cAddLogs = null;
ConVar g_cLogFormat = null;
ConVar g_cOneBuy = null;

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
    
    TTT_StartConfig("dnascanner");
    CreateConVar("ttt2_dna_scanner_version", TTT_PLUGIN_VERSION, TTT_PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_REPLICATED);
    g_cLongName = AutoExecConfig_CreateConVar("dna_name", "DNA Scanner", "The name of the Dnascanner in the Shop");
    g_cPrice = AutoExecConfig_CreateConVar("dna_price", "9000", "The amount of credits a dna scanner costs as detective. 0 to disable.");
    g_cPrio = AutoExecConfig_CreateConVar("dna_sort_prio", "0", "The sorting priority of the dna scanner in the shop menu.");
    g_cPrintTo = AutoExecConfig_CreateConVar("dna_print_message_to", "0", "Print scanner to... 0 - Nothing just detective, 1 - All detectives, 2 - All players (Default: 0)", _, true, 0.0, true, 2.0);
    g_cTeamColor = AutoExecConfig_CreateConVar("dna_team_color", "0", "Show team color on dna scan message?", _, true, 0.0, true, 1.0);
    g_cStartWith = AutoExecConfig_CreateConVar("dna_spawn_with", "1", "Spawn with dna scanner?", _, true, 0.0, true, 1.0);
    g_cFreeCount = AutoExecConfig_CreateConVar("dna_free_scanner_count", "3", "Limited the free dna scanner to X usages? (0 - disabled/unlimited)", _, true, 0.0);
    g_cCount = AutoExecConfig_CreateConVar("dna_count", "6", "Max dna scanner usages per round (dna_count + dna_free_scanner_count -> example 6 + 3 (free) is the max. count 9)");
    g_cLimit = AutoExecConfig_CreateConVar("dna_limit", "0", "The amount of purchases for all players during a round.", _, true, 0.0);
    g_cOneBuy = AutoExecConfig_CreateConVar("dna_one_buy", "1", "If it's 1, then it has unlimited usage for the round.", _, true, 0.0, true, 1.0);
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

    int iCount = g_cCount.IntValue + g_cFreeCount.IntValue;

    TTT_RegisterShopItem(SHORT_NAME, sBuffer, g_cPrice.IntValue, TTT_TEAM_DETECTIVE, g_cPrio.IntValue, iCount, g_cLimit.IntValue, OnItemPurchased);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        g_cPluginTag.GetString(g_sPluginTag, sizeof(g_sPluginTag));
    }
}

public void TTT_OnInventoryReady()
{
    LoopValidClients(client)
    {
        int iTeam = TTT_GetClientTeam(client);
        
        if (iTeam == TTT_TEAM_DETECTIVE)
        {
            if (g_cStartWith.BoolValue)
            {
                TTT_AddInventoryItem(client, SHORT_NAME, g_cFreeCount.IntValue);
            }
        }
    }
}

public Action OnItemPurchased(int client, const char[] itemshort, int count, int price)
{
    int iTeam = TTT_GetClientTeam(client);

    if (iTeam != TTT_TEAM_DETECTIVE)
    {
        return Plugin_Stop;
    }

    TTT_AddInventoryItem(client, SHORT_NAME);
    return Plugin_Continue;
}

public Action TTT_OnBodyCheck(int client, int entityref)
{
    Ragdoll body;
    TTT_GetEntityRefRagdoll(entityref, body);

    if (body.Scanned)
    {
        return Plugin_Continue;
    }

    if (!TTT_IsClientValid(client))
    {
        return Plugin_Continue;
    }

    if (TTT_GetClientTeam(client) != TTT_TEAM_DETECTIVE || !TTT_IsItemInInventory(client, SHORT_NAME))
    {
        return Plugin_Continue;
    }

    if (!g_cOneBuy.BoolValue)
    {
        TTT_AddItemUsage(client, SHORT_NAME);
        TTT_RemoveInventoryItem(client, SHORT_NAME);
    }
    
    int attacker = GetClientOfUserId(body.Attacker);
    int victim = GetClientOfUserId(body.Victim);
    
    LogMessage("[DNA-Scanner] Attacker UserID: %d (Index: %d), Victim UserID: %d (Index: %d), If Check: %d", body.Attacker, attacker, body.Victim, victim, (attacker > 0 && attacker != victim));

    char sAttackerID[24], sClientID[24], sTeam[ROLE_LENGTH], sName[MAX_NAME_LENGTH];
    TTT_GetTeamNameByID(body.AttackerTeam, sTeam, sizeof(sTeam));
    TTT_GetClientName(client, sName, sizeof(sName));
    
    if (g_cAddLogs != null && g_cAddLogs.BoolValue)
    {
        if (g_cLogFormat.IntValue == 1)
        {
            Format(sAttackerID, sizeof(sAttackerID), body.AttackerSteam2);
            GetClientAuthId(client, AuthId_Steam2, sClientID, sizeof(sClientID));
        }
        else if (g_cLogFormat.IntValue == 2)
        {
            Format(sAttackerID, sizeof(sAttackerID), body.AttackerSteam3);
            GetClientAuthId(client, AuthId_Steam3, sClientID, sizeof(sClientID));
        }
        else if (g_cLogFormat.IntValue == 3)
        {
            Format(sAttackerID, sizeof(sAttackerID), body.AttackerSteamID64);
            GetClientAuthId(client, AuthId_SteamID64, sClientID, sizeof(sClientID));
        }
        else if (g_cLogFormat.IntValue == 4)
        {
            Format(sAttackerID, sizeof(sAttackerID), "%d", body.AttackerAccountID);
            Format(sClientID, sizeof(sClientID), "%d", GetSteamAccountID(client));
        }
        
        if (strlen(sAttackerID) > 2 && strlen(sClientID) > 2)
        {
            Format(sAttackerID, sizeof(sAttackerID), " (%s)", sAttackerID);
            Format(sClientID, sizeof(sClientID), " (%s)", sClientID);
        }
    }

    TTT_LogString("-> [%N%s (Detective) scanned a body, Killer was %s%s (%s) with Weapon: %s]", client, sClientID, body.AttackerName, sAttackerID, sTeam, body.Weaponused);

    char sClientName[MAX_NAME_LENGTH];
    TTT_GetClientName(client, sClientName, sizeof(sClientName));

    if (g_cPrintTo.IntValue == 2)
    {
        LoopValidClients(j)
        {
            if (!g_cTeamColor.BoolValue)
            {
                CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body", j, sName, body.AttackerName, body.Weaponused);
            }
            else
            {
                char sTranslation[64];
                Format(sTranslation, sizeof(sTranslation), "Detective scan found body %s", sTeam);
                CPrintToChat(j, "%s %T", g_sPluginTag, sTranslation, j, sClientName, body.AttackerName, body.Weaponused);
            }
        }
    }
    else if (g_cPrintTo.IntValue == 1)
    {
        LoopValidClients(j)
        {
            if (TTT_GetClientTeam(j) == TTT_TEAM_DETECTIVE)
            {
                if (!g_cTeamColor.BoolValue)
                {
                    CPrintToChat(j, "%s %T", g_sPluginTag, "Detective scan found body", j, sName, body.AttackerName, body.Weaponused);
                }
                else
                {
                    char sTranslation[64];
                    Format(sTranslation, sizeof(sTranslation), "Detective scan found body %s", sTeam);
                    CPrintToChat(j, "%s %T", g_sPluginTag, sTranslation, j, sClientName, body.AttackerName, body.Weaponused);
                }
            }
        }
    }
    else
    {
        if (!g_cTeamColor.BoolValue)
        {
            CPrintToChat(client, "%s %T", g_sPluginTag, "Detective scan found body", client, sName, body.AttackerName, body.Weaponused);
        }
        else
        {
            char sTranslation[64];
            Format(sTranslation, sizeof(sTranslation), "Detective scan found body %s", sTeam);
            CPrintToChat(client, "%s %T", g_sPluginTag, sTranslation, client, sClientName, body.AttackerName, body.Weaponused);
        }
    }

    body.Scanned = true;
    TTT_SetRagdoll(body, sizeof(body));

    return Plugin_Changed;
}
